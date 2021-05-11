﻿/*
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

#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <vector>
#include <cstdlib>

#if defined(__linux__) && !defined(__ANDROID__)
#include <stdlib.h>
#include <sys/mman.h>
#endif

#if defined(__APPLE__) || defined(__ANDROID__) || defined(__OpenBSD__) || (defined(__GLIBCXX__) && !defined(_GLIBCXX_HAVE_ALIGNED_ALLOC) && !defined(_WIN32))
#define POSIXALIGNEDALLOC
#include <stdlib.h>
#endif

#include "misc.h"
#include "thread.h"

using namespace std;

namespace
{

/// Version number. If Version is left empty, then compile date in the format
/// DD-MM-YY and show in engine_info.
const string Version = "";

} // namespace


/// Used to serialize access to std::cout to avoid multiple threads writing at
/// the same time.

std::ostream &operator<<(std::ostream &os, SyncCout sc)
{
    static std::mutex m;

    if (sc == IO_LOCK)
        m.lock();

    if (sc == IO_UNLOCK)
        m.unlock();

    return os;
}


/// prefetch() preloads the given address in L1/L2 cache. This is a non-blocking
/// function that doesn't stall the CPU waiting for data to be loaded from memory,
/// which can be quite slow.
#ifdef NO_PREFETCH

void prefetch(void *)
{
}

#else

void prefetch(void *addr)
{
#  if defined(__INTEL_COMPILER)
    // This hack prevents prefetches from being optimized away by
    // Intel compiler. Both MSVC and gcc seem not be affected by this.
    __asm__("");
#  endif

#  if defined(__INTEL_COMPILER) || defined(_MSC_VER)
    _mm_prefetch((char *)addr, _MM_HINT_T0);
#  else
    __builtin_prefetch(addr);
#  endif
}

#ifndef PREFETCH_STRIDE
/* L1 cache line size */
#define L1_CACHE_SHIFT	7
#define L1_CACHE_BYTES	(1 << L1_CACHE_SHIFT)

#define PREFETCH_STRIDE (4 * L1_CACHE_BYTES)
#endif

void prefetch_range(void *addr, size_t len)
{
    char *cp = nullptr;
    const char *end = (char *)addr + len;

    for (cp = (char *)addr; cp < end; cp += PREFETCH_STRIDE)
        prefetch(cp);
}

#endif
