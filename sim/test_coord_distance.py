import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, ReadOnly
import numpy as np
from sim.lib import build_and_run_sim, reset


COORD_BIT_WIDTH = 8
DIMENSIONS = 3
BATCH_SIZE = 4


def generate_test_data(size):
    return np.random.randint(0, 1 << COORD_BIT_WIDTH, size=size, dtype=np.uint32)


async def drive_test_data(dut):
    test_data = generate_test_data((BATCH_SIZE, DIMENSIONS))
    dut.coords.value = test_data.tolist()
    dut.in_valid.value = 1
    await ClockCycles(dut.clk, 1)
    dut.in_valid.value = 0
    return test_data


@cocotb.test
async def test_a(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut.clk, dut.rst, 2)

    reference_point = generate_test_data((DIMENSIONS,))
    dut.reference_point.value = reference_point.tolist()

    test_data = await drive_test_data(dut)
    await ReadOnly()
    assert dut.out_valid.value == 1, "Expected out_valid to be 1"
    expected_distances_sq = np.sum((test_data - reference_point) ** 2, axis=1)
    distances_sq = np.array([d.value.to_unsigned() for d in dut.distances_sq]).astype(
        np.uint64
    )
    assert np.array_equal(distances_sq, expected_distances_sq), (
        f"Expected distances {expected_distances_sq}, but got {distances_sq}"
    )


if __name__ == "__main__":
    build_and_run_sim(
        __file__,
        hdl_toplevel="coord_distance",
        parameters={
            "COORD_BIT_WIDTH": COORD_BIT_WIDTH,
            "DIMENSIONS": DIMENSIONS,
            "BATCH_SIZE": BATCH_SIZE,
        },
    )
