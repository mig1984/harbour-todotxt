#ifndef QUERY_H
#define QUERY_H

#include <QObject>
#include <QStringList>
#include "task.h"

// Port of Simpletask's Query: filter + sort definition.

#define QPROP(type, name, Name) \
    Q_PROPERTY(type name READ name WRITE set##Name NOTIFY changed) \
    public: \
    type name() const { return m_##name; } \
    void set##Name(const type &v) { if (m_##name == v) return; m_##name = v; emit changed(); } \
    private: \
    type m_##name;

class Query : public QObject
{
    Q_OBJECT
    QPROP(QStringList, contexts, Contexts)
    QPROP(QStringList, projects, Projects)
    QPROP(QStringList, priorities, Priorities)
    QPROP(bool, contextsNot, ContextsNot)
    QPROP(bool, projectsNot, ProjectsNot)
    QPROP(bool, prioritiesNot, PrioritiesNot)
    QPROP(bool, hideCompleted, HideCompleted)
    QPROP(bool, hideFuture, HideFuture)
    QPROP(bool, hideHidden, HideHidden)
    QPROP(bool, hideLists, HideLists)
    QPROP(bool, hideTags, HideTags)
    QPROP(bool, createIsThreshold, CreateIsThreshold)
    QPROP(QString, search, Search)
    QPROP(QStringList, sorts, Sorts)   // "+!key" / "-!key"
    QPROP(QString, name, Name)         // name of the saved filter it came from

    Q_PROPERTY(bool hasFilter READ hasFilter NOTIFY changed)
    Q_PROPERTY(QString summary READ summary NOTIFY changed)
    Q_PROPERTY(QString proposedName READ proposedName NOTIFY changed)
    Q_PROPERTY(QString prefill READ prefill NOTIFY changed)
    Q_PROPERTY(bool manualSort READ manualSort NOTIFY changed)
    Q_PROPERTY(QStringList effectiveSorts READ effectiveSorts NOTIFY changed)
    Q_PROPERTY(QString sectionKey READ sectionKey NOTIFY changed)

public:
    explicit Query(QObject *parent = 0);

    static QStringList allSortKeys();
    static QStringList defaultSorts();
    Q_INVOKABLE static QString sortKeyLabel(const QString &key);
    Q_INVOKABLE QStringList allKeys() const { return allSortKeys(); }

    bool hasFilter() const;
    QString summary() const;
    QString proposedName() const;
    QString prefill() const;
    bool manualSort() const;
    QStringList effectiveSorts() const;
    QString sectionKey() const;        // sort key used for section headers ("" if none)

    Q_INVOKABLE QString toJson() const;
    Q_INVOKABLE void fromJson(const QString &json);
    Q_INVOKABLE void clear();          // clears filter parts, keeps sorts/options
    Q_INVOKABLE void toggleContext(const QString &c, bool on);
    Q_INVOKABLE void toggleProject(const QString &p, bool on);
    Q_INVOKABLE void togglePriority(const QString &p, bool on);
    Q_INVOKABLE void clearContexts();  // selection + invert of the section
    Q_INVOKABLE void clearProjects();
    Q_INVOKABLE void clearPriorities();
    Q_INVOKABLE void setSortDirection(int index, bool reversed);
    Q_INVOKABLE void moveSort(int from, int to);

    // Filtering
    bool matches(const Task &t, const QString &today) const;

    // Sorting: compares using keys [0, keyCount) of effectiveSorts().
    // keyCount < 0 means all keys.
    int compare(const Task &a, const Task &b, int keyCount = -1) const;
    int manualSortIndex() const;       // index of "manual" in effectiveSorts, -1 if absent
    QString section(const Task &t, const QString &empty) const;

    void setCaseSensitive(bool cs) { m_caseSensitive = cs; }

signals:
    void changed();

private:
    QString sortValue(const Task &t, const QString &key) const;
    bool m_caseSensitive;
};

#endif // QUERY_H
