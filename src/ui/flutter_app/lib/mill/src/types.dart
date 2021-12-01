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

int abs(int value) => value > 0 ? value : -value;

class Move {
  static const _invalidMove = -1;

  // Square
  int from = 0;
  int to = 0;

  // file & rank
  int _fromFile = 0;
  int _fromRank = 0;
  int _toFile = 0;
  int _toRank = 0;

  // 'move' is the UCI engine's move-string
  final String move;

  // "notation" is Standard Notation
  late final String notation;

  late final MoveType type;

  // TODO: [Leptopoda] attributes should probably be made getters
  Move(this.move) {
    if (!_isLegal) {
      throw "Error: Invalid Move: $move";
    }

    if (move[0] == "-" && move.length == "-(1,2)".length) {
      type = MoveType.remove;
      from = _fromFile = _fromRank = _invalidMove;
      _toFile = int.parse(move[2]);
      _toRank = int.parse(move[4]);
      to = makeSquare(_toFile, _toRank);
      notation = "x${_squareToWmdNotation[to]}";
      //captured = PieceColor.none;
    } else if (move.length == "(1,2)->(3,4)".length) {
      type = MoveType.move;
      _fromFile = int.parse(move[1]);
      _fromRank = int.parse(move[3]);
      from = makeSquare(_fromFile, _fromRank);
      _toFile = int.parse(move[8]);
      _toRank = int.parse(move[10]);
      to = makeSquare(_toFile, _toRank);
      notation = "${_squareToWmdNotation[from]}-${_squareToWmdNotation[to]}";
    } else if (move.length == "(1,2)".length) {
      type = MoveType.place;
      // TODO: [Leptopoda] remove stringy thing
      from = _fromFile = _fromRank = _invalidMove;
      _toFile = int.parse(move[1]);
      _toRank = int.parse(move[3]);
      to = makeSquare(_toFile, _toRank);
      notation = "${_squareToWmdNotation[to]}";
    } else if (move == "draw") {
      assert(false, "not yet implemented"); // TODO
      logger.v("[TODO] Computer request draw");
    } else {
      assert(false);
    }
  }

  bool get _isLegal {
    if (move == "draw") {
      return true; // TODO
    }

    if (move.length > "(3,1)->(2,1)".length) return false;

    const String range = "0123456789(,)->";

    if (!(move[0] == "(" || move[0] == "-")) {
      return false;
    }

    if (move[move.length - 1] != ")") {
      return false;
    }

    for (int i = 0; i < move.length; i++) {
      if (!range.contains(move[i])) return false;
    }

    if (move.length == "(3,1)->(2,1)".length) {
      if (move.substring(0, 4) == move.substring(7, 11)) {
        return false;
      }
    }

    return true;
  }

  @override
  int get hashCode => move.hashCode;

  @override
  bool operator ==(Object other) => other is Move && other.move == move;
}

enum MoveType { place, move, remove, none }

enum PieceColor {
  none,
  white,
  black,
  ban,
  nobody,
  draw,
}

extension PieceColorExtension on PieceColor {
  @Deprecated("this is the old representation and not needed anymore")
  String get string {
    switch (this) {
      case PieceColor.none:
        return "*";
      case PieceColor.white:
        return "O";
      case PieceColor.black:
        return "@";
      case PieceColor.ban:
        return "X";
      case PieceColor.nobody:
        return "-";
      case PieceColor.draw:
        return "=";
    }
  }

  String playerName(BuildContext context) {
    switch (this) {
      case PieceColor.white:
        return S.of(context).white;
      case PieceColor.black:
        return S.of(context).black;
      case PieceColor.none:
        return S.of(context).none;
      case PieceColor.draw:
        return S.of(context).draw;
      case PieceColor.ban:
      case PieceColor.nobody:
        throw Exception("Player has no name");
    }
  }

  String pieceName(BuildContext context) {
    switch (this) {
      case PieceColor.white:
        return S.of(context).whitePiece;
      case PieceColor.black:
        return S.of(context).blackPiece;
      case PieceColor.ban:
        return S.of(context).banPoint;
      case PieceColor.none:
        return S.of(context).emptyPoint;
      default:
        throw Exception("No piece name available");
    }
  }

