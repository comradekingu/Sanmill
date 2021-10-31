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

part of 'package:sanmill/screens/personalization_settings/personalization_settings_page.dart';

class _PieceWidthSlider extends StatelessWidget {
  const _PieceWidthSlider({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: AppTheme.sliderThemeData,
      child: Semantics(
        label: S.of(context).pieceWidth,
        child: ValueListenableBuilder(
          valueListenable: LocalDatabaseService.listenDisplay,
          builder: (context, Box<Display> displayBox, _) {
            final Display _display = displayBox.get(
              LocalDatabaseService.colorSettingsKey,
              defaultValue: Display(),
            )!;

            return Slider(
              value: _display.pieceWidth,
              min: 0.5,
              divisions: 50,
              label: _display.pieceWidth.toStringAsFixed(1),
              onChanged: (value) {
                debugPrint("[config] pieceWidth value: $value");
                LocalDatabaseService.display =
                    _display.copyWith(pieceWidth: value);
              },
            );
          },
        ),
      ),
    );
  }
}
