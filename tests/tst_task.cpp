#include <QtTest>
#include "../src/task.h"

class TstTask : public QObject
{
    Q_OBJECT
private slots:
    void roundTrip_data()
    {
        QTest::addColumn<QString>("line");
        QTest::newRow("simple") << "Test";
        QTest::newRow("completed") << "x 2012-11-11 2012-10-10 (A) test @list +tag due:2012-12-12 t:2013-01-01 rec:1d";
        QTest::newRow("double space") << "Test  with double  space";
        QTest::newRow("trailing space") << "Test with trailing space ";
        QTest::newRow("key value") << "Test key:value other:1 uuid:123e4567-e89b-12d3-a456-426655440000";
        QTest::newRow("prio only") << "(C)";
        QTest::newRow("order") << "Task #2048";
        QTest::newRow("phone") << "Call +31612345678 or 0800-1234";
        QTest::newRow("link mail") << "See https://example.com/a?b=c and mail me@example.org";
        QTest::newRow("empty") << "";
    }
    void roundTrip()
    {
        QFETCH(QString, line);
        QCOMPARE(Task(line).text(), line);
    }

    void dates()
    {
        QCOMPARE(Task("Test due:2014-10-10").dueDate(), QString("2014-10-10"));
        QCOMPARE(Task("Test due:2014-99-99").dueDate(), QString("2014-99-99"));
        QCOMPARE(Task("Test due:20141010").dueDate(), QString());
        QCOMPARE(Task("t:2013-12-12 Test").thresholdDate(), QString("2013-12-12"));
        QCOMPARE(Task("x 2012-11-11 2012-10-10 test").completionDate(), QString("2012-11-11"));
        QCOMPARE(Task("x 2012-11-11 2012-10-10 test").createDate(), QString("2012-10-10"));
        QCOMPARE(Task("x 2012-11-11 (A) 2013-11-11 test").createDate(), QString("2013-11-11"));
        QCOMPARE(Task("(A) 2014-01-01 test").createDate(), QString("2014-01-01"));
        QCOMPARE(Task("2014-01-01 test").createDate(), QString("2014-01-01"));
        Task t3("2014-01-01 test");
        t3.setCreateDate("2010-01-01");
        QCOMPARE(t3.text(), QString("2010-01-01 test"));
        Task t4("test", "2015-01-01");
        QCOMPARE(t4.text(), QString("2015-01-01 test"));
        Task t5("(B) test", "2015-01-01");
        QCOMPARE(t5.text(), QString("(B) 2015-01-01 test"));
        Task t6("x 2016-01-01 (B) test", "2015-01-01");
        QCOMPARE(t6.text(), QString("x 2016-01-01 (B) 2015-01-01 test"));
    }

    void dueSetter()
    {
        Task t("Test");
        t.setDueDate("2013-01-01");
        QCOMPARE(t.text(), QString("Test due:2013-01-01"));
        t.setDueDate("2013-01-01");
        QCOMPARE(t.text(), QString("Test due:2013-01-01"));
        t.setDueDate("");
        QCOMPARE(t.text(), QString("Test"));
        Task t2("x");
        t2.setThresholdDate("2000-01-01");
        QCOMPARE(t2.text(), QString("x t:2000-01-01"));
    }

    void priority()
    {
        Task t("Test");
        QCOMPARE(t.priority(), QChar('-'));
        t.setPriority('b');
        QCOMPARE(t.text(), QString("(B) Test"));
        t.setPriority('A');
        QCOMPARE(t.text(), QString("(A) Test"));
        t.setPriority('-');
        QCOMPARE(t.text(), QString("Test"));
        Task c("x 2020-01-01 (A) Done");
        QCOMPARE(c.priority(), QChar('A'));
        c.setPriority('-');
        QCOMPARE(c.text(), QString("x 2020-01-01 Done"));
    }

    void listsAndTags()
    {
        Task t("Milk @@errands +supermarket");
        QCOMPARE(t.lists(), QStringList() << "@errands");
        t.removeList("errands");
        QCOMPARE(t.text(), QString("Milk @@errands +supermarket"));
        t.removeList("@errands");
        QCOMPARE(t.text(), QString("Milk +supermarket"));
        Task t2("Test with trailing space ");
        t2.addTag("tag");
        QCOMPARE(t2.text(), QString("Test with trailing space +tag"));
        t2.addTag("tag");
        QCOMPARE(t2.text(), QString("Test with trailing space +tag"));
        t2.addList("home work");
        QCOMPARE(t2.text(), QString("Test with trailing space +tag @home @work"));
        QCOMPARE(Task("b +z +a +z").tags(), QStringList() << "a" << "z");
    }

    void completion()
    {
        Task t("(A) 2014-01-01 Test");
        Task n;
        QVERIFY(!t.markComplete("2015-02-02", &n));
        QCOMPARE(t.text(), QString("x 2015-02-02 (A) 2014-01-01 Test"));
        QVERIFY(t.isCompleted());
        QVERIFY(!t.markComplete("2015-03-03", &n));
        t.markIncomplete();
        QCOMPARE(t.text(), QString("(A) 2014-01-01 Test"));
    }