  PieceColor get opponent {
    switch (this) {
      case PieceColor.black:
        return PieceColor.white;
      case PieceColor.white:
        return PieceColor.black;
      default:
        return this;
    }
  }

  String getWinString(BuildContext context) {
    switch (this) {
      case PieceColor.white:
        return S.of(context).whiteWin;
      case PieceColor.black:
        return S.of(context).blackWin;
      case PieceColor.draw:
        return S.of(context).isDraw;
      case PieceColor.nobody:
        return controller.position.phase.getTip(context);
      default:
        throw Exception("No winnig string available");
    }
  }
}

enum Phase { none, ready, placing, moving, gameOver }

extension PhaseExtension on Phase {
  String get fen {
    switch (this) {
      case Phase.none:
        return "n";
      case Phase.ready:
        return "r";
      case Phase.placing:
        return "p";
      case Phase.moving:
        return "m";
      case Phase.gameOver:
        return "o";
      default:
        return "?";
    }
  }

  String getTip(BuildContext context) {
    switch (controller.position.phase) {
      case Phase.placing:
        return S.of(context).tipPlace;
      case Phase.moving:
        return S.of(context).tipMove;
      default:
        throw Exception("No tip available");
    }
  }

  String getName(BuildContext context) {
    switch (this) {
      case Phase.placing:
        return S.of(context).placingPhase;
      case Phase.moving:
        return S.of(context).movingPhase;
      default:
        throw Exception("No name available");
    }
  }
}

enum Act { none, select, place, remove }

extension ActExtension on Act {
  String get fen {
    switch (this) {
      case Act.place:
        return "p";
      case Act.select:
        return "s";
      case Act.remove:
        return "r";
      default:
        return "?";
    }
  }
}

enum GameOverReason {
  noReason,
  loseReasonlessThanThree,
  loseReasonNoWay,
  loseReasonBoardIsFull,
  loseReasonResign,
  loseReasonTimeOver,
  drawReasonThreefoldRepetition,
  drawReasonRule50,
  drawReasonEndgameRule50,
  drawReasonBoardIsFull
}

extension GameOverReasonExtension on GameOverReason {
  String getName(BuildContext context, PieceColor winner) {
    final String loserStr = winner.opponent.playerName(context);

    switch (this) {
      case GameOverReason.loseReasonlessThanThree:
        return S.of(context).loseReasonlessThanThree(loserStr);
      case GameOverReason.loseReasonResign:
        return S.of(context).loseReasonResign(loserStr);
      case GameOverReason.loseReasonNoWay:
        return S.of(context).loseReasonNoWay(loserStr);
      case GameOverReason.loseReasonBoardIsFull:
        return S.of(context).loseReasonBoardIsFull(loserStr);
      case GameOverReason.loseReasonTimeOver:
        return S.of(context).loseReasonTimeOver(loserStr);
      case GameOverReason.drawReasonRule50:
        return S.of(context).drawReasonRule50;
      case GameOverReason.drawReasonEndgameRule50:
        return S.of(context).drawReasonEndgameRule50;
      case GameOverReason.drawReasonBoardIsFull:
        return S.of(context).drawReasonBoardIsFull;
      case GameOverReason.drawReasonThreefoldRepetition:
        return S.of(context).drawReasonThreefoldRepetition;
      case GameOverReason.noReason:
        return S.of(context).gameOverUnknownReason;
    }
  }
}

const sqBegin = 8;
const sqEnd = 32;
const sqNumber = 40;

const moveDirectionBegin = 0;
const moveDirectionNumber = 4;

const lineDirectionNumber = 3;

const fileNumber = 3;
const fileExNumber = fileNumber + 2;

const rankNumber = 8;

int makeSquare(int file, int rank) {
  return (file << 3) + rank - 1;
}

bool isOk(int sq) {
  final bool ret = sq == 0 || (sq >= sqBegin && sq < sqEnd);

  if (!ret) {
    logger.w("[types] $sq is not OK");
  }

  return ret; // TODO: SQ_NONE?
}

