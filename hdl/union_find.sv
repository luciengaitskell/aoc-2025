module union_find #(
    parameter int MAX_NODE_COUNT = 2000,
    localparam int INDEX_BIT_WIDTH = $clog2(MAX_NODE_COUNT),
    localparam type METADATA_TYPE = struct packed {
      logic [INDEX_BIT_WIDTH-1:0] u;
      logic [INDEX_BIT_WIDTH-1:0] v;
    }
) (
    input logic clk,
    input logic rst,
    input logic in_valid,
    input METADATA_TYPE in_metadata,
    output logic in_ready,
    input logic [INDEX_BIT_WIDTH-1:0] out_index,
    output logic out_valid,
    output logic out_is_root,
    output logic [INDEX_BIT_WIDTH-1:0] out_size
);

  typedef struct packed {
    bit is_root;

    union packed {
      bit [INDEX_BIT_WIDTH-1:0] parent_idx;  // used if is_root == 0
      bit [INDEX_BIT_WIDTH-1:0] size;        // used if is_root == 1
    } payload;
  } uf_node_t;

  uf_node_t nodes[0:MAX_NODE_COUNT-1];  // should be a LUTRAM

  enum logic [1:0] {
    IDLE,
    READIN,
    FINDROOT,
    COMPRESS
  } state;
  assign in_ready = (state == READIN);

  always_comb begin
    out_valid = state == IDLE;
    out_is_root = nodes[out_index].is_root;
    out_size    = nodes[out_index].payload.size;
  end

  logic [INDEX_BIT_WIDTH-1:0] search_from;
  logic [INDEX_BIT_WIDTH-1:0] compressing_node;
  logic [INDEX_BIT_WIDTH-1:0] root;
  logic [INDEX_BIT_WIDTH-1:0] depth;

  always_ff @(posedge clk) begin
    if (rst) begin
      state <= IDLE;
      for (int i = 0; i < MAX_NODE_COUNT; i++) begin
        nodes[i] <= '{is_root: 1'b1, payload: INDEX_BIT_WIDTH'(1'b1)};
      end
    end else begin
      case (state)
        IDLE: begin
          if (in_valid) begin
            state <= READIN;
          end
        end
        READIN: begin
          if (!in_valid) begin
            state <= FINDROOT;
            root <= '0;  // not really the 'root', but start there
            search_from <= '0;
          end else begin
            nodes[in_metadata.v] <= '{is_root: 1'b0, payload: in_metadata.u};
          end
        end
        FINDROOT: begin
          uf_node_t s0, s1, s2, s3, s4, s5;
          depth <= 0;
          compressing_node <= search_from;

          s0 = nodes[root];
          s1 = nodes[s0.payload.parent_idx];
          s2 = nodes[s1.payload.parent_idx];
          s3 = nodes[s2.payload.parent_idx];
          s4 = nodes[s3.payload.parent_idx];
          s5 = nodes[s4.payload.parent_idx];

          if (s0.is_root) begin
            root  <= search_from;
            state <= COMPRESS;
            // hypothetically could skip COMPRESS, as it will do nothing
          end else if (s1.is_root) begin
            root  <= s0.payload.parent_idx;
            state <= COMPRESS;
          end else if (s2.is_root) begin
            root  <= s1.payload.parent_idx;
            state <= COMPRESS;
          end else if (s3.is_root) begin
            root  <= s2.payload.parent_idx;
            state <= COMPRESS;
          end else if (s4.is_root) begin
            root  <= s3.payload.parent_idx;
            state <= COMPRESS;
          end else if (s5.is_root) begin
            root  <= s4.payload.parent_idx;
            state <= COMPRESS;
          end else begin
            root  <= s5.payload.parent_idx;
            state <= FINDROOT;  // continue
          end
        end
        COMPRESS: begin
          if (compressing_node == root) begin
            nodes[root].payload.size <= nodes[root].payload.size + depth;
            if (search_from == INDEX_BIT_WIDTH'($unsigned(MAX_NODE_COUNT - 1))) begin
              state <= IDLE;
            end else begin
              logic [INDEX_BIT_WIDTH-1:0] new_node;
              new_node = search_from + INDEX_BIT_WIDTH'(1'b1);
              search_from <= new_node;
              root <= new_node;
              state <= FINDROOT;
            end
          end else begin
            depth <= depth + INDEX_BIT_WIDTH'(1'b1);
            nodes[compressing_node].payload.parent_idx <= root;
            compressing_node <= nodes[compressing_node].payload.parent_idx;
          end
        end
        default: begin
          state <= IDLE;
        end
      endcase
    end
  end
endmodule
