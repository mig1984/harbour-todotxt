TEMPLATE = app
TARGET = tst_todotxt
QT += testlib core
CONFIG += testcase console c++11
CONFIG -= app_bundle
INCLUDEPATH += ../src
SOURCES += tst_task.cpp ../src/task.cpp
HEADERS += ../src/task.h