int fileOf(int sq) {
  return sq >> 3;
}

int rankOf(int sq) {
  return (sq & 0x07) + 1;
}

int fromSq(int move) {
  return abs(move) >> 8;
}

int toSq(int move) {
  return abs(move) & 0x00FF;
}

int makeMove(int from, int to) {
  return (from << 8) + to;
}

Map<int, int> squareToIndex = {
  8: 17,
  9: 18,
  10: 25,
  11: 32,
  12: 31,
  13: 30,
  14: 23,
  15: 16,
  16: 10,
  17: 12,
  18: 26,
  19: 40,
  20: 38,
  21: 36,
  22: 22,
  23: 8,
  24: 3,
  25: 6,
  26: 27,
  27: 48,
  28: 45,
  29: 42,
  30: 21,
  31: 0
};

Map<int, int> indexToSquare = squareToIndex.map((k, v) => MapEntry(v, k));

/*
          a b c d e f g
        7 X --- X --- X 7
          |\    |    /|
        6 | X - X - X | 6
          | |\  |  /| |
        5 | | X-X-X | | 5
        4 X-X-X   X-X-X 4
        3 | | X-X-X | | 3
          | |/  |  \| |
        2 | X - X - X | 2
          |/    |    \|
        1 X --- X --- X 1
          a b c d e f g
 */
Map<int, String> _squareToWmdNotation = {
  8: "d5",
  9: "e5",
  10: "e4",
  11: "e3",
  12: "d3",
  13: "c3",
  14: "c4",
  15: "c5",
  16: "d6",
  17: "f6",
  18: "f4",
  19: "f2",
  20: "d2",
  21: "b2",
  22: "b4",
  23: "b6",
  24: "d7",
  25: "g7",
  26: "g4",
  27: "g1",
  28: "d1",
  29: "a1",
  30: "a4",
  31: "a7"
};

Map<String, String> wmdNotationToMove = {
  "d5": "(1,1)",
  "e5": "(1,2)",
  "e4": "(1,3)",
  "e3": "(1,4)",
  "d3": "(1,5)",
  "c3": "(1,6)",
  "c4": "(1,7)",
  "c5": "(1,8)",
  "d6": "(2,1)",
  "f6": "(2,2)",
  "f4": "(2,3)",
  "f2": "(2,4)",
  "d2": "(2,5)",
  "b2": "(2,6)",
  "b4": "(2,7)",
  "b6": "(2,8)",
  "d7": "(3,1)",
  "g7": "(3,2)",
  "g4": "(3,3)",
  "g1": "(3,4)",
  "d1": "(3,5)",
  "a1": "(3,6)",
  "a4": "(3,7)",
  "a7": "(3,8)",
};

Map<String, String> playOkNotationToMove = {
  "8": "(1,1)",
  "9": "(1,2)",
  "13": "(1,3)",
  "18": "(1,4)",
  "17": "(1,5)",
  "16": "(1,6)",
  "12": "(1,7)",
  "7": "(1,8)",
  "5": "(2,1)",
  "6": "(2,2)",
  "14": "(2,3)",
  "21": "(2,4)",
  "20": "(2,5)",
  "19": "(2,6)",
  "11": "(2,7)",
  "4": "(2,8)",
  "2": "(3,1)",
  "3": "(3,2)",
  "15": "(3,3)",
  "24": "(3,4)",
  "23": "(3,5)",
  "22": "(3,6)",
  "10": "(3,7)",
  "1": "(3,8)",
};

enum GameResult { pending, win, lose, draw, none }

extension GameResultExtension on GameResult {
  String winString(BuildContext context) {
    switch (this) {
      case GameResult.win:
        return controller.gameInstance.engineType == EngineType.humanVsAi
            ? S.of(context).youWin
            : S.of(context).gameOver;
      case GameResult.lose:
        return S.of(context).gameOver;
      case GameResult.draw:
        return S.of(context).isDraw;
      default:
        throw Exception("No result specified");
    }
  }
}