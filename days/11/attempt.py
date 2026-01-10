from days.lib.input import load_input


def count_routes_forward(node_from, node_to, node_children, *, prev=None):
    if prev is None:
        # cache of previously computed results
        prev = {}

    if node_from == node_to:
        return 1

    if node_from in prev:
        # use previously computed result
        #   (has the side-effect of avoiding cycles)
        return prev[node_from]

    prev[node_from] = 0  # causes cycles to return 0

    total_routes = 0
    for child in node_children.get(node_from, []):
        total_routes += count_routes_forward(child, node_to, node_children, prev=prev)
    prev[node_from] = total_routes

    return total_routes


def solve():
    node_children = {}
    for line in load_input(__file__):
        node, connected_to = line.split(": ")
        children = connected_to.split(" ")
        node_children[node] = set(child.strip() for child in children)
    # print(node_children)
    total_routes = count_routes_forward("you", "out", node_children)
    print(total_routes)


if __name__ == "__main__":
    solve()
