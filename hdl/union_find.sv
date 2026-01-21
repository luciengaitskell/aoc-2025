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

  typedef enum logic [2:0] {
    READIN,
    FINDROOT_V,
    COMPRESS_V,
    FINDROOT_U,
    COMPRESS_U,
    MERGE
  } state_t;
  state_t state;
  assign in_ready = (state == READIN);

  always_comb begin
    out_valid = state == READIN;
    out_is_root = nodes[out_index].is_root;
    out_size    = nodes[out_index].payload.size;
  end

  logic [INDEX_BIT_WIDTH-1:0] compress_from_v;
  logic [INDEX_BIT_WIDTH-1:0] compress_from_u;
  logic [INDEX_BIT_WIDTH-1:0] root_v;
  logic [INDEX_BIT_WIDTH-1:0] root_u;


  function automatic logic [INDEX_BIT_WIDTH-1:0] findNodeRoot(
      logic [INDEX_BIT_WIDTH-1:0] root, state_t current_state, state_t next_state);
    uf_node_t s0, s1, s2, s3, s4, s5;

    s0 = nodes[root];
    s1 = nodes[s0.payload.parent_idx];
    s2 = nodes[s1.payload.parent_idx];
    s3 = nodes[s2.payload.parent_idx];
    s4 = nodes[s3.payload.parent_idx];
    s5 = nodes[s4.payload.parent_idx];

    if (s0.is_root) begin
      state <= next_state;
      return root;
      // hypothetically could skip next_state, as it will do nothing
    end else if (s1.is_root) begin
      state <= next_state;
      return s0.payload.parent_idx;
    end else if (s2.is_root) begin
      state <= next_state;
      return s1.payload.parent_idx;
    end else if (s3.is_root) begin
      state <= next_state;
      return s2.payload.parent_idx;
    end else if (s4.is_root) begin
      state <= next_state;
      return s3.payload.parent_idx;
    end else if (s5.is_root) begin
      state <= next_state;
      return s4.payload.parent_idx;
    end else begin
      state <= current_state;  // continue
      return s5.payload.parent_idx;
    end
  endfunction

  always_ff @(posedge clk) begin
    if (rst) begin
      state <= READIN;
      for (int i = 0; i < MAX_NODE_COUNT; i++) begin
        nodes[i] <= '{is_root: 1'b1, payload: INDEX_BIT_WIDTH'(1'b1)};
      end
    end else begin
      case (state)
        READIN: begin
          if (in_valid) begin
            state <= FINDROOT_V;
            root_v <= in_metadata.v;
            compress_from_v <= in_metadata.v;
            root_u <= in_metadata.u;
            compress_from_u <= in_metadata.u;
          end
        end
        FINDROOT_V: begin
          root_v <= findNodeRoot(root_v, FINDROOT_V, COMPRESS_V);
        end
        COMPRESS_V, COMPRESS_U: begin
          logic [INDEX_BIT_WIDTH-1:0] compress_from;
          logic [INDEX_BIT_WIDTH-1:0] next_compress_from;
          logic [INDEX_BIT_WIDTH-1:0] root;
          if (state == COMPRESS_V) begin
            compress_from = compress_from_v;
            root = root_v;
          end else begin
            compress_from = compress_from_u;
            root = root_u;
          end

          if (compress_from == root) begin
            if (state == COMPRESS_V) begin
              state <= FINDROOT_U;
            end else begin
              state <= MERGE;
            end
          end else begin
            nodes[compress_from].payload.parent_idx <= root;
            next_compress_from = nodes[compress_from].payload.parent_idx;
            if (state == COMPRESS_V) begin
              compress_from_v <= next_compress_from;
            end else begin
              compress_from_u <= next_compress_from;
            end
          end
        end
        FINDROOT_U: begin
          root_u <= findNodeRoot(root_u, FINDROOT_U, MERGE);
        end
        MERGE: begin
          if (root_u != root_v) begin
            // merge smaller tree into larger tree
            if (nodes[root_u].payload.size < nodes[root_v].payload.size) begin
              nodes[root_u].is_root <= 1'b0;
              nodes[root_u].payload.parent_idx <= root_v;
              nodes[root_v].payload.size <= nodes[root_v].payload.size + nodes[root_u].payload.size;
            end else begin
              nodes[root_v].is_root <= 1'b0;
              nodes[root_v].payload.parent_idx <= root_u;
              nodes[root_u].payload.size <= nodes[root_u].payload.size + nodes[root_v].payload.size;
            end
          end
          state <= READIN;
        end
        default: begin
          state <= READIN;
        end
      endcase
    end
  end
endmodule
