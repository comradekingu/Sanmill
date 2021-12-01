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

enum HistoryResponse { equal, outOfRange, error }

extension HistoryResponseExtension on HistoryResponse {
  String getString(BuildContext context) {
    switch (this) {
      case HistoryResponse.outOfRange:
      case HistoryResponse.equal:
        return S.of(context).atEnd;
      case HistoryResponse.error:
      default:
        return S.of(context).movesAndRulesNotMatch;
    }
  }
}

enum SelectionResponse { r0, r1, r2, r3, r4 }
enum RemoveResponse { r0, r1, r2, r3 }

class Position {
  final List<int> posKeyHistory = [];

  GameResult result = GameResult.pending;

  List<PieceColor> board = List.filled(sqNumber, PieceColor.none);
  List<PieceColor> _grid = List.filled(7 * 7, PieceColor.none);

  late GameRecorder recorder;

  // TODO: [Leptopoda] use null
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

  PieceColor us = PieceColor.white;
  PieceColor them = PieceColor.black;
  PieceColor _winner = PieceColor.nobody;

  GameOverReason gameOverReason = GameOverReason.noReason;

  Phase phase = Phase.none;
  Act action = Act.none;

  Map<PieceColor, int> score = {
    PieceColor.white: 0,
    PieceColor.black: 0,
    PieceColor.draw: 0
  };

  int currentSquare = 0;
  int nPlayed = 0;

  Move? record;

  static late List<List<List<int>>> millTable;
  static late List<List<int>> adjacentSquares;

  late Move move;

  Position() {
    _init();
  }

  Position.clone(Position other) {
    _grid = [];
    for (final piece in other._grid) {
      _grid.add(piece);
    }

    board = [];
    for (final piece in other.board) {
      board.add(piece);
    }

    recorder = other.recorder;

    pieceInHandCount = other.pieceInHandCount;
    pieceOnBoardCount = other.pieceOnBoardCount;
    pieceToRemoveCount = other.pieceToRemoveCount;

    gamePly = other.gamePly;

    _sideToMove = other._sideToMove;

    st.rule50 = other.st.rule50;
    st.pliesFromNull = other.st.pliesFromNull;

    them = other.them;
    _winner = other._winner;
    gameOverReason = other.gameOverReason;

    phase = other.phase;
    action = other.action;

    score = other.score;

    currentSquare = other.currentSquare;
    nPlayed = other.nPlayed;
  }

  PieceColor pieceOnGrid(int index) => _grid[index];
  PieceColor pieceOn(int sq) => board[sq];

  PieceColor get sideToMove => _sideToMove;
  PieceColor movedPiece(int move) => pieceOn(fromSq(move));

  Future<bool> movePiece(int from, int to) async {
    if (selectPiece(from) == SelectionResponse.r0) {
      return putPiece(to);
    }
    return false;
  }

  void restart() {
    for (var i = 0; i < _grid.length; i++) {
      _grid[i] = PieceColor.none;
    }

    for (var i = 0; i < board.length; i++) {
      board[i] = PieceColor.none;
    }

    _init();
  }

  void _init() {
    phase = Phase.placing;

    setPosition(); // TODO

    // TODO
    recorder = GameRecorder(lastPositionWithRemove: fen());
  }

  /// Return a FEN representation of the position.
  String fen() {
    final buffer = StringBuffer();
    const space = " ";

    // Piece placement data
    for (var file = 1; file <= fileNumber; file++) {
      for (var rank = 1; rank <= rankNumber; rank++) {
        final piece = pieceOnGrid(squareToIndex[makeSquare(file, rank)]!);
        buffer.write(piece.string);
      }

      if (file == 3) {
        buffer.write(space);
      } else {
        buffer.write("/");
      }
    }

    // Active color
    buffer.write(_sideToMove == PieceColor.white ? "w$space" : "b$space");

    // Phrase
    buffer.write(phase.fen + space);

    // Action
    buffer.write(action.fen + space);

    buffer.write(
      "${pieceOnBoardCount[PieceColor.white]} ${pieceInHandCount[PieceColor.white]} ${pieceOnBoardCount[PieceColor.black]} ${pieceInHandCount[PieceColor.black]} $pieceToRemoveCount ",
    );

    final int sideIsBlack = _sideToMove == PieceColor.black ? 1 : 0;

    buffer.write("${st.rule50} ${1 + (gamePly - sideIsBlack) ~/ 2}");

    logger.v("FEN is $buffer");

    return buffer.toString();
  }

