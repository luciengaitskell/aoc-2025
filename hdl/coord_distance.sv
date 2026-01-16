module coord_distance #(
    parameter int COORD_BIT_WIDTH = 12,
    parameter int DIMENSIONS = 3,
    parameter int BATCH_SIZE = 16,
    localparam int DISTANCE_SQ_BIT_WIDTH = (2 * COORD_BIT_WIDTH) + $clog2(3)
) (
    input logic clk,
    input logic rst,
    input logic [COORD_BIT_WIDTH-1:0] reference_point[0:DIMENSIONS-1],
    input logic in_valid,
    input logic [COORD_BIT_WIDTH-1:0] coords[0:BATCH_SIZE-1][0:DIMENSIONS-1],
    output logic out_valid,
    output logic [DISTANCE_SQ_BIT_WIDTH-1:0] distances_sq[0:BATCH_SIZE-1]
);

  always_ff @(posedge clk) begin : calculate
    if (rst) begin
      out_valid <= 1'b0;
    end else begin
      out_valid <= in_valid;
      for (int i = 0; i < BATCH_SIZE; i++) begin
        logic [DISTANCE_SQ_BIT_WIDTH-1:0] sum;
        sum = '0;
        for (int d = 0; d < DIMENSIONS; d++) begin
          logic signed [COORD_BIT_WIDTH:0] diff;
          logic [DISTANCE_SQ_BIT_WIDTH-1:0] diff_sq;
          diff = $signed({1'b0, coords[i][d]}) - $signed({1'b0, reference_point[d]});
          diff_sq = DISTANCE_SQ_BIT_WIDTH'($unsigned((DISTANCE_SQ_BIT_WIDTH + 1)'(diff) ** 2));
          sum = sum + (diff_sq);
        end
        distances_sq[i] <= sum;
      end
    end
  end
endmodule
