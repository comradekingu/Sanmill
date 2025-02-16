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

part of '../adapters.dart';

/// Algorithm Adapter
///
/// This adapter provides helper functions to be used with [JsonSerializable]
class AlgorithmAdapter {
  const AlgorithmAdapter._();

  static int? algorithmToJson(Algorithms? algorithm) => algorithm?.index;
  static Algorithms? algorithmFromJson(int? value) {
    if (value != null) {
      return Algorithms.values[value];
    }
  }
}
