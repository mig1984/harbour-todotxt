#ifndef FILTERSTORE_H
#define FILTERSTORE_H

#include <QObject>
#include <QStringList>
#include <QMap>

class Settings;

// Named saved queries (JSON), persisted in Settings.
class FilterStore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList names READ names NOTIFY changed)
    Q_PROPERTY(bool manualOrderNeeded READ manualOrderNeeded NOTIFY changed)

public:
    explicit FilterStore(Settings *settings, QObject *parent = 0);

    QStringList names() const;
    bool manualOrderNeeded() const;   // any saved filter sorts by "manual"

    Q_INVOKABLE QString get(const QString &name) const;
    Q_INVOKABLE void save(const QString &name, const QString &json);
    Q_INVOKABLE void remove(const QString &name);
    Q_INVOKABLE void rename(const QString &oldName, const QString &newName);
    Q_INVOKABLE bool contains(const QString &name) const { return m_filters.contains(name); }

signals:
    void changed();

private:
    void load();
    void store();

    Settings *m_settings;
    QMap<QString, QString> m_filters;
};

#endif // FILTERSTORE_H
