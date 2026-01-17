import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge
import numpy as np
import importlib

from sim.lib import build_and_run_sim, reset
from days.lib.input import load_input

# integer in dir name breaks standard import
attempt = importlib.import_module("days.08.attempt")
solve_coords = attempt.solve_coords
load_coords = attempt.load_coords


DIMENSIONS = 3
BATCH_SIZE = 4
TOP_N = 3

if False:
    COORD_BIT_WIDTH = 32
    coords = load_coords()
    MAX_NODE_COUNT = len(coords)
    assert MAX_NODE_COUNT == 1000
    SORTER_ELEMENTS = MAX_NODE_COUNT
else:
    COORD_BIT_WIDTH = 24
    MAX_NODE_COUNT = 1000
    SORTER_ELEMENTS = 1000

    def generate_coords(count):
        rng = np.random.default_rng(1234)
        return rng.integers(
            0, (1 << COORD_BIT_WIDTH) - 1, size=(count, DIMENSIONS), dtype=np.uint32
        )

    coords = generate_coords(MAX_NODE_COUNT)


def batch_indices(indices, batch_size, pad_value):
    if len(indices) % batch_size != 0:
        padding_amount = batch_size - (len(indices) % batch_size)
        indices = indices + [pad_value] * padding_amount
    return [indices[i : i + batch_size] for i in range(0, len(indices), batch_size)]


async def drive_stream(dut, coords):
    n = coords.shape[0]
    for i in range(n):
        line_indices = list(range(i, n))
        batches = batch_indices(line_indices, BATCH_SIZE, pad_value=None)
        for j, batch in enumerate(batches):
            while not dut.in_ready.value:
                await ClockCycles(dut.clk, 1)
            batch_valid_bits = 0
            for bit_idx, value in enumerate(batch):
                if value is None:
                    batch[bit_idx] = 0
                else:
                    batch_valid_bits |= 1 << bit_idx
            dut.batch_valid.value = batch_valid_bits

            dut.batch_line_end.value = (line_end := int(j == (len(batches) - 1)))
            dut.batch_stream_end.value = int((i == (n - 1)) and line_end)
            dut.batch_coords.value = [coords[idx].tolist() for idx in batch]
            dut.batch_indices.value = batch
            await ClockCycles(dut.clk, 1)
    dut.batch_valid.value = 0
    dut.batch_line_end.value = 0
    dut.batch_stream_end.value = 0
    await ClockCycles(dut.clk, 1)


@cocotb.test
async def test_a(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut.clk, dut.rst, 2)

    expected_sizes, expected_product = solve_coords(
        coords,
        k=SORTER_ELEMENTS,
        m=TOP_N,
    )

    await drive_stream(dut, coords)
    dut._log.info("All input driven")

    dut._log.info("Waiting for sorter output to exhaust")
    await FallingEdge(dut.sorter_out_valid)
    dut._log.info("Sorter output finished, waiting for top output valid")
    for _ in range(2):
        # exhaust stale half-accumulation so wait for second valid
        await RisingEdge(dut.out_valid)

    dut._log.info("Top output valid, sampling results")
    got_sizes = [int(dut.top_sizes[i].value) for i in range(TOP_N)]
    got_product = int(dut.top_product.value)

    expected_sizes = expected_sizes.tolist()
    await ClockCycles(dut.clk, 100)  # FIXME: tmp to extend
    assert len(expected_sizes) == TOP_N, (
        f"Expected sizes length mismatch: expected {TOP_N}, got {len(expected_sizes)}"
    )
    assert got_sizes == expected_sizes, (
        f"Top sizes mismatch: expected {expected_sizes}, got {got_sizes}"
    )
    assert got_product == expected_product, (
        f"Top product mismatch: expected {expected_product}, got {got_product}"
    )


if __name__ == "__main__":
    build_and_run_sim(
        __file__,
        hdl_toplevel="day08_top",
        additional_sources=["days/08/day08_top.sv"],
        parameters={
            "COORD_BIT_WIDTH": COORD_BIT_WIDTH,
            "DIMENSIONS": DIMENSIONS,
            "BATCH_SIZE": BATCH_SIZE,
            "TOP_N": TOP_N,
            "SORTER_ELEMENTS": SORTER_ELEMENTS,
            "MAX_NODE_COUNT": MAX_NODE_COUNT,
        },
    )
