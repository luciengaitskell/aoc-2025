from days.lib.input import load_input


def count_routes_forward(node_from, node_to, node_children, visited=None):
    if visited is None:
        visited = set()

    if node_from == node_to:
        return 1

    if node_from in visited:
        return 0  # cycle, don't count
    visited.add(node_from)

    total_routes = 0
    for child in node_children.get(node_from, []):
        total_routes += count_routes_forward(child, node_to, node_children, visited)

    visited.remove(node_from)

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
