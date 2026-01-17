module day08_top #(
    parameter  int MAX_NODE_COUNT  = 2000,
    localparam int INDEX_BIT_WIDTH = $clog2(MAX_NODE_COUNT),
    parameter  int SORTER_ELEMENTS = 1000,

    parameter int COORD_BIT_WIDTH = 12,
    parameter int DIMENSIONS = 3,
    parameter int BATCH_SIZE = 16,
    parameter int TOP_N = 3,
    localparam type METADATA_TYPE = struct packed {
      logic [INDEX_BIT_WIDTH-1:0] u;
      logic [INDEX_BIT_WIDTH-1:0] v;
    },
    localparam int PRODUCT_BIT_WIDTH = INDEX_BIT_WIDTH * TOP_N
) (
    input logic clk,
    input logic rst,

    input  logic batch_line_end,
    input  logic batch_stream_end,
    output logic in_ready,

    input logic [COORD_BIT_WIDTH-1:0] batch_coords[0:BATCH_SIZE-1][0:DIMENSIONS-1],
    input logic [INDEX_BIT_WIDTH-1:0] batch_indices[0:BATCH_SIZE-1],
    input logic [BATCH_SIZE-1:0] batch_valid,

    output logic out_valid,
    output logic [INDEX_BIT_WIDTH-1:0] top_sizes[0:TOP_N-1],
    output logic [INDEX_BIT_WIDTH-1:0] top_roots[0:TOP_N-1],
    output logic [PRODUCT_BIT_WIDTH-1:0] top_product
);
  localparam int DISTANCE_SQ_BIT_WIDTH = (2 * COORD_BIT_WIDTH) + $clog2(3);


  logic [DISTANCE_SQ_BIT_WIDTH-1:0] distances_sq[0:BATCH_SIZE-1];

  typedef struct packed {
    logic [DISTANCE_SQ_BIT_WIDTH-1:0] distance_sq;
    METADATA_TYPE metadata;
    logic last;
  } fifo_data_t;


  logic fifo_ready;
  METADATA_TYPE out_metadata[0:BATCH_SIZE-1];
  logic coord_out_valid;
  logic coord_last;
  logic last_only_pulse;
  logic line_start;
  logic [COORD_BIT_WIDTH-1:0] current_ref_point[0:DIMENSIONS-1];
  logic [INDEX_BIT_WIDTH-1:0] current_ref_index;
  logic sweep_active;
  logic [INDEX_BIT_WIDTH-1:0] sweep_index;

  wire coord_in_valid = |batch_valid && fifo_ready;
  logic [COORD_BIT_WIDTH-1:0] ref_point[0:DIMENSIONS-1];
  logic [INDEX_BIT_WIDTH-1:0] ref_index;

  always_comb begin
    for (int d = 0; d < DIMENSIONS; d++) begin
      ref_point[d] = line_start ? batch_coords[0][d] : current_ref_point[d];
    end
    ref_index = line_start ? batch_indices[0] : current_ref_index;
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      line_start <= 1'b1;
      current_ref_index <= '0;
      for (int d = 0; d < DIMENSIONS; d++) begin
        current_ref_point[d] <= '0;
      end
    end else if (coord_in_valid) begin
      if (line_start) begin
        current_ref_index <= batch_indices[0];
        for (int d = 0; d < DIMENSIONS; d++) begin
          current_ref_point[d] <= batch_coords[0][d];
        end
      end
      line_start <= batch_line_end;
    end
  end

  coord_distance #(
      .INDEX_BIT_WIDTH(INDEX_BIT_WIDTH),
      .COORD_BIT_WIDTH(COORD_BIT_WIDTH),
      .DIMENSIONS(DIMENSIONS),
      .BATCH_SIZE(BATCH_SIZE),
      .METADATA_TYPE(METADATA_TYPE)
  ) coord_distance (
      .clk            (clk),
      .rst            (rst),
      .reference_point(ref_point),
      .reference_index(ref_index),
      .in_valid       (coord_in_valid),
      .coords         (batch_coords),
      .in_indices     (batch_indices),
      .out_valid      (coord_out_valid),
      .distances_sq   (distances_sq),
      .out_metadata   (out_metadata)
  );

  logic valid_kept_found;
  logic [INDEX_BIT_WIDTH-1:0] valid_kept_found_index;
  always_ff @(posedge clk) begin
    if (rst) begin
      coord_last <= 1'b0;
    end else begin
      coord_last <= batch_stream_end;
    end
  end

  logic [BATCH_SIZE-1:0] in_keep;
  logic largest_valid;
  logic [DISTANCE_SQ_BIT_WIDTH-1:0] largest;
  logic [BATCH_SIZE-1:0] delayed_batch_valid;
  always_ff @(posedge clk) begin
    delayed_batch_valid <= batch_valid;
  end

  always_comb begin
    valid_kept_found = 1'b0;
    valid_kept_found_index = '0;
    for (int i = 0; i < BATCH_SIZE; i++) begin
      if ((out_metadata[i].u != out_metadata[i].v) && (!largest_valid || (distances_sq[i] < largest)) && delayed_batch_valid[i]) begin
        in_keep[i] = 1'b1;
        valid_kept_found = 1'b1;
        valid_kept_found_index = batch_indices[i];
      end else begin
        in_keep[i] = 1'b0;
      end
    end
  end

  logic reset_last_only_pulse;
  always_ff @(posedge clk) begin
    if (rst || reset_last_only_pulse) begin
      last_only_pulse <= 1'b0;
    end else if (coord_out_valid && coord_last && !valid_kept_found) begin
      last_only_pulse <= 1'b1;
    end
  end

  fifo_data_t fifo_in_data[0:BATCH_SIZE-1];
  always_comb begin
    for (int i = 0; i < BATCH_SIZE; i++) begin
      fifo_in_data[i].distance_sq = distances_sq[i];
      fifo_in_data[i].metadata = out_metadata[i];
      fifo_in_data[i].last = coord_last && valid_kept_found && (batch_indices[i] == valid_kept_found_index);
    end
  end
  logic fifo_out_valid;
  fifo_data_t fifo_out_data;
  filtered_fifo #(
      .BIT_WIDTH ($bits(fifo_data_t)),
      .MAX_INPUTS(BATCH_SIZE),
      .FIFO_DEPTH(512),
      .DATA_TYPE (fifo_data_t)
  ) filtered_fifo (
      .clk      (clk),
      .rst      (rst),
      .in_valid (coord_out_valid),
      .in_data  (fifo_in_data),
      .in_keep  (in_keep),
      .in_ready (fifo_ready),
      .out_valid(fifo_out_valid),
      .out_data (fifo_out_data),
      .out_ready(1'b1)
  );


  METADATA_TYPE sorter_out_metadata;
  logic sorter_out_valid;
  // logic sorter_out_last;
  logic uf_in_ready;

  wire sorter_in_valid = fifo_out_valid;
  wire sorter_in_last = fifo_out_valid ? fifo_out_data.last : last_only_pulse;
  assign reset_last_only_pulse = sorter_in_last;

  systolic_sorter #(
      .ELEMENTS     (SORTER_ELEMENTS),
      .BIT_WIDTH    (DISTANCE_SQ_BIT_WIDTH),
      .METADATA_TYPE(METADATA_TYPE)
  ) systolic_sorter (
      .clk          (clk),
      .rst          (rst),
      .in_valid     (sorter_in_valid),
      .in_data      (fifo_out_data.distance_sq),
      .in_metadata  (fifo_out_data.metadata),
      .in_last      (sorter_in_last),
      .largest_valid(largest_valid),
      .largest      (largest),
      .out_ready    (uf_in_ready),
      .out_valid    (sorter_out_valid),
      .out_metadata (sorter_out_metadata),
      /* verilator lint_off PINCONNECTEMPTY */
      .out_last     (/*sorter_out_last*/),
      .out_data     ()
      /* verilator lint_on PINCONNECTEMPTY */
  );

  logic uf_out_valid;
  logic uf_out_is_root;
  logic [INDEX_BIT_WIDTH-1:0] uf_out_size;
  logic [INDEX_BIT_WIDTH-1:0] uf_out_index;

  union_find #(
      .MAX_NODE_COUNT(MAX_NODE_COUNT)
  ) union_find (
      .clk        (clk),
      .rst        (rst),
      .in_valid   (sorter_out_valid),
      .in_metadata(sorter_out_metadata),
      .in_ready   (uf_in_ready),
      .out_index  (uf_out_index),
      .out_valid  (uf_out_valid),
      .out_is_root(uf_out_is_root),
      .out_size   (uf_out_size)
  );

  assign in_ready = fifo_ready;

  always_ff @(posedge clk) begin
    if (rst) begin
      sweep_active <= 1'b0;
    end else if (!sweep_active) begin
      if (uf_out_valid) begin
        out_valid <= 1'b0;
        sweep_active <= 1'b1;
        sweep_index <= '0;
      end
    end else begin
      for (int d = 0; d < TOP_N; d++) begin
        if (uf_out_is_root && (uf_out_size > top_sizes[d])) begin
          // shift down
          for (int sd = TOP_N-1; sd > d; sd--) begin
            top_sizes[sd] <= top_sizes[sd-1];
            top_roots[sd] <= top_roots[sd-1];
          end
          top_sizes[d] <= uf_out_size;
          top_roots[d] <= uf_out_index;
          break;
        end
      end

      if (sweep_index == INDEX_BIT_WIDTH'($unsigned(MAX_NODE_COUNT - 1))) begin
        sweep_active <= 1'b0;
        out_valid <= 1'b1;
      end else begin
        sweep_index <= sweep_index + INDEX_BIT_WIDTH'(1'b1);
      end
    end
  end

  assign uf_out_index = sweep_active ? sweep_index : '0;
  always_comb begin
    top_product = PRODUCT_BIT_WIDTH'(top_sizes[0]);
    for (int d = 1; d < TOP_N; d++) begin
      top_product = top_product * PRODUCT_BIT_WIDTH'(top_sizes[d]);
    end
  end

endmodule
