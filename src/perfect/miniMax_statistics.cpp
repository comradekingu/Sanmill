/*********************************************************************
    miniMax_statistics.cpp
    Copyright (c) Thomas Weber. All rights reserved.
    Copyright (C) 2021 The Sanmill developers (see AUTHORS file)
    Licensed under the GPLv3 License.
    https://github.com/madweasel/Muehle
\*********************************************************************/

#include "config.h"

#ifdef MADWEASEL_MUEHLE_PERFECT_AI

#include "miniMax.h"

//-----------------------------------------------------------------------------
// showMemoryStatus()
//
//-----------------------------------------------------------------------------
uint32_t MiniMax::getThreadCount()
{
    return threadManager.getThreadCount();
}

//-----------------------------------------------------------------------------
// anyFreshlyCalculatedLayer()
// called by MAIN-thread in pMiniMax->csOsPrint critical-section
//-----------------------------------------------------------------------------
bool MiniMax::anyFreshlyCalculatedLayer()
{
    return (lastCalculatedLayer.size() > 0);
}

//-----------------------------------------------------------------------------
// getLastCalculatedLayer()
// called by MAIN-thread in pMiniMax->csOsPrint critical-section
//-----------------------------------------------------------------------------
uint32_t MiniMax::getLastCalculatedLayer()
{
    uint32_t tmp = lastCalculatedLayer.front();
    lastCalculatedLayer.pop_front();
    return tmp;
}

//-----------------------------------------------------------------------------
// isLayerInDatabase()
//
//-----------------------------------------------------------------------------
bool MiniMax::isLayerInDatabase(uint32_t layerNum)
{
    if (layerStats == nullptr)
        return false;
    return layerStats[layerNum].layerIsCompletedAndInFile;
}

//-----------------------------------------------------------------------------
// getLayerSizeInBytes()
//
//-----------------------------------------------------------------------------
int64_t MiniMax::getLayerSizeInBytes(uint32_t layerNum)
{
    if (plyInfos == nullptr || layerStats == nullptr)
        return 0;
    return (int64_t)layerStats[layerNum].sizeInBytes +
           (int64_t)plyInfos[layerNum].sizeInBytes;
}

//-----------------------------------------------------------------------------
// getWonStateCount()
//
//-----------------------------------------------------------------------------
MiniMax::StateNumberVarType MiniMax::getWonStateCount(uint32_t layerNum)
{
    if (layerStats == nullptr)
        return 0;
    return layerStats[layerNum].wonStateCount;
}

//-----------------------------------------------------------------------------
// getLostStateCount()
//
//-----------------------------------------------------------------------------
MiniMax::StateNumberVarType MiniMax::getLostStateCount(uint32_t layerNum)
{
    if (layerStats == nullptr)
        return 0;
    return layerStats[layerNum].lostStateCount;
}

//-----------------------------------------------------------------------------
// getDrawnStateCount()
//
//-----------------------------------------------------------------------------
MiniMax::StateNumberVarType MiniMax::getDrawnStateCount(uint32_t layerNum)
{
    if (layerStats == nullptr)
        return 0;
    return layerStats[layerNum].drawnStateCount;
}

//-----------------------------------------------------------------------------
// getInvalidStateCount()
//
//-----------------------------------------------------------------------------
MiniMax::StateNumberVarType MiniMax::getInvalidStateCount(uint32_t layerNum)
{
    if (layerStats == nullptr)
        return 0;
    return layerStats[layerNum].invalidStateCount;
}

//-----------------------------------------------------------------------------
// showMemoryStatus()
//
//-----------------------------------------------------------------------------
void MiniMax::showMemoryStatus()
{
    MEMORYSTATUSEX memStatus;
    memStatus.dwLength = sizeof(memStatus);
    GlobalMemoryStatusEx(&memStatus);

    cout << endl << "dwMemoryLoad           : " << memStatus.dwMemoryLoad;
    cout << endl
         << "ullAvailExtendedVirtual: " << memStatus.ullAvailExtendedVirtual;
    cout << endl << "ullAvailPageFile       : " << memStatus.ullAvailPageFile;
    cout << endl << "ullAvailPhys           : " << memStatus.ullAvailPhys;
    cout << endl << "ullAvailVirtual        : " << memStatus.ullAvailVirtual;
    cout << endl << "ullTotalPageFile       : " << memStatus.ullTotalPageFile;
    cout << endl << "ullTotalPhys           : " << memStatus.ullTotalPhys;
    cout << endl << "ullTotalVirtual        : " << memStatus.ullTotalVirtual;
}

