TARGET = harbour-todotxt

CONFIG += sailfishapp c++11

SOURCES += src/harbour-todotxt.cpp \
    src/task.cpp \
    src/settings.cpp \
    src/query.cpp \
    src/todostore.cpp \
    src/taskmodel.cpp \
    src/filterstore.cpp \
    src/swipedetector.cpp

HEADERS += src/task.h \
    src/settings.h \
    src/query.h \
    src/todostore.h \
    src/taskmodel.h \
    src/filterstore.h \
    src/swipedetector.h

DISTFILES += qml/harbour-todotxt.qml \
    qml/cover/CoverPage.qml \
    qml/pages/*.qml \
    qml/components/*.qml \
    rpm/harbour-todotxt.spec \
    harbour-todotxt.desktop

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

CONFIG += sailfishapp_i18n

TRANSLATIONS += translations/harbour-todotxt-cs.ts \
    translations/harbour-todotxt-de.ts \
    translations/harbour-todotxt-fr.ts \
    translations/harbour-todotxt-es.ts \
    translations/harbour-todotxt-it.ts \
    translations/harbour-todotxt-ru.ts \
    translations/harbour-todotxt-pl.ts \
    translations/harbour-todotxt-nl.ts \
    translations/harbour-todotxt-sv.ts \
    translations/harbour-todotxt-fi.ts \
    translations/harbour-todotxt-zh_CN.ts