  /// Position::legal() tests whether a pseudo-legal move is legal
  bool legal(Move move) {
    if (!isOk(move.from) || !isOk(move.to)) return false;

    final PieceColor us = _sideToMove;

    if (move.from == move.to) {
      logger.v("[position] Move $move.move from == to");
      return false;
    }

    if (move.type == MoveType.remove) {
      if (movedPiece(move.to) != us) {
        logger.v("[position] Move $move.to to != us");
        return false;
      }
    }

    return true;
  }

  Future<bool> doMove(String move) async {
    if (move.length > "Player".length &&
        move.substring(0, "Player".length - 1) == "Player") {
      if (move["Player".length] == "1") {
        return resign(PieceColor.white);
      } else {
        return resign(PieceColor.black);
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
        gameOverReason = GameOverReason.drawReasonRule50;
      } else if (LocalDatabaseService.rules.endgameNMoveRule <
              LocalDatabaseService.rules.nMoveRule &&
          isThreeEndgame &&
          posKeyHistory.length >=
              LocalDatabaseService.rules.endgameNMoveRule - 1) {
        gameOverReason = GameOverReason.drawReasonEndgameRule50;
      } else if (LocalDatabaseService.rules.threefoldRepetitionRule) {
        gameOverReason =
            GameOverReason.drawReasonThreefoldRepetition; // TODO: Sure?
      } else {
        gameOverReason = GameOverReason.drawReasonBoardIsFull; // TODO: Sure?
      }

      return true;
    }

    // TODO: Above is diff from position.cpp

    bool ret = false;

    final Move m = Move(move);

    switch (m.type) {
      case MoveType.remove:
        ret = await removePiece(m.to) == RemoveResponse.r0;
        if (ret) {
          // Reset rule 50 counter
          st.rule50 = 0;
        }
        break;
      case MoveType.move:
        ret = await movePiece(m.from, m.to);
        if (ret) {
          ++st.rule50;
        }
        break;
      case MoveType.place:
        ret = await putPiece(m.to);
        if (ret) {
          // Reset rule 50 counter
          st.rule50 = 0;
        }
        break;
      default:
        throw Exception("No Move to do");
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
            hasGameCycle()) {
          setGameOver(
            PieceColor.draw,
            GameOverReason.drawReasonThreefoldRepetition,
          );
        }
      }
    } else {
      posKeyHistory.clear();
    }

    this.move = m;

    recorder.moveIn(m, this); // TODO: Is Right?

    return true;
  }

  bool hasRepeated(List<Position> ss) {
    for (int i = posKeyHistory.length - 2; i >= 0; i--) {
      if (st.key == posKeyHistory[i]) {
        return true;
      }
    }

    final int size = ss.length;

    for (int i = size - 1; i >= 0; i--) {
      if (ss[i].move.type == MoveType.remove) {
        break;
      }
      if (st.key == ss[i].st.key) {
        return true;
      }
    }

    return false;
  }

  /// hasGameCycle() tests if the position has a move which draws by repetition.

  bool hasGameCycle() {
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

  bool reset() {
    gamePly = 0;
    st.rule50 = 0;

    phase = Phase.ready;
    setSideToMove(PieceColor.white);
    action = Act.place;

    _winner = PieceColor.nobody;
    gameOverReason = GameOverReason.noReason;

    clearBoard();

    st.key = 0;

    pieceOnBoardCount[PieceColor.white] =
        pieceOnBoardCount[PieceColor.black] = 0;
    pieceInHandCount[PieceColor.white] = pieceInHandCount[PieceColor.black] =
        LocalDatabaseService.rules.piecesCount;
    pieceToRemoveCount = 0;

    // TODO:
    // MoveList<LEGAL>::create();
    // create_mill_table();

    currentSquare = 0;

    record = null;

    return true;
  }

  bool start() {
    gameOverReason = GameOverReason.noReason;

    switch (phase) {
      case Phase.placing:
      case Phase.moving:
        return false;
      case Phase.gameOver:
        reset();
        continue ready;
      ready:
      case Phase.ready:
        phase = Phase.placing;
        return true;
      default:
        return false;
    }
  }

  Future<bool> putPiece(int s) async {
    var piece = PieceColor.none;
    final us = _sideToMove;

    if (phase == Phase.gameOver ||
        action != Act.place ||
        !(sqBegin <= s && s < sqEnd) ||
        board[s] != PieceColor.none) {
      return false;
    }

    if (phase == Phase.ready) start();

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
        board[s] = piece;

        record = Move("(${fileOf(s)},${rankOf(s)})");

        updateKey(s);

        currentSquare = s;

        final int n = millsCount(currentSquare);

        if (n == 0) {
          assert(
            pieceInHandCount[PieceColor.white]! >= 0 &&
                pieceInHandCount[PieceColor.black]! >= 0,
          );

          if (pieceInHandCount[PieceColor.white] == 0 &&
              pieceInHandCount[PieceColor.black] == 0) {
            if (isGameOver()) return true;

            phase = Phase.moving;
            action = Act.select;

            if (LocalDatabaseService.rules.hasBannedLocations) {
              removeBanStones();
            }

            if (!LocalDatabaseService.rules.isDefenderMoveFirst) {
              changeSideToMove();
            }

            if (isGameOver()) return true;
          } else {
            changeSideToMove();
          }
          controller.gameInstance.focusIndex = squareToIndex[s];
          await Audios.playTone(Sound.place);
        } else {
          pieceToRemoveCount =
              LocalDatabaseService.rules.mayRemoveMultiple ? n : 1;
          updateKeyMisc();

          if (LocalDatabaseService
                  .rules.mayOnlyRemoveUnplacedPieceInPlacingPhase &&
              pieceInHandCount[them] != null) {
            pieceInHandCount[them] =
                pieceInHandCount[them]! - 1; // Or pieceToRemoveCount?

            if (pieceInHandCount[them]! < 0) {
              pieceInHandCount[them] = 0;
            }

            if (pieceInHandCount[PieceColor.white] == 0 &&
                pieceInHandCount[PieceColor.black] == 0) {
              if (isGameOver()) return true;

              phase = Phase.moving;
              action = Act.select;

              if (LocalDatabaseService.rules.isDefenderMoveFirst) {
                changeSideToMove();
              }

              if (isGameOver()) return true;
            }
          } else {
            action = Act.remove;
          }

          controller.gameInstance.focusIndex = squareToIndex[s];
          await Audios.playTone(Sound.mill);
        }
        break;
      case Phase.moving:
        if (isGameOver()) return true;

        // if illegal
        if (pieceOnBoardCount[sideToMove]! >
                LocalDatabaseService.rules.flyPieceCount ||
            !LocalDatabaseService.rules.mayFly) {
          int md;

          for (md = 0; md < moveDirectionNumber; md++) {
            if (s == adjacentSquares[currentSquare][md]) break;
          }

          // not in moveTable
          if (md == moveDirectionNumber) {
            logger.i(
              "[position] putPiece: [$s] is not in [$currentSquare]'s move table.",
            );
            return false;
          }
        }

        record = Move(
          "(${fileOf(currentSquare)},${rankOf(currentSquare)})->(${fileOf(s)},${rankOf(s)})",
        );

        st.rule50++;

        board[s] = _grid[squareToIndex[s]!] = board[currentSquare];
        updateKey(s);
        revertKey(currentSquare);

        board[currentSquare] =
            _grid[squareToIndex[currentSquare]!] = PieceColor.none;

        currentSquare = s;
        final int n = millsCount(currentSquare);

        // midgame
        if (n == 0) {
          action = Act.select;
          changeSideToMove();

          if (isGameOver()) return true;
          controller.gameInstance.focusIndex = squareToIndex[s];

          await Audios.playTone(Sound.place);
        } else {
          pieceToRemoveCount =
              LocalDatabaseService.rules.mayRemoveMultiple ? n : 1;
          updateKeyMisc();
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
      return RemoveResponse.r1;
    }

    if (action != Act.remove) return RemoveResponse.r1;

    if (pieceToRemoveCount <= 0) return RemoveResponse.r1;

    // if piece is not their
    if (!(sideToMove.opponent == board[s])) return RemoveResponse.r2;

    if (!LocalDatabaseService.rules.mayRemoveFromMillsAlways &&
        potentialMillsCount(s, PieceColor.nobody) > 0 &&
        !isAllInMills(sideToMove.opponent)) {
      return RemoveResponse.r3;
    }

    revertKey(s);

    await Audios.playTone(Sound.remove);

    if (LocalDatabaseService.rules.hasBannedLocations &&
        phase == Phase.placing) {
      // Remove and put ban
      board[s] = _grid[squareToIndex[s]!] = PieceColor.ban;
      updateKey(s);
    } else {
      // Remove only
      board[s] = _grid[squareToIndex[s]!] = PieceColor.none;
    }

    record = Move("-(${fileOf(s)},${rankOf(s)})");
    st.rule50 = 0; // TODO: Need to move out?

    if (pieceOnBoardCount[them] != null) {
      pieceOnBoardCount[them] = pieceOnBoardCount[them]! - 1;
    }

    if (pieceOnBoardCount[them]! + pieceInHandCount[them]! <
        LocalDatabaseService.rules.piecesAtLeastCount) {
      setGameOver(sideToMove, GameOverReason.loseReasonlessThanThree);
      return RemoveResponse.r0;
    }

    currentSquare = 0;

    pieceToRemoveCount--;
    updateKeyMisc();

    if (pieceToRemoveCount != 0) {
      return RemoveResponse.r0;
    }

    if (phase == Phase.placing) {
      if (pieceInHandCount[PieceColor.white] == 0 &&
          pieceInHandCount[PieceColor.black] == 0) {
        phase = Phase.moving;
        action = Act.select;

        if (LocalDatabaseService.rules.hasBannedLocations) {
          removeBanStones();
        }

        if (LocalDatabaseService.rules.isDefenderMoveFirst) {
          isGameOver();
          return RemoveResponse.r0;
        }
      } else {
        action = Act.place;
      }
    } else {
      action = Act.select;
    }

    changeSideToMove();
    isGameOver();

    return RemoveResponse.r0;
  }

  SelectionResponse selectPiece(int sq) {
    if (phase != Phase.moving) return SelectionResponse.r2;

    if (action != Act.select && action != Act.place) {
      return SelectionResponse.r1;
    }

    if (board[sq] == PieceColor.none) {
      return SelectionResponse.r3;
    }

    if (!(board[sq] == sideToMove)) {
      return SelectionResponse.r4;
    }

    currentSquare = sq;
    action = Act.place;
    controller.gameInstance.blurIndex = squareToIndex[sq];

    return SelectionResponse.r0;
  }

  bool resign(PieceColor loser) {
    if (phase == Phase.ready ||
        phase == Phase.gameOver ||
        phase == Phase.none) {
      return false;
    }

    setGameOver(loser.opponent, GameOverReason.loseReasonResign);

    return true;
  }

  PieceColor get winner => _winner;

  void setGameOver(PieceColor w, GameOverReason reason) {
    phase = Phase.gameOver;
    gameOverReason = reason;
    _winner = w;

    logger.i("[position] Game over, $w win, because of $reason");
    updateScore();
  }

  void updateScore() {
    if (phase == Phase.gameOver) {
      score[_winner] = score[_winner]! + 1;
    }
  }

  bool get isThreeEndgame {
    if (phase == Phase.placing) {
      return false;
    }

    return pieceOnBoardCount[PieceColor.white] == 3 ||
        pieceOnBoardCount[PieceColor.black] == 3;
  }

  bool isGameOver() {
    if (phase == Phase.ready || phase == Phase.gameOver) {
      return true;
    }

    if (LocalDatabaseService.rules.nMoveRule > 0 &&
        posKeyHistory.length >= LocalDatabaseService.rules.nMoveRule) {
      setGameOver(PieceColor.draw, GameOverReason.drawReasonRule50);
      return true;
    }

    if (LocalDatabaseService.rules.endgameNMoveRule <
            LocalDatabaseService.rules.nMoveRule &&
        isThreeEndgame &&
        posKeyHistory.length >= LocalDatabaseService.rules.endgameNMoveRule) {
      setGameOver(PieceColor.draw, GameOverReason.drawReasonEndgameRule50);
      return true;
    }

    if (pieceOnBoardCount[PieceColor.white]! +
            pieceOnBoardCount[PieceColor.black]! >=
        rankNumber * fileNumber) {
      if (LocalDatabaseService.rules.isWhiteLoseButNotDrawWhenBoardFull) {
        setGameOver(PieceColor.black, GameOverReason.loseReasonBoardIsFull);
      } else {
        setGameOver(PieceColor.draw, GameOverReason.drawReasonBoardIsFull);
      }

      return true;
    }

    if (phase == Phase.moving && action == Act.select && isAllSurrounded) {
      if (LocalDatabaseService.rules.isLoseButNotChangeSideWhenNoWay) {
        setGameOver(
          sideToMove.opponent,
          GameOverReason.loseReasonNoWay,
        );
        return true;
      } else {
        changeSideToMove(); // TODO: Need?
        return false;
      }
    }

    return false;
  }

  void removeBanStones() {
    assert(LocalDatabaseService.rules.hasBannedLocations);

    int s = 0;

    for (int f = 1; f <= fileNumber; f++) {
      for (int r = 0; r < rankNumber; r++) {
        s = f * rankNumber + r;

        if (board[s] == PieceColor.ban) {
          board[s] = _grid[squareToIndex[s]!] = PieceColor.none;
          revertKey(s);
        }
      }
    }
  }

  void setSideToMove(PieceColor color) {
    _sideToMove = color;
    //us = color;
    them = _sideToMove.opponent;
  }

  void changeSideToMove() {
    setSideToMove(_sideToMove.opponent);
    st.key ^= Zobrist.side;
    logger.v("[position] $_sideToMove to move.");

    /*
    if (phase == Phase.moving &&
        !rule.isLoseButNotChangeSideWhenNoWay &&
        isAllSurrounded() &&
        !rule.mayFly &&
        pieceOnBoardCount[sideToMove()]! >= rule.piecesAtLeastCount) {
      logger.v("[position] $_sideToMove is no way to go.");
      changeSideToMove();
    }
    */
  }

  int updateKey(int s) {
    final PieceColor pieceType = colorOn(s);

    return st.key ^= Zobrist.psq[pieceType.index][s];
  }

  int revertKey(int s) {
    return updateKey(s);
  }

  int updateKeyMisc() {
    st.key = st.key << Zobrist.keyMiscBit >> Zobrist.keyMiscBit;

    st.key |= pieceToRemoveCount << (32 - Zobrist.keyMiscBit);

    return st.key;
  }

  ///////////////////////////////////////////////////////////////////////////////

  PieceColor colorOn(int sq) {
    return board[sq];
  }

  int potentialMillsCount(int to, PieceColor c, {int from = 0}) {
    int n = 0;
    PieceColor locbak = PieceColor.none;
    PieceColor _c = c;

    assert(0 <= from && from < sqNumber);

    if (_c == PieceColor.nobody) {
      _c = colorOn(to);
    }

    if (from != 0 && from >= sqBegin && from < sqEnd) {
      locbak = board[from];
      board[from] = _grid[squareToIndex[from]!] = PieceColor.none;
    }

    for (int ld = 0; ld < lineDirectionNumber; ld++) {
      if (_c == board[millTable[to][ld][0]] &&
          _c == board[millTable[to][ld][1]]) {
        n++;
      }
    }

    if (from != 0) {
      board[from] = _grid[squareToIndex[from]!] = locbak;
    }

    return n;
  }

  int millsCount(int s) {
    int n = 0;
    final List<int?> idx = [0, 0, 0];
    int min = 0;
    int? temp = 0;
    final PieceColor m = colorOn(s);

    for (int i = 0; i < idx.length; i++) {
      idx[0] = s;
      idx[1] = millTable[s][i][0];
      idx[2] = millTable[s][i][1];

      // no mill
      if (!(m == board[idx[1]!] && m == board[idx[2]!])) {
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

  bool isAllInMills(PieceColor c) {
    for (int i = sqBegin; i < sqEnd; i++) {
      if (board[i] == c) {
        if (potentialMillsCount(i, PieceColor.nobody) == 0) {
          return false;
        }
      }
    }

    return true;
  }

  bool get isAllSurrounded {
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
      if (!(sideToMove == colorOn(s))) {
        continue;
      }

      for (int d = moveDirectionBegin; d < moveDirectionNumber; d++) {
        final int moveSquare = adjacentSquares[s][d];
        if (moveSquare != 0 && board[moveSquare] == PieceColor.none) {
          return false;
        }
      }
    }

    return true;
  }

  bool isStarSquare(int s) {
    if (LocalDatabaseService.rules.hasDiagonalLines) {
      return s == 17 || s == 19 || s == 21 || s == 23;
    }

    return s == 16 || s == 18 || s == 20 || s == 22;
  }

  ///////////////////////////////////////////////////////////////////////////////

  int get nPiecesInHand {
    pieceInHandCount[PieceColor.white] =
        LocalDatabaseService.rules.piecesCount -
            pieceOnBoardCount[PieceColor.white]!;
    pieceInHandCount[PieceColor.black] =
        LocalDatabaseService.rules.piecesCount -
            pieceOnBoardCount[PieceColor.black]!;

    return pieceOnBoardCount[PieceColor.white]! +
        pieceOnBoardCount[PieceColor.black]!;
  }

  void clearBoard() {
    for (int i = 0; i < _grid.length; i++) {
      _grid[i] = PieceColor.none;
    }

    for (int i = 0; i < board.length; i++) {
      board[i] = PieceColor.none;
    }
  }

  int setPosition() {
    result = GameResult.pending;

    gamePly = 0;
    st.rule50 = 0;
    st.pliesFromNull = 0;

    gameOverReason = GameOverReason.noReason;
    phase = Phase.placing;
    setSideToMove(PieceColor.white);
    action = Act.place;
    currentSquare = 0;

    record = null;

    clearBoard();
    // TODO: [Leptopoda] use null
    if (pieceOnBoardCountCount() == -1) {
      return -1;
    }

    nPiecesInHand;
    pieceToRemoveCount = 0;

    _winner = PieceColor.nobody;
    adjacentSquares = Mills.adjacentSquaresInit;
    millTable = Mills.millTableInit;
    currentSquare = 0;

    return -1;
  }

  int pieceOnBoardCountCount() {
    pieceOnBoardCount[PieceColor.white] =
        pieceOnBoardCount[PieceColor.black] = 0;

    for (int f = 1; f < fileExNumber; f++) {
      for (int r = 0; r < rankNumber; r++) {
        final int s = f * rankNumber + r;
        if (board[s] == PieceColor.white) {
          pieceOnBoardCount[PieceColor.white] =
              pieceOnBoardCount[PieceColor.white]! + 1;
        } else if (board[s] == PieceColor.black) {
          pieceOnBoardCount[PieceColor.black] =
              pieceOnBoardCount[PieceColor.black]! + 1;
        }
      }
    }

    if (pieceOnBoardCount[PieceColor.white]! >
            LocalDatabaseService.rules.piecesCount ||
        pieceOnBoardCount[PieceColor.black]! >
            LocalDatabaseService.rules.piecesCount) {
      return -1;
    }

    return pieceOnBoardCount[PieceColor.white]! +
        pieceOnBoardCount[PieceColor.black]!;
  }

///////////////////////////////////////////////////////////////////////////////
  Future<HistoryResponse?> gotoHistory(HistoryMove move, [int? index]) async {
    final int moveIndex = _gotoHistoryIndex(move, index);

    if (recorder.cur == moveIndex) {
      logger.i("[goto] cur is equal to moveIndex.");
      return HistoryResponse.equal;
    }

    // TODO: [Leptopoda] use null
    if (moveIndex < -1 || recorder.moveCount <= moveIndex) {
      logger.i("[goto] moveIndex is out of range.");
      return HistoryResponse.outOfRange;
    }

    Audios.isTemporaryMute = true;

    // Backup context
    final engineTypeBackup = controller.gameInstance.engineType;
    controller.gameInstance.setWhoIsAi(EngineType.humanVsHuman);
    final historyBack = recorder.moves;
    controller.gameInstance.newGame();

    HistoryResponse? error;
    // TODO: [Leptopoda] throw errors instead of returning bools
    for (var i = 0; i <= moveIndex; i++) {
      if (!(await controller.gameInstance.doMove(historyBack[i]))) {
        error = HistoryResponse.error;
        break;
      }
    }

    // Restore context
    controller.gameInstance.setWhoIsAi(engineTypeBackup);
    recorder.moves = historyBack;
    recorder.cur = moveIndex;

    Audios.isTemporaryMute = false;
    await _gotoHistoryPlaySound(move);
    return error;
  }

  // TODO: [Leptopoda] use null
  int _gotoHistoryIndex(HistoryMove move, [int? index]) {
    switch (move) {
      case HistoryMove.forwardAll:
        return recorder.moveCount - 1;
      case HistoryMove.backAll:
        return -1;
      case HistoryMove.forward:
        return recorder.cur + 1;
      case HistoryMove.backN:
        assert(index != null);
        int _index = recorder.cur - index!;
        if (_index < -1) {
          _index = -1;
        }
        return _index;
      case HistoryMove.backOne:
        return recorder.cur - 1;
    }
  }

  Future<void> _gotoHistoryPlaySound(HistoryMove move) async {
    if (!LocalDatabaseService.preferences.keepMuteWhenTakingBack) {
      switch (move) {
        case HistoryMove.forwardAll:
        case HistoryMove.forward:
          await Audios.playTone(Sound.place);
          break;
        case HistoryMove.backAll:
        case HistoryMove.backN:

        case HistoryMove.backOne:
          await Audios.playTone(Sound.remove);
      }
    }
  }

  String? get movesSinceLastRemove {
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

  String? get moveHistoryText => recorder.buildMoveHistoryText();

  PieceColor get side => _sideToMove;

  Move? get lastMove => recorder.lastMove;

  String? get lastPositionWithRemove => recorder.lastPositionWithRemove;
}

enum HistoryMove { forwardAll, backAll, forward, backN, backOne }