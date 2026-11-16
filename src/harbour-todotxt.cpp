#include <QtQuick>
#include <sailfishapp.h>

#include "settings.h"
#include "todostore.h"
#include "query.h"
#include "taskmodel.h"
#include "filterstore.h"

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    app->setOrganizationName("cz.mig");
    app->setApplicationName("harbour-todotxt");

    Settings settings;
    TodoStore store(&settings);
    Query query;
    FilterStore filters(&settings);
    TaskModel model(&store, &query, &settings);

    // Restore the main query and keep it persisted.
    if (!settings.queryJson().isEmpty())
        query.fromJson(settings.queryJson());
    QObject::connect(&query, &Query::changed, [&]() {
        settings.setQueryJson(query.toJson());
        store.setManualOrderNeeded(query.manualSort() || filters.manualOrderNeeded());
    });
    QObject::connect(&filters, &FilterStore::changed, [&]() {
        store.setManualOrderNeeded(query.manualSort() || filters.manualOrderNeeded());
    });
    store.setManualOrderNeeded(query.manualSort() || filters.manualOrderNeeded());

    qmlRegisterType<Query>("harbour.todotxt", 1, 0, "Query");

    QScopedPointer<QQuickView> view(SailfishApp::createView());
    view->rootContext()->setContextProperty("settings", &settings);
    view->rootContext()->setContextProperty("store", &store);
    view->rootContext()->setContextProperty("query", &query);
    view->rootContext()->setContextProperty("taskModel", &model);
    view->rootContext()->setContextProperty("filterStore", &filters);
    view->setSource(SailfishApp::pathToMainQml());
    view->show();

    store.reload();
    return app->exec();
}
