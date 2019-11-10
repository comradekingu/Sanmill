﻿/*
  Sanmill, a mill game playing engine derived from NineChess 1.5
  Copyright (C) 2015-2018 liuweilhy (NineChess author)
  Copyright (C) 2019 Calcitem <calcitem@outlook.com>

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

#include "gamecontroller.h"
#include "trainer.h"

#ifdef TRAINING_MODE

int main(int argc, char *argv[])
{
    loggerDebug("Training start...\n");

    GameController *gameController = new GameController();
    
    gameController->gameReset();
    gameController->gameStart();

    gameController->isAiPlayer[BLACK] = gameController->isAiPlayer[WHITE] = true;

    gameController->setEngine(1, true);
    gameController->setEngine(2, true);

#ifdef WIN32
    system("pause");
#endif

    return 0;
}

#endif // TRAINING_MODE