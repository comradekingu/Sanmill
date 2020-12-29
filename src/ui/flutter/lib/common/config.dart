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

import 'package:sanmill/mill/game.dart';
import 'package:sanmill/mill/rule.dart';

import 'profile.dart';

class Config {
  static bool bgmEnabled = false;
  static bool toneEnabled = true;
  static int thinkingTime = 5000;
  static PlayerType whoMovesFirst = PlayerType.human;

  static bool isAutoRestart = false;
  static bool isAutoChangeFirstMove = false;
  static bool resignIfMostLose = false;
  static bool shufflingEnabled = true;
  static bool learnEndgame = false;
  static bool idsEnabled = false;
  static bool depthExtension = true;
  static bool openingBook = false;

  // Rules
  static int nTotalPiecesEachSide = 12;
  static int nPiecesAtLeast = 3;
  static bool hasObliqueLines = true;
  static bool hasBannedLocations = true;
  static bool isDefenderMoveFirst = true;
  static bool allowRemoveMultiPiecesWhenCloseMultiMill = false;
  static bool allowRemovePieceInMill = true;
  static bool isBlackLoseButNotDrawWhenBoardFull = true;
  static bool isLoseButNotChangeSideWhenNoWay = true;
  static bool flyingAllowed = false;
  static int maxStepsLedToDraw = 50;

  static Future<void> loadProfile() async {
    final profile = await Profile.shared();

    Config.bgmEnabled = profile['bgm-enabled'] ?? false;
    Config.toneEnabled = profile['tone-enabled'] ?? true;
    Config.thinkingTime = profile['thinking-time'] ?? 5000;
    Config.whoMovesFirst = profile['who-moves-first'] ?? PlayerType.human;

    Config.isAutoRestart = profile['isAutoRestart'] ?? false;
    Config.isAutoChangeFirstMove = profile['isAutoChangeFirstMove'] ?? false;
    Config.resignIfMostLose = profile['resignIfMostLose'] ?? false;
    Config.shufflingEnabled = profile['shufflingEnabled'] ?? true;
    Config.learnEndgame = profile['learnEndgame'] ?? false;
    Config.idsEnabled = profile['idsEnabled'] ?? false;
    Config.depthExtension = profile['depthExtension'] ?? false;
    Config.openingBook = profile['openingBook'] ?? false;

    // Rules
    rule.nTotalPiecesEachSide =
        Config.nTotalPiecesEachSide = profile['nTotalPiecesEachSide'] ?? 12;
    rule.nPiecesAtLeast =
        Config.nPiecesAtLeast = profile['nPiecesAtLeast'] ?? 3;
    rule.hasObliqueLines =
        Config.hasObliqueLines = profile['hasObliqueLines'] ?? true;
    rule.hasBannedLocations =
        Config.hasBannedLocations = profile['hasBannedLocations'] ?? true;
    rule.isDefenderMoveFirst =
        Config.isDefenderMoveFirst = profile['isDefenderMoveFirst'] ?? true;
    rule.allowRemoveMultiPiecesWhenCloseMultiMill =
        Config.allowRemoveMultiPiecesWhenCloseMultiMill =
            profile['allowRemoveMultiPiecesWhenCloseMultiMill'] ?? false;
    rule.allowRemovePieceInMill = Config.allowRemovePieceInMill =
        profile['allowRemovePieceInMill'] ?? true;
    rule.isBlackLoseButNotDrawWhenBoardFull =
        Config.isBlackLoseButNotDrawWhenBoardFull =
            profile['isBlackLoseButNotDrawWhenBoardFull'] ?? true;
    rule.isLoseButNotChangeSideWhenNoWay =
        Config.isLoseButNotChangeSideWhenNoWay =
            profile['isLoseButNotChangeSideWhenNoWay'] ?? true;
    rule.flyingAllowed =
        Config.flyingAllowed = profile['flyingAllowed'] ?? false;
    rule.maxStepsLedToDraw =
        Config.maxStepsLedToDraw = profile['maxStepsLedToDraw'] ?? 50;

    return true;
  }

  static Future<bool> save() async {
    final profile = await Profile.shared();

    profile['bgm-enabled'] = Config.bgmEnabled;
    profile['tone-enabled'] = Config.toneEnabled;
    profile['thinking-time'] = Config.thinkingTime;
    profile['who-moves-first'] = Config.whoMovesFirst;

    profile['isAutoRestart'] = Config.isAutoRestart;
    profile['isAutoChangeFirstMove'] = Config.isAutoChangeFirstMove;
    profile['resignIfMostLose'] = Config.resignIfMostLose;
    profile['shufflingEnabled'] = Config.shufflingEnabled;
    profile['learnEndgame'] = Config.learnEndgame;
    profile['idsEnabled'] = Config.idsEnabled;
    profile['depthExtension'] = Config.depthExtension;
    profile['openingBook'] = Config.openingBook;

    // Rules
    profile['nTotalPiecesEachSide'] = Config.nTotalPiecesEachSide;
    profile['nPiecesAtLeast'] = Config.nPiecesAtLeast;
    profile['hasObliqueLines'] = Config.hasObliqueLines;
    profile['hasBannedLocations'] = Config.hasBannedLocations;
    profile['isDefenderMoveFirst'] = Config.isDefenderMoveFirst;
    profile['allowRemoveMultiPiecesWhenCloseMultiMill'] =
        Config.allowRemoveMultiPiecesWhenCloseMultiMill;
    profile['allowRemovePieceInMill'] = Config.allowRemovePieceInMill;
    profile['isBlackLoseButNotDrawWhenBoardFull'] =
        Config.isBlackLoseButNotDrawWhenBoardFull;
    profile['isLoseButNotChangeSideWhenNoWay'] =
        Config.isLoseButNotChangeSideWhenNoWay;
    profile['flyingAllowed'] = Config.flyingAllowed;
    profile['maxStepsLedToDraw'] = Config.maxStepsLedToDraw;

    profile.commit();

    return true;
  }
}