//-----------------------------------------------------------------------------
// setOutputStream()
//
//-----------------------------------------------------------------------------
void MiniMax::setOutputStream(ostream *theStream,
                              void (*printFunc)(void *pUserData),
                              void *pUserData)
{
    osPrint = theStream;
    pDataForUserPrintFunc = pUserData;
    userPrintFunc = printFunc;
}

//-----------------------------------------------------------------------------
// showLayerStats()
//
//-----------------------------------------------------------------------------
void MiniMax::showLayerStats(uint32_t layerNumber)
{
    // locals
    StateAdress curState;
    uint32_t statsValueCounter[] = {0, 0, 0, 0};
    TwoBit curStateValue;

    // calculate and show statistics
    for (curState.layerNumber = layerNumber, curState.stateNumber = 0;
         curState.stateNumber < layerStats[curState.layerNumber].knotsInLayer;
         curState.stateNumber++) {
        // get state value
        readKnotValueFromDatabase(curState.layerNumber, curState.stateNumber,
                                  curStateValue);
        statsValueCounter[curStateValue]++;
    }

    layerStats[layerNumber].wonStateCount =
        statsValueCounter[SKV_VALUE_GAME_WON];
    layerStats[layerNumber].lostStateCount =
        statsValueCounter[SKV_VALUE_GAME_LOST];
    layerStats[layerNumber].drawnStateCount =
        statsValueCounter[SKV_VALUE_GAME_DRAWN];
    layerStats[layerNumber].invalidStateCount =
        statsValueCounter[SKV_VALUE_INVALID];

    PRINT(1, this, endl << "FINAL STATISTICS OF LAYER " << layerNumber);
    PRINT(1, this, (getOutputInfo(layerNumber)));
    PRINT(1, this,
          " number  states: " << layerStats[curState.layerNumber].knotsInLayer);
    PRINT(1, this,
          " won     states: " << statsValueCounter[SKV_VALUE_GAME_WON]);
    PRINT(1, this,
          " lost    states: " << statsValueCounter[SKV_VALUE_GAME_LOST]);
    PRINT(1, this,
          " draw    states: " << statsValueCounter[SKV_VALUE_GAME_DRAWN]);
    PRINT(1, this, " invalid states: " << statsValueCounter[SKV_VALUE_INVALID]);
}

