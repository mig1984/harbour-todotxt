#ifndef ROWDIFF_H
#define ROWDIFF_H

#include <QList>
#include <QSet>
#include <QHash>

// Computes the list of model row operations that turn `oldRows` into `newRows`
// (both lists of unique keys). Used to update a QAbstractItemModel
// incrementally (insert/remove/move) instead of resetting it, so the view keeps
// its delegates (and their running undo bars). The number of moves is minimised
// with a longest increasing subsequence of the surviving rows, so moving a
// single row across the list costs one operation, not one per crossed row.
//
// `Key` just needs operator== and qHash() (e.g. int, or a task id + occurrence
// pair). The ops are ordered the way they must be applied: removals first (back
// to front), then placements from the end of the target order to the front.
namespace RowDiff {

template <typename Key>
struct OpT {
    enum Kind { Remove, Insert, Move };
    Kind kind;
    Key id;    // row key (Insert: the key to insert; Move/Remove: the affected key)
    int from;  // index the op applies to (Remove, Move)
    int to;    // target index (Insert, Move)
};

// Default key type, used by callers/tests that work with plain task ids.
typedef OpT<int> Op;

template <typename Key>
inline QList<OpT<Key> > compute(const QList<Key> &oldRows, const QList<Key> &newRows)
{
    typedef OpT<Key> OpX;
    QList<OpX> ops;

    QSet<Key> oldSet, newSet;
    for (int i = 0; i < oldRows.size(); ++i)
        oldSet.insert(oldRows[i]);
    for (int i = 0; i < newRows.size(); ++i)
        newSet.insert(newRows[i]);

    QList<Key> cur = oldRows;

    // 1) Removals, back to front so the indices stay valid.
    for (int i = cur.size() - 1; i >= 0; --i) {
        if (!newSet.contains(cur[i])) {
            OpX op; op.kind = OpX::Remove; op.id = cur[i]; op.from = i; op.to = -1;
            ops << op;
            cur.removeAt(i);
        }
    }

    // 2) Longest increasing subsequence of the survivors' old positions, taken
    //    in the new order: those rows are already in relative order.
    QHash<Key, int> rankInCur;
    for (int i = 0; i < cur.size(); ++i)
        rankInCur.insert(cur[i], i);

    QList<Key> keys;
    QList<int> seq;   // kept rows (new order) and their old positions
    for (int t = 0; t < newRows.size(); ++t) {
        const Key &k = newRows[t];
        if (oldSet.contains(k)) {
            keys << k;
            seq << rankInCur.value(k, -1);
        }
    }

    QSet<Key> stay;
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
            stay.insert(keys[i]);
    }

    // 3) Place rows from the end of the target order to the front. Each op puts
    //    the row just before its right neighbour (the anchor), which is already
    //    in place; rows in the LIS are left untouched.
    for (int t = newRows.size() - 1; t >= 0; --t) {
        const Key &desired = newRows[t];
        const bool hasAnchor = (t + 1 < newRows.size());

        if (!oldSet.contains(desired)) {
            int a = hasAnchor ? cur.indexOf(newRows[t + 1]) : -1;
            if (a < 0)
                a = cur.size();
            cur.insert(a, desired);
            OpX op; op.kind = OpX::Insert; op.id = desired; op.from = -1; op.to = a;
            ops << op;
        } else if (stay.contains(desired)) {
            continue;
        } else {
            const int k = cur.indexOf(desired);
            if (k < 0)
                continue;
            cur.removeAt(k);
            int a = hasAnchor ? cur.indexOf(newRows[t + 1]) : -1;
            if (a < 0)
                a = cur.size();
            cur.insert(a, desired);
            OpX op; op.kind = OpX::Move; op.id = desired; op.from = k; op.to = a;
            ops << op;
        }
    }

    return ops;
}

} // namespace RowDiff

#endif // ROWDIFF_H
