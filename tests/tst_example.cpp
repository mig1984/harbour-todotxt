// Plain QtCore test for the first-run example list generator (no testlib, like
// tst_rowdiff). Only the pure line generators are exercised, no files touched.

#include "settings.h"

#include <QDate>
#include <QStringList>
#include <cstdio>

static int failures = 0;

static void check(bool ok, const char *what)
{
    if (!ok) {
        std::printf("FAIL: %s\n", what);
        ++failures;
    }
}

int main()
{
    const QDate today(2026, 11, 18);
    const QStringList todo = Settings::exampleTodoLines(today);
    const QStringList done = Settings::exampleDoneLines(today);

    auto has = [&todo](const QString &needle) {
        foreach (const QString &line, todo)
            if (line.contains(needle))
                return true;
        return false;
    };

    check(has("due:2026-11-15"), "overdue task (due today-3)");
    check(has("due:2026-11-18"), "task due today");
    check(has("due:2026-11-19"), "task due tomorrow");
    check(has("due:2026-11-20"), "task due the day after tomorrow");
    check(has("t:2026-11-20"), "threshold the day after tomorrow");
    check(has("due:2026-11-28"), "task due in ten days");
    check(has("due:2026-11-25"), "task due in a week");
    check(has("rec:1w"), "recurring task");
    check(has("x 2026-11-16"), "completed task");
    check(todo.contains("Read the todo.txt documentation"), "plain task without dates");
    check(!done.isEmpty() && done.first().startsWith("x 2026-11-13"), "archived example in done.txt");
    check(todo.size() == 9, "todo.txt has nine tasks");

    if (failures == 0) {
        std::printf("All example list checks passed.\n");
        return 0;
    }
    std::printf("%d check(s) failed.\n", failures);
    return 1;
}
