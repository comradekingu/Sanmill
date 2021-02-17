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

import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../common/config.dart';
import '../common/profile.dart';
import 'ranks.dart';

class Player extends RankItem {
  //
  static Player _instance;
  String _uuid;

  static get shared => _instance;

  static Future<Player> loadProfile() async {
    if (_instance == null) {
      _instance = Player();
      await _instance._load();
    }

    return _instance;
  }

  _load() async {
    final profile = await Profile.shared();

    await Config.loadProfile();

    _uuid = profile['player-uuid'];

    if (_uuid == null) {
      profile['player-uuid'] = _uuid = Uuid().v1();
    } else {
      //
      final playerInfoJson = profile['_rank-player-info'] ?? '{}';
      final values = jsonDecode(playerInfoJson);

      name = values['name'] ?? 'Anonymous';
      winCloudEngine = values['win_cloud_engine'] ?? 0;
      winAi = values['win_ai'] ?? 0;
    }
  }

  Player() : super.empty();

  Future<void> increaseWinAi() async {
    winAi++;
    await saveAndUpload();
  }

  Future<void> saveAndUpload() async {
    //
    final profile = await Profile.shared();
    profile['_rank-player-info'] = jsonEncode(toMap());
    profile.commit();

    await Ranks.mockUpload(uuid: _uuid, rank: this);
  }
}