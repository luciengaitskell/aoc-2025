import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
import random
from sim.lib import build_and_run_sim, reset


BIT_WIDTH = 8
MAX_INPUTS = 4
FIFO_DEPTH = 256


def generate_test_data(size):
    return [random.randint(0, (1 << BIT_WIDTH) - 1) for _ in range(size)]


def batch_data(data, batch_size):
    """Batch data into chunks of batch_size, padding with zeros if necessary."""
    batches = []
    for i in range(0, len(data), batch_size):
        batch = data[i : i + batch_size]
        # Pad with zeros if necessary
        while len(batch) < batch_size:
            batch.append(0)
        batches.append(batch)
    return batches


def create_keep_mask(batch, threshold):
    mask = 0
    for i, val in enumerate(batch):
        if val < threshold:
            mask |= 1 << i
    return mask


async def send_batched_data(dut, *, data_batches, keep_threshold):
    """Send batched data with keep masks based on threshold."""
    for batch in data_batches:
        while not dut.in_ready.value:
            await RisingEdge(dut.in_ready)
        keep_mask = create_keep_mask(batch, keep_threshold)
        dut.in_data.value = batch
        dut.in_keep.value = keep_mask
        dut.in_valid.value = 1
        await ClockCycles(dut.clk, 1)
    dut.in_valid.value = 0


async def receive_filtered_data(dut, *, expected_data=None, count=None):
    """Receive filtered data from output."""
    if count is None:
        assert expected_data is not None
        count = len(expected_data)
    received_data = []
    timeout = 0
    max_timeout = count * 10  # Allow some cycles for FIFO to drain
    while len(received_data) < count and timeout < max_timeout:
        dut.out_ready.value = 1
        await ClockCycles(dut.clk, 1)
        if dut.out_valid.value == 1:
            received_data.append(int(dut.out_data.value))
            timeout = 0
        else:
            timeout += 1
    dut.out_ready.value = 0

    if expected_data is not None:
        assert received_data == expected_data, (
            f"Received data of length {len(received_data)} does not match expected of length {len(expected_data)}"
        )
    return received_data


@cocotb.test
async def test_a(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut.clk, dut.rst, 2)

    test_data = generate_test_data(1000)

    data_batches = batch_data(test_data, MAX_INPUTS)

    threshold = 128

    expected_output = [val for val in test_data if val < threshold]

    cocotb.start_soon(
        send_batched_data(dut, data_batches=data_batches, keep_threshold=threshold)
    )

    await ClockCycles(dut.clk, 5)

    await receive_filtered_data(dut, expected_data=expected_output)


if __name__ == "__main__":
    build_and_run_sim(
        __file__,
        hdl_toplevel="filtered_fifo",
        parameters={
            "BIT_WIDTH": BIT_WIDTH,
            "MAX_INPUTS": MAX_INPUTS,
            "FIFO_DEPTH": FIFO_DEPTH,
        },
    )
