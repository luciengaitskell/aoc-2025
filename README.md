# aoc-2025
my approaches to Advent of Code 2025

```
uv run -m days.08.test_hdl_attempt
```

### Jane Street Advent of FPGA

I built day 8 in an FPGA design with the following architecture:

1. Distance engine: calculate the squared distance between current
point-of-interest and the other points
2. FIFO to serialize and pre-filter the batches of distances
3. Systolic queue to hold the top N entries by value
4. Union-Find to determine the largest connected components

This design relies on having an off-chip memory to stream in
the point coordinates continuously while evaluating the
squared distances. This avoids having a full-sized on-chip
memory to store the entire set of nodes.

Additionally, my pipeline supports processing a batch of
points each cycle to take advantage of wide external memory busses.
To then serialize these outputs into the systolic priority queue,
there is a multi-input-per-cycle FIFO. This module had threshold
filtering to immediately reject any inputs that are greater than
or equal to the current largest value in the systolic queue.
In tests, this prevents the queues from overflowing.

The systolic queue sorts the distance values by shuffling
larger values down the queue. Once the input values are exhausted,
all values remaining in the queue are kept and shuffled out to
a LUTRAM indexed by node. The Union-Find module is
able to take advantage of the LUTRAM by performing single-cycle
multi-step parent resolution. The path compression occurs
sequentially, but the nature of the algorithm means that
each compress step will be short in expectation.
During this process, the size of the connected component
for each root is accumulated.

Finally, sweeping through the connected components in the LUTRAM
allows the selection of the top 3 sizes, which are then multiplied
together and returned.


#### Correctness
I was able to demonstrate synthesis of this design,
with the default (reduced) size parameters in the top level.
I demonstrate logical correctness in my testbench.
