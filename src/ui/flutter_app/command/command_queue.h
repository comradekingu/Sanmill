// This file is part of Sanmill.
// Copyright (C) 2019-2021 The Sanmill developers (see AUTHORS file)
//
// Sanmill is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Sanmill is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

#ifndef COMMAND_QUEUE_H
#define COMMAND_QUEUE_H

#include <mutex>

class CommandQueue
{
    enum {
        MAX_COMMAND_COUNT = 128,
        COMMAND_LENGTH = 4096,
    };

    char commands[MAX_COMMAND_COUNT][COMMAND_LENGTH];
    int readIndex, writeIndex;

    std::mutex mutex;

public:
    CommandQueue();

    bool write(const char *command);
    bool read(char *dest);
};

#endif /* COMMAND_QUEUE_H */
