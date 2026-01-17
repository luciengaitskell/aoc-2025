import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, ReadOnly
from sim.lib import build_and_run_sim, reset


BIT_WIDTH = 32
DEPTH = 16


def generate_test_data(size):
    return [random.randint(0, (1 << BIT_WIDTH) - 1) for _ in range(size)]


async def send_test_data(dut, *, test_data=None, count=None):
    if test_data is None:
        assert count is not None
        test_data = generate_test_data(count)
    for i, val in enumerate(test_data):
        dut.in_data.value = val
        dut.in_valid.value = 1
        await ClockCycles(dut.clk, 1)
    dut.in_valid.value = 0
    return test_data


async def receive_test_data(dut, *, expected_data=None, count=None):
    if count is None:
        assert expected_data is not None
        count = len(expected_data)
    received_data = []
    while len(received_data) < count:
        dut.out_enable.value = 1
        await ClockCycles(dut.clk, 1)
        if dut.out_valid.value == 1:
            received_data.append(int(dut.out_data.value))
    dut.out_enable.value = 0
    if expected_data is not None:
        assert received_data == expected_data, (
            f"Received data {received_data} does not match expected {expected_data}"
        )
    return received_data


@cocotb.test
async def test_a(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut.clk, dut.rst, 2)

    for amount in [1, 3, DEPTH - 1, DEPTH, DEPTH + 1]:
        test_data = await send_test_data(dut, count=amount)
        await ReadOnly()
        await ClockCycles(dut.clk, 1)
        expected_full = 1 if amount >= DEPTH - 1 else 0
        assert dut.full.value == expected_full, (
            f"Expected FIFO to be {'full' if expected_full else 'not full'}"
            f" after sending {amount} elements"
        )

        test_data = test_data[: DEPTH - 1]  # FIFO will stop accepting when full

        await receive_test_data(dut, expected_data=test_data)
        await ReadOnly()
        assert dut.empty.value == 1, (
            f"Expected FIFO to be empty after receiving all {amount} elements"
        )
        await ClockCycles(dut.clk, 1)


if __name__ == "__main__":
    build_and_run_sim(
        __file__,
        hdl_toplevel="fifo",
        parameters={
            "BIT_WIDTH": BIT_WIDTH,
            "DEPTH": DEPTH,
        },
    )
