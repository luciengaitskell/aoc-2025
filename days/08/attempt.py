import numpy as np

from days.lib.input import load_input


def top_k_closest_pairs_l2(X, k):
    n = X.shape[0]
    X = X.astype(np.int64)  # allow negative diffs

    diff = X[:, None] - X[None, :]  # (n,n,3) int64
    dist2 = np.sum(diff**2, axis=-1).astype(np.uint64)  # uint64

    iu, ju = np.triu_indices(n, k=1)  # relevant indices (excludes self-pairs)
    flat = dist2[iu, ju]

    k = min(k, len(flat))
    # first, get the indices of the k smallest
    idx = np.argpartition(flat, k - 1)[:k]
    # then, actually sort these k
    order = np.argsort(flat[idx])

    return (np.column_stack((iu[idx[order]], ju[idx[order]])), flat[idx[order]])


def top_m_cc_sizes(pairs, m):
    n = np.max(pairs) + 1
    parent = np.arange(n, dtype=np.intp)
    rank = np.zeros(n, dtype=np.intp)  # union-by-rank

    def find(x):
        # first, find the root of x
        root = x
        while parent[root] != root:
            root = parent[root]

        # compress path from x to root
        cur = x
        while cur != root:
            nxt = parent[cur]
            parent[cur] = root
            cur = nxt
        return root

    for a, b in pairs:
        pa, pb = find(a), find(b)
        if pa == pb:
            continue
        if rank[pa] < rank[pb]:
            parent[pa] = pb
        elif rank[pa] > rank[pb]:
            parent[pb] = pa
        else:
            parent[pb] = pa
            rank[pa] += 1

    root_ids = np.empty(n, dtype=np.intp)
    for i in range(n):
        root_ids[i] = find(i)
    sizes = np.bincount(root_ids)

    top_m = np.sort(sizes)[::-1][:m]  # top m

    print("Top connected component roots and sizes:")
    for root_id in np.argsort(sizes)[::-1][:m]:
        print(f"  Root {root_id}: size {sizes[root_id]}")

        points = np.where(root_ids == root_id)[0]
        for i, point in enumerate(points):
            print(f"    Point {point} (idx {i})")

    return top_m

def solve_coords(coords, *, k=1000, m=3):
    pairs, distances = top_k_closest_pairs_l2(coords, k)
    print("top k pairs of node indices:", pairs)
    print("Top k closest pair distances:", distances)
    top_sizes = top_m_cc_sizes(pairs, m)
    return top_sizes, int(np.prod(top_sizes)), pairs, distances

def load_coords():
    coords = []
    for line in load_input(__file__):
        new_coords = line.split(",")
        coords.append([int(c) for c in new_coords])
    return np.array(coords, dtype=np.uint32)


def solve():
    coords = load_coords()
    k = 1000
    m = 3
    top_sizes, product, _, _ = solve_coords(coords, k=k, m=m)
    print(f"Top {m} connected component sizes:", top_sizes)
    print("Product of top sizes:", product)


if __name__ == "__main__":
    solve()
