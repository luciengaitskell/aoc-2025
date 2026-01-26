module coord_distance #(
    parameter int INDEX_BIT_WIDTH = 32,
    parameter int COORD_BIT_WIDTH = 12,
    parameter int DIMENSIONS = 3,
    parameter int BATCH_SIZE = 16,
    localparam int DISTANCE_SQ_BIT_WIDTH = (2 * COORD_BIT_WIDTH) + $clog2(3),
    parameter type INDEX_TYPE = logic [INDEX_BIT_WIDTH-1:0],
    parameter type METADATA_TYPE = struct packed {
      INDEX_TYPE u;
      INDEX_TYPE v;
    }
) (
    input logic clk,
    input logic rst,
    input logic [COORD_BIT_WIDTH-1:0] reference_point[0:DIMENSIONS-1],
    input INDEX_TYPE reference_index,
    input logic in_valid,
    input logic [COORD_BIT_WIDTH-1:0] coords[0:BATCH_SIZE-1][0:DIMENSIONS-1],
    input INDEX_TYPE in_indices[0:BATCH_SIZE-1],
    input logic out_ready,
    output logic out_valid,
    output logic [DISTANCE_SQ_BIT_WIDTH-1:0] distances_sq[0:BATCH_SIZE-1],
    output METADATA_TYPE out_metadata[0:BATCH_SIZE-1]
);

  always_ff @(posedge clk) begin : calculate
    if (rst) begin
      out_valid <= 1'b0;
    end else if (out_ready) begin
      out_valid <= in_valid;
      for (int i = 0; i < BATCH_SIZE; i++) begin
        out_metadata[i].u <= reference_index;
        out_metadata[i].v <= in_indices[i];
      end
      for (int i = 0; i < BATCH_SIZE; i++) begin
        logic [DISTANCE_SQ_BIT_WIDTH-1:0] sum;
        sum = '0;
        for (int d = 0; d < DIMENSIONS; d++) begin
          logic signed [COORD_BIT_WIDTH:0] diff;
          logic signed [DISTANCE_SQ_BIT_WIDTH:0] diff_expanded;
          logic [DISTANCE_SQ_BIT_WIDTH-1:0] diff_sq;
          diff = $signed({1'b0, coords[i][d]}) - $signed({1'b0, reference_point[d]});
          diff_expanded = (DISTANCE_SQ_BIT_WIDTH + 1)'(diff);
          diff_sq = DISTANCE_SQ_BIT_WIDTH'($unsigned(diff_expanded * diff_expanded));
          sum = sum + (diff_sq);
        end
        distances_sq[i] <= sum;
      end
    end
  end
endmodule
