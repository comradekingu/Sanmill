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

#include "bitboard.h"
#include "position.h"
#include "search.h"
#include "thread.h"
#include "uci.h"

#ifdef FLUTTER_UI
#include "engine_main.h"
#endif

#ifndef QT_GUI_LIB

int main(int argc, char* argv[]) {

#ifdef FLUTTER_UI
  println("uciok");
#endif

  UCI::init(Options);
  Bitboards::init();
  Position::init();
  if (mainThread == nullptr) {
      mainThread = new Thread();
  }
  mainThread->set(1);
  Search::clear(); // After threads are up

  UCI::loop(argc, argv);

  mainThread->set(0);
  return 0;
}
#endif
