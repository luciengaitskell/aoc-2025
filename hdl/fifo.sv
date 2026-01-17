module fifo #(
    parameter int BIT_WIDTH = 32,
    parameter int DEPTH = 16,
    parameter int READ_CYCLES = 0,
    parameter type DATA_TYPE = logic [BIT_WIDTH-1:0]
) (
    input logic clk,

    input logic rst,
    input logic in_valid,
    input DATA_TYPE in_data,
    input logic out_enable,
    output logic out_valid,
    output DATA_TYPE out_data,
    output logic full,
    output logic empty
);
  initial begin
    assert (DEPTH > 0 && (DEPTH & (DEPTH - 1)) == 0)
    else $fatal(1, "DEPTH must be a power of 2.");
    assert (READ_CYCLES == 0 || READ_CYCLES == 1)
    else $fatal(1, "READ_CYCLES must be 0 or 1.");
  end
  localparam int ADDR_BIT_WIDTH = $clog2(DEPTH);
  DATA_TYPE mem[0:DEPTH-1];
  logic [ADDR_BIT_WIDTH-1:0] write_ptr;
  logic [ADDR_BIT_WIDTH-1:0] read_ptr;

  assign full  = (write_ptr + ADDR_BIT_WIDTH'(1'b1)) == read_ptr;
  assign empty = write_ptr == read_ptr;

  always_ff @(posedge clk) begin : writeLogic
    if (rst) begin
      write_ptr <= '0;
    end else if (in_valid && !full) begin
      mem[write_ptr] <= in_data;
      write_ptr <= write_ptr + ADDR_BIT_WIDTH'(1'b1);
    end
  end

  if (READ_CYCLES == 0) begin : zeroCycleRead
    always_comb begin : readLogic
      out_valid = !empty;
      out_data  = mem[read_ptr];
    end
    always_ff @(posedge clk) begin : readPtrAdvance
      if (rst) begin
        read_ptr <= '0;
      end else if (out_enable && out_valid) begin
        read_ptr <= read_ptr + ADDR_BIT_WIDTH'(1'b1);
      end
    end
  end else if (READ_CYCLES == 1) begin : oneCycleRead
    // FIXME: write test for this
    always_ff @(posedge clk) begin : readLogic
      if (rst) begin
        read_ptr  <= '0;
        out_valid <= 1'b0;
        out_data  <= '0;
      end else if (out_enable && !empty) begin
        out_data  <= mem[read_ptr];
        out_valid <= 1'b1;
        read_ptr  <= read_ptr + ADDR_BIT_WIDTH'(1'b1);
      end else begin
        out_valid <= 1'b0;
      end
    end
  end

endmodule
