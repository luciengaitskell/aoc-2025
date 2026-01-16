
localparam int INDEX_WIDTH = 32;

typedef struct packed {
  logic [INDEX_WIDTH-1:0] id1;
  logic [INDEX_WIDTH-1:0] id2;
} id_pair_s;

module systolic_sorter #(
    parameter int ELEMENTS = 64,
    parameter int BIT_WIDTH = 32,
    parameter type METADATA_TYPE = id_pair_s
) (
    input logic clk,
    input logic rst,
    input logic in_valid,
    input logic [BIT_WIDTH-1:0] in_data,
    input METADATA_TYPE in_metadata,
    input logic in_last,
    output logic largest_valid,
    output logic [BIT_WIDTH-1:0] largest,
    input logic out_ready,
    output logic out_last,
    output logic out_valid,
    output logic [BIT_WIDTH-1:0] out_data,
    output METADATA_TYPE out_metadata
);

  enum logic [0:0] {
    RUN,
    SHIFTOUT
  } state;


  logic array_valid[0:ELEMENTS-1];
  logic [BIT_WIDTH-1:0] array_data[0:ELEMENTS-1];
  id_pair_s array_metadata[0:ELEMENTS-1];
  // the values moving are being propagated
  //  note that it is one element larger to make my generator loops cleaner
  //  (the last element should not be used)
  logic array_valid_moving[0:ELEMENTS];
  logic [BIT_WIDTH-1:0] array_data_moving[0:ELEMENTS];
  id_pair_s array_metadata_moving[0:ELEMENTS];
  logic last_moving[0:ELEMENTS];


  always_comb begin : inputAssign
    array_valid_moving[0] = in_valid;
    array_data_moving[0] = in_data;
    array_metadata_moving[0] = in_metadata;
    last_moving[0] = in_last;
  end

  always_comb begin : largestAssign
    largest_valid = array_valid[ELEMENTS-1];
    largest = array_data[ELEMENTS-1];
  end

  always_ff @(posedge clk) begin : lastLatch
    if (rst) begin
      out_last <= 1'b0;
    end else if (last_moving[ELEMENTS]) begin
      out_last <= last_moving[ELEMENTS];
    end
  end

  // Input loading
  always_ff @(posedge clk) begin : systolicArray
    if (rst) begin
      for (int i = 0; i < ELEMENTS; i++) begin
        array_valid[i] <= 1'b0;
      end
      state <= RUN;
    end else begin
      case (state)
        RUN: begin
          if (out_last) begin
            state <= SHIFTOUT;
          end else begin
            for (int i = 0; i < ELEMENTS; i++) begin
              last_moving[i+1] <= last_moving[i];
              if (!array_valid[i]) begin
                array_valid[i] <= array_valid_moving[i];
                array_data[i] <= array_data_moving[i];
                array_metadata[i] <= array_metadata_moving[i];

                array_valid_moving[i+1] <= 1'b0;  // consumed
              end else if (!array_valid_moving[i]) begin
                // propagate invalid
                array_valid_moving[i+1] <= array_valid_moving[i];
              end else begin
                // compare and swap
                if (array_data_moving[i] < array_data[i]) begin
                  // moving value is smaller, swap
                  array_valid_moving[i+1] <= array_valid[i];
                  array_data_moving[i+1] <= array_data[i];
                  array_metadata_moving[i+1] <= array_metadata[i];

                  array_valid[i] <= array_valid_moving[i];
                  array_data[i] <= array_data_moving[i];
                  array_metadata[i] <= array_metadata_moving[i];
                end else begin
                  // current value is smaller, propagate moving
                  array_valid_moving[i+1] <= array_valid_moving[i];
                  array_data_moving[i+1] <= array_data_moving[i];
                  array_metadata_moving[i+1] <= array_metadata_moving[i];
                end
              end
            end
          end
        end
        SHIFTOUT: begin
          if (!out_valid) begin
            state <= RUN;
          end else if (out_ready) begin
            array_valid[0] <= 1'b0;
            for (int i = 0; i < ELEMENTS-1; i++) begin
              array_valid[i+1] <= array_valid[i];
              array_data[i+1] <= array_data[i];
              array_metadata[i+1] <= array_metadata[i];
            end
          end
        end
        default: begin
          state <= RUN;
        end
      endcase
    end
  end

  always_comb begin : outputSelect
    out_valid = array_valid[ELEMENTS-1] && (state == SHIFTOUT);
    out_data = array_data[ELEMENTS-1];
    out_metadata = array_metadata[ELEMENTS-1];
  end
endmodule
