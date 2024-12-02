// dcache name: cashay

`include "verilog/sys_defs.svh"
`include "verilog/memDP.sv"

module dcache (
    input clock,
    input reset,

    input ADDR proc2Dcache_addr,

    input logic     is_store,
    input MEM_SIZE  st_size,
    input DATA      in_data,

    input logic     mshr2cache_wr,
    input MEM_BLOCK mem2Dcache_data,

    // To load unit stage
    output MEM_BLOCK Dcache_data_out, // this is for cache hit on a load inst (miss data will come from mshr)
    output logic     Dcache_valid_out, // When valid is high
    output ADDR      Dcache_addr_out  // addr goes to the load unit for a load inst, and mem for a store inst
);

    // Note: cache tags, not memory tags
    logic [12-`DCACHE_LINE_BITS:0] current_tag,   last_tag;
    logic [`DCACHE_LINE_BITS -1:0] current_index, last_index;
    logic                          got_mem_data;
    MEM_BLOCK                      wr_cache_data;
    MEM_BLOCK                      rd_cache_data;


    // ---- Cache data ---- //

    DCACHE_TAG [`DCACHE_LINES-1:0] dcache_tags;

    memDP #(
        .WIDTH     ($bits(MEM_BLOCK)),
        .DEPTH     (`DCACHE_LINES),
        .READ_PORTS(1),
        .BYPASS_EN (0))
    dcache_mem (
        .clock(clock),
        .reset(reset),
        .re   (1'b1),
        .raddr(current_index),
        .rdata(rd_cache_data),
        .we   (mshr2cache_wr || ((Dcache_valid_out || mshr2cache_wr) && is_store)),
        .waddr(current_index),
        .wdata(wr_cache_data)
    );
    

    // ---- Addresses and final outputs ---- //

    assign {current_tag, current_index} = proc2Dcache_addr[15:3];

    assign Dcache_valid_out =  dcache_tags[current_index].valid &&
                              (dcache_tags[current_index].tags == current_tag);

    always_comb begin
        Dcache_data_out = (mshr2cache_wr) ? mem2Dcache_data : rd_cache_data;
        Dcache_addr_out = {proc2Dcache_addr[31:3], 3'b0};
        if ((Dcache_valid_out || mshr2cache_wr) && is_store) begin
            if (st_size == BYTE) begin
                wr_cache_data.byte_level[proc2Dcache_addr[2:0]] = in_data;
            end
            if (st_size == HALF) begin
                wr_cache_data.half_level[proc2Dcache_addr[2:1]] = in_data;
            end
            if (st_size == WORD) begin
                wr_cache_data.word_level[proc2Dcache_addr[2]] = in_data;
            end
            Dcache_data_out = wr_cache_data;
        end
    end

    // ---- Cache state registers ---- //

    always_ff @(posedge clock) begin
        if (reset) begin
            dcache_tags      <= '0; // Set all cache tags and valid bits to 0
        end else begin
            if (mshr2cache_wr) begin
                dcache_tags[current_index].tags  <= current_tag;
                dcache_tags[current_index].valid <= 1'b1;
            end
        end
    end

endmodule