//-----------------------------------------------------------------------------
// calcLayerStatistics()
//
//-----------------------------------------------------------------------------
bool MiniMax::calcLayerStatistics(char *statisticsFileName)
{
    // locals
    HANDLE statFile;
    DWORD dwBytesWritten;
    StateAdress curState;
    uint32_t *statsValueCounter;
    TwoBit curStateValue;
    char line[10000];
    string text("");

    // database must be open
    if (hFileShortKnotValues == nullptr)
        return false;

    // Open statistics file
    statFile = CreateFileA(statisticsFileName, GENERIC_WRITE,
                           FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                           OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);

    // opened file successfully?
    if (statFile == INVALID_HANDLE_VALUE) {
        statFile = nullptr;
        return false;
    }

    // headline
    text += "layer number\t";
    text += "white pieces\t";
    text += "black pieces\t";
    text += "won states\t";
    text += "lost states\t";
    text += "draw states\t";
    text += "invalid states\t";
    text += "total num states\t";
    text += "num succeeding layers\t";
    text += "partner layer\t";
    text += "size in bytes\t";
    text += "succeedingLayers[0]\t";
    text += "succeedingLayers[1]\n";

    statsValueCounter = new uint32_t[4 * skvfHeader.LayerCount];
    curCalcActionId = MM_ACTION_CALC_LAYER_STATS;

    // calculate and show statistics
    for (layerInDatabase = false, curState.layerNumber = 0;
         curState.layerNumber < skvfHeader.LayerCount; curState.layerNumber++) {
        // status output
        PRINT(0, this,
              "Calculating statistics of layer: " << (int)curState.layerNumber);

        // zero counters
        statsValueCounter[4 * curState.layerNumber + SKV_VALUE_GAME_WON] = 0;
        statsValueCounter[4 * curState.layerNumber + SKV_VALUE_GAME_LOST] = 0;
        statsValueCounter[4 * curState.layerNumber + SKV_VALUE_GAME_DRAWN] = 0;
        statsValueCounter[4 * curState.layerNumber + SKV_VALUE_INVALID] = 0;

        // only calculate stats of completed layers
        if (layerStats[curState.layerNumber].layerIsCompletedAndInFile) {
            for (curState.stateNumber = 0;
                 curState.stateNumber <
                 layerStats[curState.layerNumber].knotsInLayer;
                 curState.stateNumber++) {
                // get state value
                readKnotValueFromDatabase(curState.layerNumber,
                                          curState.stateNumber, curStateValue);
                statsValueCounter[4 * curState.layerNumber + curStateValue]++;
            }

            // free memory
            unloadLayer(curState.layerNumber);
        }

        // add line
        sprintf_s(
            line, "%d\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n",
            curState.layerNumber, getOutputInfo(curState.layerNumber).c_str(),
            statsValueCounter[4 * curState.layerNumber + SKV_VALUE_GAME_WON],
            statsValueCounter[4 * curState.layerNumber + SKV_VALUE_GAME_LOST],
            statsValueCounter[4 * curState.layerNumber + SKV_VALUE_GAME_DRAWN],
            statsValueCounter[4 * curState.layerNumber + SKV_VALUE_INVALID],
            layerStats[curState.layerNumber].knotsInLayer,
            layerStats[curState.layerNumber].succeedingLayerCount,
            layerStats[curState.layerNumber].partnerLayer,
            layerStats[curState.layerNumber].sizeInBytes,
            layerStats[curState.layerNumber].succeedingLayers[0],
            layerStats[curState.layerNumber].succeedingLayers[1]);
        text += line;
    }

    // write to file and close it
    WriteFile(statFile, text.c_str(), (DWORD)text.length(), &dwBytesWritten,
              nullptr);
    CloseHandle(statFile);
    SAFE_DELETE_ARRAY(statsValueCounter);
    return true;
}

//-----------------------------------------------------------------------------
// anyArraryInfoToUpdate()
// called by MAIN-thread in pMiniMax->csOsPrint critical-section
//-----------------------------------------------------------------------------
bool MiniMax::anyArrayInfoToUpdate()
{
    return (arrayInfos.arrayInfosToBeUpdated.size() > 0);
}

//-----------------------------------------------------------------------------
// getArrayInfoForUpdate()
// called by MAIN-thread in pMiniMax->csOsPrint critical-section
//-----------------------------------------------------------------------------
MiniMax::ArrayInfoChange MiniMax::getArrayInfoForUpdate()
{
    MiniMax::ArrayInfoChange tmp = arrayInfos.arrayInfosToBeUpdated.front();
    arrayInfos.arrayInfosToBeUpdated.pop_front();
    return tmp;
}

//-----------------------------------------------------------------------------
// getCurActionStr()
// called by MAIN-thread in pMiniMax->csOsPrint critical-section
//-----------------------------------------------------------------------------
LPWSTR MiniMax::getCurActionStr()
{
    switch (curCalcActionId) {
    case MM_ACTION_INIT_RETRO_ANAL:
        return (LPWSTR)L"initiating retro-analysis";
    case MM_ACTION_PREPARE_COUNT_ARRAY:
        return (LPWSTR)L"preparing count arrays";
    case MM_ACTION_PERFORM_RETRO_ANAL:
        return (LPWSTR)L"performing retro analysis";
    case MM_ACTION_PERFORM_ALPHA_BETA:
        return (LPWSTR)L"performing alpha-beta-algorithmn";
    case MM_ACTION_TESTING_LAYER:
        return (LPWSTR)L"testing calculated layer";
    case MM_ACTION_SAVING_LAYER_TO_FILE:
        return (LPWSTR)L"saving layer to file";
    case MM_ACTION_CALC_LAYER_STATS:
        return (LPWSTR)L"making layer statistics";
    case MM_ACTION_NONE:
        return (LPWSTR)L"none";
    default:
        return (LPWSTR)L"undefined";
    }
}

