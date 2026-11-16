#include "filterstore.h"
#include "settings.h"
#include "query.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

FilterStore::FilterStore(Settings *settings, QObject *parent)
    : QObject(parent), m_settings(settings)
{
    load();
}

void FilterStore::load()
{
    m_filters.clear();
    QJsonObject o = QJsonDocument::fromJson(m_settings->savedFiltersJson().toUtf8()).object();
    for (QJsonObject::const_iterator it = o.begin(); it != o.end(); ++it)
        m_filters[it.key()] = QString::fromUtf8(QJsonDocument(it.value().toObject()).toJson(QJsonDocument::Compact));
}

void FilterStore::store()
{
    QJsonObject o;
    for (QMap<QString, QString>::const_iterator it = m_filters.begin(); it != m_filters.end(); ++it)
        o[it.key()] = QJsonDocument::fromJson(it.value().toUtf8()).object();
    m_settings->setSavedFiltersJson(QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact)));
    emit changed();
}

QStringList FilterStore::names() const
{
    return m_filters.keys();
}

bool FilterStore::manualOrderNeeded() const
{
    foreach (const QString &json, m_filters) {
        QJsonObject o = QJsonDocument::fromJson(json.toUtf8()).object();
        Query q;
        q.fromJson(json);
        if (q.manualSort())
            return true;
    }
    return false;
}

QString FilterStore::get(const QString &name) const
{
    return m_filters.value(name);
}

void FilterStore::save(const QString &name, const QString &json)
{
    if (name.trimmed().isEmpty())
        return;
    m_filters[name.trimmed()] = json;
    store();
}

void FilterStore::remove(const QString &name)
{
    if (m_filters.remove(name))
        store();
}

void FilterStore::rename(const QString &oldName, const QString &newName)
{
    if (!m_filters.contains(oldName) || newName.trimmed().isEmpty() || oldName == newName)
        return;
    m_filters[newName.trimmed()] = m_filters.take(oldName);
    store();
}
