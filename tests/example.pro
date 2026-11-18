TEMPLATE = app
TARGET = tst_example
QT += core
CONFIG += console c++11
CONFIG -= app_bundle
INCLUDEPATH += ../src
SOURCES += tst_example.cpp ../src/settings.cpp
HEADERS += ../src/settings.h
