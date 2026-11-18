#ifndef ROWDIFF_H
#define ROWDIFF_H

#include <QList>
#include <QSet>
#include <QHash>

// Computes the list of model row operations that turn `oldRows` into `newRows`
// (both lists of unique task ids). Used to update a QAbstractItemModel
// incrementally (insert/remove/move) instead of resetting it, so the view keeps
// its delegates (and their running undo bars). The number of moves is minimised
// with a longest increasing subsequence of the surviving rows, so moving a
// single row across the list costs one operation, not one per crossed row.
//
// The ops are ordered the way they must be applied: removals first (back to
// front), then placements from the end of the target order to the front.
namespace RowDiff {

struct Op {
    enum Kind { Remove, Insert, Move };
    Kind kind;
    int id;    // task id (Insert: the id to insert; Move/Remove: the affected id)
    int from;  // index the op applies to (Remove, Move)
    int to;    // target index (Insert, Move)
};

inline QList<Op> compute(const QList<int> &oldRows, const QList<int> &newRows)
{
    QList<Op> ops;

    QSet<int> oldSet, newSet;
    for (int i = 0; i < oldRows.size(); ++i)
        oldSet.insert(oldRows[i]);
    for (int i = 0; i < newRows.size(); ++i)
        newSet.insert(newRows[i]);

    QList<int> cur = oldRows;

    // 1) Removals, back to front so the indices stay valid.
    for (int i = cur.size() - 1; i >= 0; --i) {
        if (!newSet.contains(cur[i])) {
            Op op; op.kind = Op::Remove; op.id = cur[i]; op.from = i; op.to = -1;
            ops << op;
            cur.removeAt(i);
        }
    }

    // 2) Longest increasing subsequence of the survivors' old positions, taken
    //    in the new order: those rows are already in relative order.
    QHash<int, int> rankInCur;
    for (int i = 0; i < cur.size(); ++i)
        rankInCur.insert(cur[i], i);

    QList<int> ids, seq;   // kept rows in new order and their old positions
    for (int t = 0; t < newRows.size(); ++t) {
        const int id = newRows[t];
        if (oldSet.contains(id)) {
            ids << id;
            seq << rankInCur.value(id, -1);
        }
    }

    QSet<int> stay;
    const int m = seq.size();
    if (m > 0) {
        QList<int> dp, prev;
        for (int i = 0; i < m; ++i) {
            dp << 1;
            prev << -1;
        }
        int best = 0, bestIdx = 0;
        for (int i = 0; i < m; ++i) {
            for (int j = 0; j < i; ++j) {
                if (seq[j] < seq[i] && dp[j] + 1 > dp[i]) {
                    dp[i] = dp[j] + 1;
                    prev[i] = j;
                }
            }
            if (dp[i] > best) {
                best = dp[i];
                bestIdx = i;
            }
        }
        for (int i = bestIdx; i >= 0; i = prev[i])
            stay.insert(ids[i]);
    }

    // 3) Place rows from the end of the target order to the front. Each op
    //    puts the row just before its right neighbour (the anchor), which is
    //    already in place; rows in the LIS are left untouched.
    for (int t = newRows.size() - 1; t >= 0; --t) {
        const int desired = newRows[t];
        const int anchorId = (t + 1 < newRows.size()) ? newRows[t + 1] : -1;

        if (!oldSet.contains(desired)) {
            int a = (anchorId >= 0) ? cur.indexOf(anchorId) : -1;
            if (a < 0)
                a = cur.size();
            cur.insert(a, desired);
            Op op; op.kind = Op::Insert; op.id = desired; op.from = -1; op.to = a;
            ops << op;
        } else if (stay.contains(desired)) {
            continue;
        } else {
            const int k = cur.indexOf(desired);
            if (k < 0)
                continue;
            cur.removeAt(k);
            int a = (anchorId >= 0) ? cur.indexOf(anchorId) : -1;
            if (a < 0)
                a = cur.size();
            cur.insert(a, desired);
            Op op; op.kind = Op::Move; op.id = desired; op.from = k; op.to = a;
            ops << op;
        }
    }

    return ops;
}

} // namespace RowDiff

#endif // ROWDIFF_H
