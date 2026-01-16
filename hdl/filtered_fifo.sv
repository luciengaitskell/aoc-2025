module filtered_fifo #(
    parameter int  BIT_WIDTH  = 32,
    parameter int  MAX_INPUTS = 4,
    parameter int  FIFO_DEPTH = 256,
    parameter type DATA_TYPE  = logic [BIT_WIDTH-1:0]
) (
    input logic clk,
    input logic rst,
    input logic in_valid,
    input DATA_TYPE in_data[0:MAX_INPUTS-1],
    input logic [MAX_INPUTS-1:0] in_keep,
    output logic in_ready,
    output logic out_valid,
    output DATA_TYPE out_data,
    input logic out_ready
);
  initial begin
    assert (MAX_INPUTS > 0)
    else $fatal(1, "MAX_INPUTS must be greater than 0.");
    assert ((MAX_INPUTS % 2) == 0)
    else $fatal(1, "MAX_INPUTS must be even.");
    assert (FIFO_DEPTH > 0 && (FIFO_DEPTH % 2) == 0 && (FIFO_DEPTH % MAX_INPUTS) == 0)
    else $fatal(1, "FIFO_DEPTH must be even and divisible by MAX_INPUTS.");
  end

  localparam int FIFO_COUNT_WIDTH = $clog2(MAX_INPUTS);

  logic [BIT_WIDTH-1:0] in_data_compacted[0:MAX_INPUTS-1];
  logic [FIFO_COUNT_WIDTH-1:0] in_count;
  always_comb begin
    in_count = 0;
    in_data_compacted = '{default: 0};
    for (int i = 0; i < MAX_INPUTS; i++) begin
      if (in_keep[i]) begin
        in_data_compacted[in_count] = in_data[i];
        in_count++;
      end
    end
  end

  logic [FIFO_COUNT_WIDTH-1:0] next_fifo_write;
  logic [MAX_INPUTS-1:0] fifo_full;
  // logic [MAX_INPUTS-1:0] fifo_empty;

  assign in_ready = !(&fifo_full);
  wire in_transaction = in_valid && (in_count > 0) && in_ready;


  logic [BIT_WIDTH-1:0] fifo_out_data[0:MAX_INPUTS-1];
  logic fifo_out_valid[0:MAX_INPUTS-1];
  logic [FIFO_COUNT_WIDTH-1:0] next_fifo_read;
  assign out_valid = fifo_out_valid[next_fifo_read];
  assign out_data  = fifo_out_data[next_fifo_read];

  wire out_transaction = out_valid && out_ready;
  always_ff @(posedge clk) begin
    if (rst) begin
      next_fifo_read <= 0;
    end else if (out_transaction) begin
      next_fifo_read <= next_fifo_read + FIFO_COUNT_WIDTH'(1'b1);
    end
  end

  generate
    for (genvar i = 0; i < MAX_INPUTS; i++) begin : genFifos
      wire [FIFO_COUNT_WIDTH-1:0] index = FIFO_COUNT_WIDTH'(i);
      wire [FIFO_COUNT_WIDTH-1:0] adjusted_index = (index - next_fifo_write);
      fifo #(
          .BIT_WIDTH  (BIT_WIDTH),
          .DEPTH      (256),
          .READ_CYCLES(0)           // change to 1 if timing issues arise
      ) fifo (
          .clk       (clk),
          .rst       (rst),
          .in_valid  (in_valid && (in_count > adjusted_index)),
          .in_data   (in_data_compacted[adjusted_index]),
          .out_enable((i == next_fifo_read) && out_transaction),
          .out_valid (fifo_out_valid[i]),
          .out_data  (fifo_out_data[i]),
          .full      (fifo_full[i]),
          /* verilator lint_off PINCONNECTEMPTY */
          .empty     ()
          /* verilator lint_on  PINCONNECTEMPTY */
      );
    end
  endgenerate

  always_ff @(posedge clk) begin
    if (rst) begin
      next_fifo_write <= 0;
    end else if (in_transaction) begin
      next_fifo_write <= next_fifo_write + in_count;
    end
  end

endmodule
