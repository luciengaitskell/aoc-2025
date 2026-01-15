import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, ReadOnly
from sim.lib import build_and_run_sim, reset


@cocotb.test
async def test_a(dut):
    test_data = [15, 15, 15, 15, 14, 11, 8, 9, 10, 8, 8, 6, 4, 2, 0, 2, 1, 3, 5, 7, 9]

    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut.clk, dut.rst, 2)

    for i, val in enumerate(test_data):
        dut.in_data.value = val
        # dut.in_metadata.value = i
        dut.in_valid.value = 1
        dut.in_last.value = int(i == len(test_data) - 1)
        await ClockCycles(dut.clk, 1)
    dut.in_valid.value = 0

    await RisingEdge(dut.out_last)

    for i, val in enumerate(sorted(test_data)):
        dut.out_address.value = i
        await ReadOnly()
        output_value = dut.out_data.value.to_unsigned()
        # print(f"Got output value: {output_value}, expected {val}")
        assert output_value == val, (
            f"at index {i}, expected {val} but got {output_value}"
        )
        await ClockCycles(dut.clk, 1)


if __name__ == "__main__":
    build_and_run_sim(
        __file__,
        hdl_toplevel="systolic_sorter",
        parameters={
            "BIT_WIDTH": 32,
        },
    )