    void recurrence()
    {
        QCOMPARE(Task("Test").recurrence(), QString());
        QCOMPARE(Task("Test rec:1d").recurrence(), QString("1d"));
        struct Case { const char *in; const char *out; };
        const Case cases[] = {
            { "(B) 2014-07-05 Test t:2014-07-05 rec:2d", "(B) 2000-01-01 Test t:2000-01-03 rec:2d" },
            { "(B) 2014-07-05 Test t:2014-07-05 rec:+2d", "(B) 2000-01-01 Test t:2014-07-07 rec:+2d" },
            { "(B) 2014-07-05 Test due:2014-07-05 rec:2d", "(B) 2000-01-01 Test due:2000-01-03 rec:2d" },
            { "(B) 2014-07-05 Test due:2014-07-05 rec:+2d", "(B) 2000-01-01 Test due:2014-07-07 rec:+2d" },
            { "Test due:2014-07-05 rec:1y", "Test due:2001-01-01 rec:1y" },
            { "Test due:2014-01-31 rec:+1m", "Test due:2014-02-28 rec:+1m" },
            { "Test due:2014-07-05 rec:1w", "Test due:2000-01-08 rec:1w" },
            { "Test due:2000-01-01 rec:+1b", "Test due:2000-01-03 rec:+1b" }, // Sat -> Mon
            { "Test due:1999-12-31 rec:+3b", "Test due:2000-01-05 rec:+3b" }, // Fri -> Wed
            { "Test rec:1d #1024", "Test rec:1d #1024" },
        };
        for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
            Task t(cases[i].in);
            Task n;
            QVERIFY2(t.markComplete("2000-01-01", &n), cases[i].in);
            QCOMPARE(n.text(), QString(cases[i].out));
            QVERIFY(t.isCompleted());
        }
    }

    void defer()
    {
        Task t("Test due:2000-01-01");
        t.deferDueDate("1w", "");
        QCOMPARE(t.dueDate(), QString("2000-01-08"));
        t.deferDueDate("2000-05-05", "");
        QCOMPARE(t.dueDate(), QString("2000-05-05"));
        t.deferDueDate("", "");
        QCOMPARE(t.text(), QString("Test"));
        t.deferThresholdDate("1d", "2001-01-01");
        QCOMPARE(t.thresholdDate(), QString("2001-01-02"));
    }

    void future()
    {
        QVERIFY(Task("Test t:2015-01-02").inFuture("2015-01-01", false));
        QVERIFY(!Task("Test t:2015-01-01").inFuture("2015-01-01", false));
        QVERIFY(!Task("2015-01-02 Test").inFuture("2015-01-01", false));
        QVERIFY(Task("2015-01-02 Test").inFuture("2015-01-01", true));
        QVERIFY(!Task("Test t:2013-11-31").inFuture("2015-01-01", false));
    }

    void hasTaskText()
    {
        QVERIFY(!Task::hasTaskText(""));
        QVERIFY(!Task::hasTaskText("   "));
        QVERIFY(!Task::hasTaskText("(A)"));
        QVERIFY(!Task::hasTaskText("due:2020-01-01"));
        QVERIFY(!Task::hasTaskText("@home +work"));
        QVERIFY(!Task::hasTaskText("2020-01-01"));
        QVERIFY(!Task::hasTaskText("rec:1w"));
        QVERIFY(!Task::hasTaskText("h:1"));
        QVERIFY(!Task::hasTaskText("uuid:123e4567-e89b-12d3-a456-426655440000"));
        QVERIFY(!Task::hasTaskText("x 2020-01-01 @done +arch"));
        QVERIFY(Task::hasTaskText("Done task"));
        QVERIFY(Task::hasTaskText("(B) Buy milk +groceries"));
        QVERIFY(Task::hasTaskText("Call @home due:2020-01-01"));
        QVERIFY(Task::hasTaskText("Test h:1"));
        QVERIFY(Task::hasTaskText("key:value"));
    }

    void misc()
    {
        QCOMPARE(Task("1234 Task text with some 33-33 random numbers 12345678 +tag @list due:2020-01-01").alphaParts(),
                 QString("1234 Task text with some 33-33 random numbers 12345678"));
        QVERIFY(Task("Test h:1").isHidden());
        QVERIFY(!Task("Test h:0").isHidden());
        Task o("Task #2048");
        QCOMPARE(o.manualOrder(), 2048);
        o.setManualOrder(1024);
        QCOMPARE(o.text(), QString("Task #1024"));
        o.clearManualOrder();
        QCOMPARE(o.text(), QString("Task"));
        o.setManualOrder(5);
        QCOMPARE(o.text(), QString("Task #5"));
        QCOMPARE(Task("No order").manualOrder(), -1);
        QCOMPARE(Task("x 2020-01-01 2019-01-01 (A) test @l +t due:2020-02-02 rec:1d uuid:123e4567-e89b-12d3-a456-426655440000 #3").showParts(false, false, true),
                 QString("test @l +t"));
        QCOMPARE(Task("test @l +t due:2020-02-02").showParts(true, true, false), QString("test due:2020-02-02"));
        QCOMPARE(Task("See https://example.com").links(), QStringList() << "https://example.com");
        QCOMPARE(Task("Mail a@b.cz now").mails(), QStringList() << "a@b.cz");
    }
};

QTEST_APPLESS_MAIN(TstTask)
#include "tst_task.moc"
