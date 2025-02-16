/*
  This file is part of Sanmill.
  Copyright (C) 2019-2021 The Sanmill developers (see AUTHORS file)

  Sanmill is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Sanmill is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

part of '../mill.dart';

class _StateInfo {
  // Copied when making a move
  int rule50 = 0;
  int pliesFromNull = 0;

  // Not copied when making a move (will be recomputed anyhow)
  int key = 0;
}

class Position {
  final MillController controller;

  Position(this.controller) {
    _init();
  }

  final List<int> posKeyHistory = [];

  GameResult result = GameResult.pending;

  List<PieceColor> _board = List.filled(sqNumber, PieceColor.none);
  List<PieceColor> _grid = List.filled(7 * 7, PieceColor.none);

  // TODO: [Leptopoda] move it into the controller
  late _GameRecorder recorder;

  Map<PieceColor, int> pieceInHandCount = {
    PieceColor.white: -1,
    PieceColor.black: -1
  };
  Map<PieceColor, int> pieceOnBoardCount = {
    PieceColor.white: 0,
    PieceColor.black: 0
  };
  int pieceToRemoveCount = 0;

  int gamePly = 0;
  PieceColor _sideToMove = PieceColor.white;

  _StateInfo st = _StateInfo();

  PieceColor _them = PieceColor.black;
  PieceColor _winner = PieceColor.nobody;

  GameOverReason gameOverReason = GameOverReason.none;

  Phase phase = Phase.none;
  Act action = Act.none;

  Map<PieceColor, int> score = {
    PieceColor.white: 0,
    PieceColor.black: 0,
    PieceColor.draw: 0
  };

  int _currentSquare = 0;

  ExtMove? record;

  static late List<List<List<int>>> _millTable;
  static late List<List<int>> _adjacentSquares;

  late ExtMove extMove;

  PieceColor pieceOnGrid(int index) => _grid[index];
  PieceColor pieceOn(int sq) => _board[sq];

  PieceColor get sideToMove => _sideToMove;
  set sideToMove(PieceColor color) {
    _sideToMove = color;
    //us = color;
    _them = _sideToMove.opponent;
  }

  Future<bool> _movePiece(int from, int to) async {
    if (selectPiece(from) == SelectionResponse.ok) {
      return putPiece(to);
    }
    return false;
  }

  void restart() => _init();

  void _init() {
    phase = Phase.placing;

    _setPosition(); // TODO

    // TODO
    // TODO: [Leptopoda] make the recorder get the fen itself as it is public so we don't need to pas it around...
    // seems like this is causing the stack overflow
    recorder = _GameRecorder(controller, lastPositionWithRemove: _fen);
  }

  /// Returns a FEN representation of the position.
  String get _fen {
    final buffer = StringBuffer();

    // Piece placement data
    for (var file = 1; file <= fileNumber; file++) {
      for (var rank = 1; rank <= rankNumber; rank++) {
        final piece = pieceOnGrid(squareToIndex[makeSquare(file, rank)]!);
        buffer.write(piece.string);
      }

      if (file == 3) {
        buffer.writeSpace();
      } else {
        buffer.write("/");
      }
    }

    // Active color
    buffer.writeSpace(_sideToMove == PieceColor.white ? "w" : "b");

    // Phrase
    buffer.writeSpace(phase.fen);

    // Action
    buffer.writeSpace(action.fen);

    buffer.writeSpace(pieceOnBoardCount[PieceColor.white]);
    buffer.writeSpace(pieceInHandCount[PieceColor.white]);
    buffer.writeSpace(pieceOnBoardCount[PieceColor.black]);
    buffer.writeSpace(pieceInHandCount[PieceColor.black]);
    buffer.writeSpace(pieceToRemoveCount);

    final int sideIsBlack = _sideToMove == PieceColor.black ? 1 : 0;

    buffer.write("${st.rule50} ${1 + (gamePly - sideIsBlack) ~/ 2}");

    logger.v("FEN is $buffer");

    return buffer.toString();
  }

  Future<bool> _doMove(String move) async {
    if (move.length > "Player".length &&
        move.substring(0, "Player".length - 1) == "Player") {
      if (move["Player".length] == "1") {
        return _resign(PieceColor.white);
      } else {
        return _resign(PieceColor.black);
      }
    }

    // TODO
    if (move == "Threefold Repetition. Draw!") {
      return true;
    }

    if (move == "draw") {
      phase = Phase.gameOver;
      _winner = PieceColor.draw;

      score[PieceColor.draw] = score[PieceColor.draw]! + 1;

      // TODO: WAR to judge rule50
      if (LocalDatabaseService.rules.nMoveRule > 0 &&
          posKeyHistory.length >= LocalDatabaseService.rules.nMoveRule - 1) {
        gameOverReason = GameOverReason.drawRule50;
      } else if (LocalDatabaseService.rules.endgameNMoveRule <
              LocalDatabaseService.rules.nMoveRule &&
          _isThreeEndgame &&
          posKeyHistory.length >=
              LocalDatabaseService.rules.endgameNMoveRule - 1) {
        gameOverReason = GameOverReason.drawEndgameRule50;
      } else if (LocalDatabaseService.rules.threefoldRepetitionRule) {
        gameOverReason = GameOverReason.drawThreefoldRepetition; // TODO: Sure?
      } else {
        gameOverReason = GameOverReason.drawBoardIsFull; // TODO: Sure?
      }

      return true;
    }

    // TODO: Above is diff from position.cpp

    bool ret = false;

    final ExtMove m = ExtMove(move);

    switch (m.type) {
      case _MoveType.remove:
        ret = await removePiece(m.to) == RemoveResponse.ok;
        if (ret) {
          // Reset rule 50 counter
          st.rule50 = 0;
        }
        break;
      case _MoveType.move:
        ret = await _movePiece(m.from, m.to);
        if (ret) {
          ++st.rule50;
        }
        break;
      case _MoveType.place:
        ret = await putPiece(m.to);
        if (ret) {
          // Reset rule 50 counter
          st.rule50 = 0;
        }
    }

    if (!ret) {
      return false;
    }

    // Increment ply counters. In particular, rule50 will be reset to zero later on
    // in case of a capture.
    ++gamePly;
    ++st.pliesFromNull;

    if (record != null && record!.move.length > "-(1,2)".length) {
      if (st.key != posKeyHistory.lastF) {
        posKeyHistory.add(st.key);
        if (LocalDatabaseService.rules.threefoldRepetitionRule &&
            hasGameCycle) {
          setGameOver(
            PieceColor.draw,
            GameOverReason.drawThreefoldRepetition,
          );
        }
      }
    } else {
      posKeyHistory.clear();
    }

    extMove = m;

    recorder.moveIn(m, this); // TODO: Is Right?

    return true;
  }

  /// hasGameCycle() tests if the position has a move which draws by repetition.
  bool get hasGameCycle {
    int repetition = 0; // Note: Engine is global val
    for (final i in posKeyHistory) {
      if (st.key == i) {
        repetition++;
        if (repetition == 3) {
          logger.i("[position] Has game cycle.");
          return true;
        }
      }
    }

    return false;
  }

///////////////////////////////////////////////////////////////////////////////

  /// Mill Game

  void _reset() {
    gamePly = 0;
    st.rule50 = 0;

    phase = Phase.ready;
    sideToMove = PieceColor.white;
    action = Act.place;

    _winner = PieceColor.nobody;
    gameOverReason = GameOverReason.none;

    _clearBoard();

    st.key = 0;

    pieceOnBoardCount[PieceColor.white] =
        pieceOnBoardCount[PieceColor.black] = 0;
    pieceInHandCount[PieceColor.white] = pieceInHandCount[PieceColor.black] =
        LocalDatabaseService.rules.piecesCount;
    pieceToRemoveCount = 0;

    // TODO:
    // MoveList<LEGAL>::create();
    // create_mill_table();

    _currentSquare = 0;

    record = null;
  }

  void _start() {
    gameOverReason = GameOverReason.none;

    switch (phase) {
      case Phase.gameOver:
        _reset();
        continue ready;
      ready:
      case Phase.ready:
        phase = Phase.placing;
        break;
      case Phase.placing:
      case Phase.moving:
      case Phase.none:
    }
  }

  Future<bool> putPiece(int s) async {
    var piece = PieceColor.none;
    final us = _sideToMove;

    if (phase == Phase.gameOver ||
        action != Act.place ||
        !(sqBegin <= s && s < sqEnd) ||
        _board[s] != PieceColor.none) {
      return false;
    }

    if (phase == Phase.ready) _start();

    switch (phase) {
      case Phase.placing:
        piece = sideToMove;
        if (pieceInHandCount[us] != null) {
          pieceInHandCount[us] = pieceInHandCount[us]! - 1;
        }

        if (pieceOnBoardCount[us] != null) {
          pieceOnBoardCount[us] = pieceOnBoardCount[us]! + 1;
        }

        _grid[squareToIndex[s]!] = piece;
        _board[s] = piece;

        record = ExtMove("(${fileOf(s)},${rankOf(s)})");

        _updateKey(s);

        _currentSquare = s;

        final int n = _millsCount(_currentSquare);

        if (n == 0) {
          assert(
            pieceInHandCount[PieceColor.white]! >= 0 &&
                pieceInHandCount[PieceColor.black]! >= 0,
          );

          if (pieceInHandCount[PieceColor.white] == 0 &&
              pieceInHandCount[PieceColor.black] == 0) {
            if (_gameOver) return true;

            phase = Phase.moving;
            action = Act.select;

            if (LocalDatabaseService.rules.hasBannedLocations) {
              _removeBanStones();
            }

            if (!LocalDatabaseService.rules.isDefenderMoveFirst) {
              _changeSideToMove();
            }

            if (_gameOver) return true;
          } else {
            _changeSideToMove();
          }
          controller.gameInstance.focusIndex = squareToIndex[s];
          await Audios.playTone(Sound.place);
        } else {
          pieceToRemoveCount =
              LocalDatabaseService.rules.mayRemoveMultiple ? n : 1;
          _updateKeyMisc();

          if (LocalDatabaseService
                  .rules.mayOnlyRemoveUnplacedPieceInPlacingPhase &&
              pieceInHandCount[_them] != null) {
            pieceInHandCount[_them] =
                pieceInHandCount[_them]! - 1; // Or pieceToRemoveCount?

            if (pieceInHandCount[_them]! < 0) {
              pieceInHandCount[_them] = 0;
            }

            if (pieceInHandCount[PieceColor.white] == 0 &&
                pieceInHandCount[PieceColor.black] == 0) {
              if (_gameOver) return true;

              phase = Phase.moving;
              action = Act.select;

              if (LocalDatabaseService.rules.isDefenderMoveFirst) {
                _changeSideToMove();
              }

              if (_gameOver) return true;
            }
          } else {
            action = Act.remove;
          }

          controller.gameInstance.focusIndex = squareToIndex[s];
          await Audios.playTone(Sound.mill);
        }
        break;
      case Phase.moving:
        if (_gameOver) return true;

        // if illegal
        if (pieceOnBoardCount[sideToMove]! >
                LocalDatabaseService.rules.flyPieceCount ||
            !LocalDatabaseService.rules.mayFly) {
          int md;

          for (md = 0; md < moveDirectionNumber; md++) {
            if (s == _adjacentSquares[_currentSquare][md]) break;
          }

          // not in moveTable
          if (md == moveDirectionNumber) {
            logger.i(
              "[position] putPiece: [$s] is not in [$_currentSquare]'s move table.",
            );
            return false;
          }
        }

        record = ExtMove(
          "(${fileOf(_currentSquare)},${rankOf(_currentSquare)})->(${fileOf(s)},${rankOf(s)})",
        );

        st.rule50++;

        _board[s] = _grid[squareToIndex[s]!] = _board[_currentSquare];
        _updateKey(s);
        _revertKey(_currentSquare);

        _board[_currentSquare] =
            _grid[squareToIndex[_currentSquare]!] = PieceColor.none;

        _currentSquare = s;
        final int n = _millsCount(_currentSquare);

        // midgame
        if (n == 0) {
          action = Act.select;
          _changeSideToMove();

          if (_gameOver) return true;
          controller.gameInstance.focusIndex = squareToIndex[s];

          await Audios.playTone(Sound.place);
        } else {
          pieceToRemoveCount =
              LocalDatabaseService.rules.mayRemoveMultiple ? n : 1;
          _updateKeyMisc();
          action = Act.remove;
          controller.gameInstance.focusIndex = squareToIndex[s];
          await Audios.playTone(Sound.mill);
        }

        break;
      default:
        assert(false);
    }
    return true;
  }

  Future<RemoveResponse> removePiece(int s) async {
    if (phase == Phase.ready || phase == Phase.gameOver) {
      return RemoveResponse.illegalPhase;
    }

    if (action != Act.remove) return RemoveResponse.illegalAction;

    if (pieceToRemoveCount <= 0) return RemoveResponse.noPieceToRemove;

    // if piece is not their
    if (!(sideToMove.opponent == _board[s])) {
      return RemoveResponse.cannotRemoveOurPiece;
    }

    if (!LocalDatabaseService.rules.mayRemoveFromMillsAlways &&
        _potentialMillsCount(s, PieceColor.nobody) > 0 &&
        !_isAllInMills(sideToMove.opponent)) {
      return RemoveResponse.cannotRemovePieceFromMill;
    }

    _revertKey(s);

    await Audios.playTone(Sound.remove);

    if (LocalDatabaseService.rules.hasBannedLocations &&
        phase == Phase.placing) {
      // Remove and put ban
      _board[s] = _grid[squareToIndex[s]!] = PieceColor.ban;
      _updateKey(s);
    } else {
      // Remove only
      _board[s] = _grid[squareToIndex[s]!] = PieceColor.none;
    }

    record = ExtMove("-(${fileOf(s)},${rankOf(s)})");
    st.rule50 = 0; // TODO: Need to move out?

    if (pieceOnBoardCount[_them] != null) {
      pieceOnBoardCount[_them] = pieceOnBoardCount[_them]! - 1;
    }

    if (pieceOnBoardCount[_them]! + pieceInHandCount[_them]! <
        LocalDatabaseService.rules.piecesAtLeastCount) {
      setGameOver(sideToMove, GameOverReason.loseLessThanThree);
      return RemoveResponse.ok;
    }

    _currentSquare = 0;

    pieceToRemoveCount--;
    _updateKeyMisc();

    if (pieceToRemoveCount != 0) {
      return RemoveResponse.ok;
    }

    if (phase == Phase.placing) {
      if (pieceInHandCount[PieceColor.white] == 0 &&
          pieceInHandCount[PieceColor.black] == 0) {
        phase = Phase.moving;
        action = Act.select;

        if (LocalDatabaseService.rules.hasBannedLocations) {
          _removeBanStones();
        }

        if (LocalDatabaseService.rules.isDefenderMoveFirst) {
          _gameOver;
          return RemoveResponse.ok;
        }
      } else {
        action = Act.place;
      }
    } else {
      action = Act.select;
    }

    _changeSideToMove();
    _gameOver;

    return RemoveResponse.ok;
  }

  SelectionResponse selectPiece(int sq) {
    if (phase != Phase.moving) return SelectionResponse.illegalPhase;

    if (action != Act.select && action != Act.place) {
      return SelectionResponse.illegalAction;
    }

    if (_board[sq] == PieceColor.none) {
      return SelectionResponse.canOnlyMoveToAdjacentEmptyPoints;
    }

    if (!(_board[sq] == sideToMove)) {
      return SelectionResponse.pleaseSelectOurPieceToMove;
    }

    _currentSquare = sq;
    action = Act.place;
    controller.gameInstance.blurIndex = squareToIndex[sq];

    return SelectionResponse.ok;
  }

  bool _resign(PieceColor loser) {
    if (phase == Phase.ready ||
        phase == Phase.gameOver ||
        phase == Phase.none) {
      return false;
    }

    setGameOver(loser.opponent, GameOverReason.loseResign);

    return true;
  }

  PieceColor get winner => _winner;

  void setGameOver(PieceColor w, GameOverReason reason) {
    phase = Phase.gameOver;
    gameOverReason = reason;
    _winner = w;

    logger.i("[position] Game over, $w win, because of $reason");
    _updateScore();
  }

  void _updateScore() {
    if (phase == Phase.gameOver) {
      score[_winner] = score[_winner]! + 1;
    }
  }

  bool get _isThreeEndgame {
    if (phase == Phase.placing) {
      return false;
    }

    return pieceOnBoardCount[PieceColor.white] == 3 ||
        pieceOnBoardCount[PieceColor.black] == 3;
  }

  // TODO: [Leptopoda] this method seems to be more than  a getter
  // we should probably return it to not be a getter and rename it to avoid confusion
  // The original name was: checkIfGameIsOver()
  bool get _gameOver {
    if (phase == Phase.ready || phase == Phase.gameOver) {
      return true;
    }

    if (LocalDatabaseService.rules.nMoveRule > 0 &&
        posKeyHistory.length >= LocalDatabaseService.rules.nMoveRule) {
      setGameOver(PieceColor.draw, GameOverReason.drawRule50);
      return true;
    }

    if (LocalDatabaseService.rules.endgameNMoveRule <
            LocalDatabaseService.rules.nMoveRule &&
        _isThreeEndgame &&
        posKeyHistory.length >= LocalDatabaseService.rules.endgameNMoveRule) {
      setGameOver(PieceColor.draw, GameOverReason.drawEndgameRule50);
      return true;
    }

    if (pieceOnBoardCount[PieceColor.white]! +
            pieceOnBoardCount[PieceColor.black]! >=
        rankNumber * fileNumber) {
      if (LocalDatabaseService.rules.isWhiteLoseButNotDrawWhenBoardFull) {
        setGameOver(PieceColor.black, GameOverReason.loseBoardIsFull);
      } else {
        setGameOver(PieceColor.draw, GameOverReason.drawBoardIsFull);
      }

      return true;
    }

    if (phase == Phase.moving && action == Act.select && _isAllSurrounded) {
      if (LocalDatabaseService.rules.isLoseButNotChangeSideWhenNoWay) {
        setGameOver(
          sideToMove.opponent,
          GameOverReason.loseNoWay,
        );
        return true;
      } else {
        _changeSideToMove(); // TODO: Need?
        return false;
      }
    }

    return false;
  }

  void _removeBanStones() {
    assert(LocalDatabaseService.rules.hasBannedLocations);

    int s = 0;

    for (int f = 1; f <= fileNumber; f++) {
      for (int r = 0; r < rankNumber; r++) {
        s = f * rankNumber + r;

        if (_board[s] == PieceColor.ban) {
          _board[s] = _grid[squareToIndex[s]!] = PieceColor.none;
          _revertKey(s);
        }
      }
    }
  }

  void _changeSideToMove() {
    sideToMove = _sideToMove.opponent;
    st.key ^= _Zobrist.side;
    logger.v("[position] $_sideToMove to move.");
  }

  /// Updates square if it hasn't been updated yet.
  int _updateKey(int s) {
    final PieceColor pieceType = _colorOn(s);

    return st.key ^= _Zobrist.psq[pieceType.index][s];
  }

  /// If the square has been updated,
  /// then another update is equivalent to returning to
  /// the state before the update
  /// The significance of this function is to improve code readability.
  int _revertKey(int s) => _updateKey(s);

  void _updateKeyMisc() {
    st.key = st.key << _Zobrist.keyMiscBit >> _Zobrist.keyMiscBit;

    st.key |= pieceToRemoveCount << (32 - _Zobrist.keyMiscBit);
  }

  ///////////////////////////////////////////////////////////////////////////////

  PieceColor _colorOn(int sq) {
    return _board[sq];
  }

  int _potentialMillsCount(int to, PieceColor c, {int from = 0}) {
    int n = 0;
    PieceColor locbak = PieceColor.none;
    PieceColor _c = c;

    assert(0 <= from && from < sqNumber);

    if (_c == PieceColor.nobody) {
      _c = _colorOn(to);
    }

    if (from != 0 && from >= sqBegin && from < sqEnd) {
      locbak = _board[from];
      _board[from] = _grid[squareToIndex[from]!] = PieceColor.none;
    }

    for (int ld = 0; ld < lineDirectionNumber; ld++) {
      if (_c == _board[_millTable[to][ld][0]] &&
          _c == _board[_millTable[to][ld][1]]) {
        n++;
      }
    }

    if (from != 0) {
      _board[from] = _grid[squareToIndex[from]!] = locbak;
    }

    return n;
  }

  int _millsCount(int s) {
    int n = 0;
    final List<int?> idx = [0, 0, 0];
    int min = 0;
    int? temp = 0;
    final PieceColor m = _colorOn(s);

    for (int i = 0; i < idx.length; i++) {
      idx[0] = s;
      idx[1] = _millTable[s][i][0];
      idx[2] = _millTable[s][i][1];

      // no mill
      if (!(m == _board[idx[1]!] && m == _board[idx[2]!])) {
        continue;
      }

      // close mill

      // sort
      for (int j = 0; j < 2; j++) {
        min = j;

        for (int k = j + 1; k < 3; k++) {
          if (idx[min]! > idx[k]!) min = k;
        }

        if (min == j) {
          continue;
        }

        temp = idx[min];
        idx[min] = idx[j];
        idx[j] = temp;
      }

      n++;
    }

    return n;
  }

  bool _isAllInMills(PieceColor c) {
    for (int i = sqBegin; i < sqEnd; i++) {
      if (_board[i] == c) {
        if (_potentialMillsCount(i, PieceColor.nobody) == 0) {
          return false;
        }
      }
    }

    return true;
  }

  bool get _isAllSurrounded {
    // Full
    if (pieceOnBoardCount[PieceColor.white]! +
            pieceOnBoardCount[PieceColor.black]! >=
        rankNumber * fileNumber) {
      return true;
    }

    // Can fly
    if (pieceOnBoardCount[sideToMove]! <=
            LocalDatabaseService.rules.flyPieceCount &&
        LocalDatabaseService.rules.mayFly) {
      return false;
    }

    for (int s = sqBegin; s < sqEnd; s++) {
      if (!(sideToMove == _colorOn(s))) {
        continue;
      }

      for (int d = moveDirectionBegin; d < moveDirectionNumber; d++) {
        final int moveSquare = _adjacentSquares[s][d];
        if (moveSquare != 0 && _board[moveSquare] == PieceColor.none) {
          return false;
        }
      }
    }

    return true;
  }

  ///////////////////////////////////////////////////////////////////////////////

  int get _nPiecesInHand {
    pieceInHandCount[PieceColor.white] =
        LocalDatabaseService.rules.piecesCount -
            pieceOnBoardCount[PieceColor.white]!;
    pieceInHandCount[PieceColor.black] =
        LocalDatabaseService.rules.piecesCount -
            pieceOnBoardCount[PieceColor.black]!;

    return pieceOnBoardCount[PieceColor.white]! +
        pieceOnBoardCount[PieceColor.black]!;
  }

  void _clearBoard() {
    _grid = List.filled(_grid.length, PieceColor.none);
    _board = List.filled(_board.length, PieceColor.none);
  }

  void _setPosition() {
    result = GameResult.pending;

    gamePly = 0;
    st.rule50 = 0;
    st.pliesFromNull = 0;

    gameOverReason = GameOverReason.none;
    phase = Phase.placing;
    sideToMove = PieceColor.white;
    action = Act.place;
    _currentSquare = 0;

    record = null;

    _clearBoard();

    if (_pieceOnBoardCount == null) {
      return;
    }

    _nPiecesInHand;
    pieceToRemoveCount = 0;

    _winner = PieceColor.nobody;
    _adjacentSquares = _Mills.adjacentSquaresInit;
    _millTable = _Mills.millTableInit;
    _currentSquare = 0;

    return;
  }

  int? get _pieceOnBoardCount {
    pieceOnBoardCount[PieceColor.white] =
        pieceOnBoardCount[PieceColor.black] = 0;

    for (int f = 1; f < fileExNumber; f++) {
      for (int r = 0; r < rankNumber; r++) {
        final int s = f * rankNumber + r;

        if (_board[s] == PieceColor.white || _board[s] == PieceColor.black) {
          pieceOnBoardCount[_board[s]] = pieceOnBoardCount[_board[s]]! + 1;
        }
      }
    }

    if (pieceOnBoardCount[PieceColor.white]! >
            LocalDatabaseService.rules.piecesCount ||
        pieceOnBoardCount[PieceColor.black]! >
            LocalDatabaseService.rules.piecesCount) {
      return null;
    }

    return pieceOnBoardCount[PieceColor.white]! +
        pieceOnBoardCount[PieceColor.black]!;
  }

///////////////////////////////////////////////////////////////////////////////
  Future<_HistoryResponse?> gotoHistory(HistoryMove move, [int? index]) async {
    final int moveIndex = move.gotoHistoryIndex(index);

    if (recorder.cur == moveIndex) {
      logger.i("[goto] cur is equal to moveIndex.");
      return _HistoryResponse.equal;
    }

    if (moveIndex < -1 || recorder.moveCount <= moveIndex) {
      logger.i("[goto] moveIndex is out of range.");
      return _HistoryResponse.outOfRange;
    }

    Audios.isTemporaryMute = true;

    // Backup context
    final gameModeBackup = controller.gameInstance.gameMode;
    controller.gameInstance.gameMode = GameMode.humanVsHuman;
    final historyBack = recorder.moves;
    controller.gameInstance.newGame();

    _HistoryResponse? error;

    // TODO: [Leptopoda] throw errors instead of returning bools
    for (int i = 0; i <= moveIndex; i++) {
      if (!(await controller.gameInstance.doMove(historyBack[i]))) {
        error = _HistoryResponse.error;
        break;
      }
    }

    // Restore context
    controller.gameInstance.gameMode = gameModeBackup;
    recorder.moves = historyBack;
    recorder.cur = moveIndex;

    Audios.isTemporaryMute = false;
    await move.gotoHistoryPlaySound();
    return error;
  }

  String? get _movesSinceLastRemove {
    int i = 0;
    final buffer = StringBuffer();
    int posAfterLastRemove = 0;

    for (i = recorder.moveCount - 1; i >= 0; i--) {
      if (recorder.moves[i].move[0] == "-") break;
    }

    if (i >= 0) {
      posAfterLastRemove = i + 1;
    }

    for (int i = posAfterLastRemove; i < recorder.moveCount; i++) {
      buffer.write(" ${recorder.moves[i].move}");
    }

    final String moves = buffer.toString();

    assert(!moves.contains('-('));

    return moves.isNotEmpty ? moves.substring(1) : null;
  }

  String? get moveHistoryText => recorder._buildMoveHistoryText();

  ExtMove? get lastMove => recorder.lastMove;

  String? get lastPositionWithRemove => recorder.lastPositionWithRemove;
}