//-----------------------------------------------------------------------------
// getCurCalculatedLayer()
// called by MAIN-thread in pMiniMax->csOsPrint critical-section
//-----------------------------------------------------------------------------
void MiniMax::getCurCalculatedLayer(vector<uint32_t> &layers)
{
    // when retro-analysis is used than two layers are calculated at the same
    // time
    if (shallRetroAnalysisBeUsed(curCalculatedLayer) &&
        layerStats[curCalculatedLayer].partnerLayer != curCalculatedLayer) {
        layers.resize(2);
        layers[0] = curCalculatedLayer;
        layers[1] = layerStats[curCalculatedLayer].partnerLayer;
    } else {
        layers.resize(1);
        layers[0] = curCalculatedLayer;
    }
}

//-----------------------------------------------------------------------------
// ArrayInfoContainer::addArray()
// Caution: layerNumber and type must be a unique pair!
//       called by single CALCULATION-thread
//-----------------------------------------------------------------------------
void MiniMax::ArrayInfoContainer::addArray(uint32_t layerNumber, uint32_t type,
                                           int64_t size, int64_t compressedSize)
{
    // create new info object and add to list
    EnterCriticalSection(&c->csOsPrint);

    ArrayInfo ais;
    ais.belongsToLayer = layerNumber;
    ais.compressedSizeInBytes = compressedSize;
    ais.sizeInBytes = size;
    ais.type = type;
    ais.updateCounter = 0;
    listArrays.push_back(ais);

    // notify change
    ArrayInfoChange aic;
    aic.arrayInfo = &listArrays.back();
    aic.itemIndex = (uint32_t)listArrays.size() - 1;
    arrayInfosToBeUpdated.push_back(aic);

    // save pointer of info in vector for direct access
    vectorArrays[layerNumber * ArrayInfo::arrayTypeCount + type] =
        (--listArrays.end());

    // update GUI
    if (c->userPrintFunc != nullptr) {
        c->userPrintFunc(c->pDataForUserPrintFunc);
    }

    LeaveCriticalSection(&c->csOsPrint);
}

//-----------------------------------------------------------------------------
// ArrayInfoContainer::removeArray()
// called by single CALCULATION-thread
//-----------------------------------------------------------------------------
void MiniMax::ArrayInfoContainer::removeArray(uint32_t layerNumber,
                                              uint32_t type, int64_t size,
                                              int64_t compressedSize)
{
    // find info object in list
    EnterCriticalSection(&c->csOsPrint);

    if (vectorArrays.size() > layerNumber * ArrayInfo::arrayTypeCount + type) {
        list<ArrayInfo>::iterator itr =
            vectorArrays[layerNumber * ArrayInfo::arrayTypeCount + type];
        if (itr != listArrays.end()) {
            // does sizes fit?
            if (itr->belongsToLayer != layerNumber || itr->type != type ||
                itr->sizeInBytes != size ||
                itr->compressedSizeInBytes != compressedSize) {
                c->falseOrStop();
            }

            // notify change
            ArrayInfoChange aic;
            aic.arrayInfo = nullptr;
            aic.itemIndex = (uint32_t)std::distance(listArrays.begin(), itr);
            arrayInfosToBeUpdated.push_back(aic);

            // delete tem from list
            listArrays.erase(itr);
        }
    }

    // update GUI
    if (c->userPrintFunc != nullptr) {
        c->userPrintFunc(c->pDataForUserPrintFunc);
    }

    LeaveCriticalSection(&c->csOsPrint);
}

//-----------------------------------------------------------------------------
// ArrayInfoContainer::updateArray()
// called by mutiple CALCULATION-thread
//-----------------------------------------------------------------------------
void MiniMax::ArrayInfoContainer::updateArray(uint32_t layerNumber,
                                              uint32_t type)
{
    // find info object in list
    list<ArrayInfo>::iterator itr =
        vectorArrays[layerNumber * ArrayInfo::arrayTypeCount + type];

    itr->updateCounter++;
    if (itr->updateCounter > ArrayInfo::updateCounterThreshold) {
        // notify change
        EnterCriticalSection(&c->csOsPrint);

        ArrayInfoChange aic;
        aic.arrayInfo = &(*itr);
        aic.itemIndex = (uint32_t)std::distance(listArrays.begin(), itr);
        arrayInfosToBeUpdated.push_back(aic);

        // update GUI
        if (c->userPrintFunc != nullptr) {
            c->userPrintFunc(c->pDataForUserPrintFunc);
        }
        itr->updateCounter = 0;

        LeaveCriticalSection(&c->csOsPrint);
    }
}

#endif // MADWEASEL_MUEHLE_PERFECT_AI
