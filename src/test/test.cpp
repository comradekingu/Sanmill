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

#include "config.h"

#include <QBuffer>
#include <QUuid>
#include <QDataStream>
#include <QString>
#include <QThread>
#include <QtWidgets>
#include <QtCore>
#include <random>

#include "test.h"

Test::Test(QWidget *parent, QString k)
    : QDialog(parent)
    , keyCombo(new QComboBox)
    , startButton(new QPushButton(tr("Start")))
    , stopButton(new QPushButton(tr("Stop")))
{
    setWindowFlags(windowFlags() & ~Qt::WindowContextHelpButtonHint);

    this->key = k;

    readMemoryTimer = new QTimer(this);
    connect(readMemoryTimer, SIGNAL(timeout()), this, SLOT(onTimeOut()));
    readMemoryTimer->stop();

    keyCombo->setEditable(true);
    keyCombo->addItem(QString("MillGame-Key-0"));
    keyCombo->addItem(QString("MillGame-Key-1"));
    auto keyLabel = new QLabel(tr("&Key:"));
    keyLabel->setBuddy(keyCombo);

    startButton->setDefault(true);
    startButton->setEnabled(true);
    stopButton->setEnabled(false);

    auto closeButton = new QPushButton(tr("Close"));
    auto buttonBox = new QDialogButtonBox;
    buttonBox->addButton(startButton, QDialogButtonBox::ActionRole);
    buttonBox->addButton(stopButton, QDialogButtonBox::ActionRole);
    buttonBox->addButton(closeButton, QDialogButtonBox::RejectRole);

    connect(startButton, &QAbstractButton::clicked, this, &Test::startAction);
    connect(stopButton, &QAbstractButton::clicked, this, &Test::stopAction);
    connect(closeButton, &QAbstractButton::clicked, this, &QWidget::close);

    QGridLayout *mainLayout = nullptr;
    if (QGuiApplication::styleHints()->showIsFullScreen() || QGuiApplication::styleHints()->showIsMaximized()) {
        auto outerVerticalLayout = new QVBoxLayout(this);
        outerVerticalLayout->addItem(new QSpacerItem(0, 0, QSizePolicy::Ignored, QSizePolicy::MinimumExpanding));
        auto outerHorizontalLayout = new QHBoxLayout;
        outerHorizontalLayout->addItem(new QSpacerItem(0, 0, QSizePolicy::MinimumExpanding, QSizePolicy::Ignored));
        auto groupBox = new QGroupBox(QGuiApplication::applicationDisplayName());
        mainLayout = new QGridLayout(groupBox);
        outerHorizontalLayout->addWidget(groupBox);
        outerHorizontalLayout->addItem(new QSpacerItem(0, 0, QSizePolicy::MinimumExpanding, QSizePolicy::Ignored));
        outerVerticalLayout->addLayout(outerHorizontalLayout);
        outerVerticalLayout->addItem(new QSpacerItem(0, 0, QSizePolicy::Ignored, QSizePolicy::MinimumExpanding));
    } else {
        mainLayout = new QGridLayout(this);
    }

    mainLayout->addWidget(keyLabel, 0, 0);
    mainLayout->addWidget(keyCombo, 0, 1);
    mainLayout->addWidget(buttonBox, 3, 0, 1, 2);

    setWindowTitle(QGuiApplication::applicationDisplayName());
}

Test::~Test()
{
    detach();
    readMemoryTimer->stop();
}

void Test::stop()
{
    detach();
    isTestMode = false;
    readMemoryTimer->stop();
}

void Test::attach()
{
    sharedMemory.setKey(key);

    if (sharedMemory.attach()) {
        loggerDebug("Attached shared memory segment.\n");
    } else {
        if (sharedMemory.create(SHARED_MEMORY_SIZE)) {
            loggerDebug("Created shared memory segment.\n");
        } else {
            loggerDebug("Unable to create shared memory segment.\n");
        }
    }

    to = (char *)sharedMemory.data();

    uuid = createUuidString();
    uuidSize = uuid.size();

    assert(uuidSize == 38);
}

void Test::detach()
{
    if (sharedMemory.isAttached()) {
        if (sharedMemory.detach()) {
            loggerDebug("Detached shared memory segment.\n");            
        }
    }
}

void Test::writeToMemory(const QString &cmdline)
{
    if (!isTestMode) {
        return;
    }

    if (cmdline == readStr) {
        return;
    }

    char from[BUFSIZ] = { 0 };
#ifdef _WIN32
    strcpy_s(from, cmdline.toStdString().c_str());
#else
    strcpy(from, cmdline.toStdString().c_str());
#endif

    while (true) {
        sharedMemory.lock();

        if (to[0] != 0) {
            sharedMemory.unlock();
            QThread::msleep(100);
            continue;
        }

        memset(to, 0, SHARED_MEMORY_SIZE);
        memcpy(to, uuid.toStdString().c_str(), uuidSize);
        memcpy(to + uuidSize, from, strlen(from));
        sharedMemory.unlock();

        break;
    }
}

void Test::readFromMemory()
{
    if (!isTestMode) {
        return;
    }

    sharedMemory.lock();
    QString str = to;
    sharedMemory.unlock();

    if (str.size() == 0) {
        return;
    }

    if (!(str.mid(0, uuidSize) == uuid)) {
        str = str.mid(uuidSize);
        if (str.size()) {
            sharedMemory.lock();
            memset(to, 0, SHARED_MEMORY_SIZE);
            sharedMemory.unlock();
            readStr = str;
            emit command(str);
        }
    }
}

QString Test::createUuidString()
{
    return QUuid::createUuid().toString();
}

void Test::startAction()
{
    key = keyCombo->currentText();

    detach();
    attach();

    isTestMode = true;
    readMemoryTimer->start(100);

    startButton->setEnabled(false);
    stopButton->setEnabled(true);
}

void Test::stopAction()
{
    stop();

    startButton->setEnabled(true);
    stopButton->setEnabled(false);
}

void Test::onTimeOut()
{
    readFromMemory();
}