from days.lib.input import load_input


def count_routes_forward(
    node_from,
    node_to,
    node_children,
    needs: frozenset | None = None,
    *,
    prev=None,
):
    assert isinstance(needs, frozenset) or needs is None
    if prev is None:
        # cache of previously computed results
        prev = {}

    needs = needs - {node_from} if needs is not None else None

    if node_from == node_to:
        if needs is not None and needs:  # still need some nodes
            return 0
        return 1

    key = (node_from, needs)
    if key in prev:
        # use previously computed result
        #   (has the side-effect of avoiding cycles)
        return prev[key]

    prev[key] = 0  # causes cycles to return 0

    total_routes = 0
    for child in node_children.get(node_from, []):
        total_routes += count_routes_forward(
            child, node_to, node_children, needs=needs, prev=prev
        )
    prev[key] = total_routes

    return total_routes

def load():
    node_children = {}
    for line in load_input(__file__):
        node, connected_to = line.split(": ")
        children = connected_to.split(" ")
        node_children[node] = set(child.strip() for child in children)
    return node_children


def solve():
    node_children = load()
    # print(node_children)
    total_routes = count_routes_forward("you", "out", node_children)
    print(total_routes)

def solve_part2():
    node_children = load()
    # print(node_children)
    total_routes = count_routes_forward(
        "svr", "out", node_children, needs=frozenset({"dac", "fft"})
    )
    print(total_routes)

if __name__ == "__main__":
    solve()
    solve_part2()
