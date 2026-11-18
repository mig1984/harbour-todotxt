// Plain QtCore test for src/rowdiff.h (QtTest/qtestlib is not available in the
// SDK targets). Exits non-zero on failure.
#include <QList>
#include <QDebug>
#include <cstdio>
#include "../src/rowdiff.h"

static int failures = 0;

static QList<int> applyOps(QList<int> rows, const QList<RowDiff::Op> &ops)
{
    foreach (const RowDiff::Op &op, ops) {
        if (op.kind == RowDiff::Op::Remove)
            rows.removeAt(op.from);
        else if (op.kind == RowDiff::Op::Insert)
            rows.insert(op.to, op.id);
        else
            rows.move(op.from, op.to);
    }
    return rows;
}

static int moveCount(const QList<RowDiff::Op> &ops)
{
    int n = 0;
    foreach (const RowDiff::Op &op, ops)
        if (op.kind == RowDiff::Op::Move)
            ++n;
    return n;
}

static void expect(bool ok, const char *what)
{
    if (ok)
        return;
    ++failures;
    std::fprintf(stderr, "FAIL: %s\n", what);
}

static void transforms()
{
    QList<QList<int> > olds, news;
    olds << (QList<int>() << 1 << 2 << 3);
    news << (QList<int>() << 1 << 2 << 3);
    olds << (QList<int>() << 1 << 2 << 3);
    news << (QList<int>() << 2 << 3 << 1);
    olds << (QList<int>() << 1 << 2 << 3);
    news << (QList<int>() << 3 << 1 << 2);
    olds << (QList<int>() << 1 << 2 << 3);
    news << (QList<int>() << 1 << 2 << 3 << 4);
    olds << (QList<int>() << 1 << 2 << 3);
    news << (QList<int>() << 0 << 1 << 2 << 3);
    olds << (QList<int>() << 1 << 2 << 3);
    news << (QList<int>() << 1 << 9 << 2 << 3);
    olds << (QList<int>() << 1 << 2 << 3);
    news << (QList<int>() << 2 << 3);
    olds << (QList<int>() << 1 << 2 << 3);
    news << (QList<int>() << 1 << 3);
    olds << (QList<int>() << 1 << 2 << 3);
    news << QList<int>();
    olds << QList<int>();
    news << (QList<int>() << 1 << 2 << 3);
    olds << (QList<int>() << 1 << 2 << 3 << 4);
    news << (QList<int>() << 4 << 3 << 2 << 1);
    olds << (QList<int>() << 1 << 2 << 3 << 4 << 5);
    news << (QList<int>() << 2 << 4 << 1 << 5 << 3);
    olds << (QList<int>() << 5 << 1 << 4 << 2 << 8);
    news << (QList<int>() << 1 << 2 << 3 << 4 << 5 << 6 << 7 << 8 << 9);

    for (int i = 0; i < olds.size(); ++i) {
        QList<RowDiff::Op> ops = RowDiff::compute(olds[i], news[i]);
        QList<int> got = applyOps(olds[i], ops);
        if (got != news[i])
            std::fprintf(stderr, "case %d: ops=%d got != want\n", i, ops.size());
        expect(got == news[i], "transform result");
    }
}

static void singleMoveToEndIsOneOp()
{
    QList<int> oldRows, newRows;
    for (int i = 0; i < 50; ++i) { oldRows << i; newRows << i; }
    newRows.move(0, 49);
    QList<RowDiff::Op> ops = RowDiff::compute(oldRows, newRows);
    expect(moveCount(ops) == 1, "move to end: one move");
    expect(ops.size() == 1, "move to end: one op");
    expect(applyOps(oldRows, ops) == newRows, "move to end: result");
}

static void singleMoveAcrossIsOneOp()
{
    QList<int> oldRows, newRows;
    for (int i = 0; i < 100; ++i) { oldRows << i; newRows << i; }
    newRows.move(20, 80);
    QList<RowDiff::Op> ops = RowDiff::compute(oldRows, newRows);
    expect(moveCount(ops) == 1, "move across: one move");
    expect(applyOps(oldRows, ops) == newRows, "move across: result");
}

static void longListCompleteIsCheap()
{
    // Completing a task near the top of a long list moves it to the end; it
    // must not degrade into one move per crossed row.
    QList<int> oldRows, newRows;
    for (int i = 0; i < 200; ++i) { oldRows << i; newRows << i; }
    int id = newRows.takeAt(3);
    newRows.append(id);
    QList<RowDiff::Op> ops = RowDiff::compute(oldRows, newRows);
    expect(ops.size() <= 2, "long list complete: few ops");
    expect(applyOps(oldRows, ops) == newRows, "long list complete: result");
}

static void fuzz()
{
    quint32 seed = 12345u;
    struct Rnd {
        quint32 *s;
        int next(int mod) { *s = (*s) * 1103515245u + 12345u; return int(((*s) >> 16) % quint32(mod)); }
    } rnd = { &seed };

    for (int iter = 0; iter < 20000; ++iter) {
        const int universe = 1 + rnd.next(12);
        QList<int> all;
        for (int i = 0; i < universe; ++i)
            all << i;
        for (int i = all.size() - 1; i > 0; --i)
            all.swap(i, rnd.next(i + 1));

        QList<int> oldRows, newRows;
        const int oldLen = rnd.next(universe + 1);
        for (int i = 0; i < oldLen; ++i)
            oldRows << all[i];
        for (int i = all.size() - 1; i > 0; --i)
            all.swap(i, rnd.next(i + 1));
        const int newLen = rnd.next(universe + 1);
        for (int i = 0; i < newLen; ++i)
            newRows << all[i];

        QList<RowDiff::Op> ops = RowDiff::compute(oldRows, newRows);
        QList<int> got = applyOps(oldRows, ops);
        if (got != newRows) {
            std::fprintf(stderr, "fuzz iter %d old/new mismatch\n", iter);
            ++failures;
            break;
        }
    }
}

int main()
{
    transforms();
    singleMoveToEndIsOneOp();
    singleMoveAcrossIsOneOp();
    longListCompleteIsCheap();
    fuzz();

    if (failures) {
        std::fprintf(stderr, "%d rowdiff test failure(s)\n", failures);
        return 1;
    }
    std::printf("all rowdiff tests passed\n");
    return 0;
}
