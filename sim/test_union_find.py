import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, ReadOnly
from sim.lib import build_and_run_sim, reset


MAX_NODE_COUNT = 8
STATE_IDLE = 0


def pack_metadata(dut, u, v):
    width = len(dut.in_metadata)
    half = width // 2
    return (int(u) << half) | int(v)


def unpack_node(dut, node_idx):
    raw = int(dut.nodes[node_idx].value)
    width = len(dut.nodes[node_idx])
    payload_width = width - 1
    is_root = (raw >> payload_width) & 1
    payload = raw & ((1 << payload_width) - 1)
    return is_root, payload


@cocotb.test
async def test_a(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut.clk, dut.rst, 2)

    edges = [(0, 1), (0, 2), (2, 3), (4, 5), (4, 6), (6, 7)]

    dut.in_valid.value = 1
    dut.in_metadata.value = pack_metadata(dut, 0, 0)
    await ClockCycles(dut.clk, 1)

    for u, v in edges:
        dut.in_metadata.value = pack_metadata(dut, u, v)
        await ClockCycles(dut.clk, 1)

    dut.in_valid.value = 0
    await ClockCycles(dut.clk, 1)

    for _ in range(200):
        await ClockCycles(dut.clk, 1)
        if int(dut.state.value) == STATE_IDLE:
            break
    else:
        assert False, "Timeout waiting for union_find to return to IDLE"

    expected_roots = {0: 0, 1: 0, 2: 0, 3: 0, 4: 4, 5: 4, 6: 4, 7: 4}
    await ReadOnly()
    for node, root in expected_roots.items():
        is_root, payload = unpack_node(dut, node)
        if node == root:
            assert is_root == 1, f"Expected node {node} to be root"
        else:
            assert is_root == 0, f"Expected node {node} to be non-root"
            assert payload == root, f"Expected node {node} parent {root}, got {payload}"


if __name__ == "__main__":
    build_and_run_sim(
        __file__,
        hdl_toplevel="union_find",
        parameters={
            "MAX_NODE_COUNT": MAX_NODE_COUNT,
        },
    )
