
`include "defines.v"
`timescale 1ns / 1ps

module ysyx_2022040010_dcache_tag (
    input                       clk,
    input                       rst,

    input                       flush,
    output                      stallreq,
    input                       cache,

    input                       sram_e,
    input                       sram_we, // 0 load 1 store
    input  [63:0]               sram_addr,

    input                       refresh,
    output                      miss,
    output                      dirty,
    output [63:0]               dirty_addr,

    output [`HIT_WIDTH-1:0]     hit,

    output                      lru 

);

    // ------------- get tag index offset ----------------
    wire [`TAG_WIDTH-1:0] tag;            // 54
    wire [`INDEX_WIDTH-1:0] index;         // 6 64lines 
    wire [`OFFSET_WIDTH-1:0] offset;        // 4 2^4=16 8*16 = 128bits

    assign { 
        tag, 
        index, 
        offset 
    } = sram_addr;
    wire [59:0] aligned_addr = {tag, index};


    // -------------- updata lru array ------------
    wire hit_way0 = cache & sram_e & ({1'b1, tag} == tag_way0[index][CACHE_BIT:0]);
    wire hit_way1 = cache & sram_e & ({1'b1, tag} == tag_way1[index][CACHE_BIT:0]);
    reg [`INDEX_LENGTH-1:0] lru_r;

    always @(posedge clk) begin
        if (rst)                        lru_r <= `INDEX_LENGTH'b0;
        else if (hit_way0 & ~hit_way1)  lru_r[index] <= 1'b1;
        else if (~hit_way0 & hit_way1)  lru_r[index] <= 1'b0;
        else if (refresh)               lru_r[index] <= ~lru_r[index];  
    end


    // ------------- updata tag line -------------
    parameter TAG_BIT   = 53;
    parameter CACHE_BIT = 54;
    parameter DIRTY_BIT = 55;

    reg [`DTAG_WIDTH-1:0] tag_way0 [`INDEX_LENGTH-1:0];   // 55:0    63:0
    reg [`DTAG_WIDTH-1:0] tag_way1 [`INDEX_LENGTH-1:0];   // dirty + cache + tag  55 54 53

    wire load_sign  = sram_e & ~sram_we; 
    wire store_sign = sram_e & sram_we; 

    always @(posedge clk) begin
        if(rst) begin
            for (int i = 0; i<64; i++) begin 
                tag_way0[i] <= `DTAG_WIDTH'b0; 
            end    
        end
        else if (refresh & ~lru_r[index]) begin  // lru cache 0
            tag_way0[index] <= {1'b0, cache, tag};
        end
        else if (store_sign & hit_way0 & lru_r[index]) begin
            tag_way0[index][DIRTY_BIT] <= store_sign;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i<64; i++) begin
                tag_way1[i] <= `DTAG_WIDTH'b0;
            end    
        end
        else if (refresh & lru_r[index]) begin
            tag_way1[index] <= {1'b0, cache, tag};
        end
        else if (store_sign & hit_way1 & ~lru_r[index]) begin
            tag_way1[index][DIRTY_BIT] <= store_sign;
        end
    end

    // ---------------- prepare for output ---------------
    wire write_back_way0 = cache & sram_e & miss & tag_way0[index][DIRTY_BIT]; // dirty0
    wire write_back_way1 = cache & sram_e & miss & tag_way1[index][DIRTY_BIT]; // dirty1
    wire [63:0] dirty_way1_addr = {tag_way1[index][TAG_BIT:0], index, 4'b0};
    wire [63:0] dirty_way0_addr = {tag_way0[index][TAG_BIT:0], index, 4'b0};


    // --------------------- output -----------------------
    assign lru = lru_r[index];
    assign hit = {hit_way1, hit_way0};
    assign miss = cache & sram_e & ~(hit_way0|hit_way1);
    assign dirty = write_back_way0 | write_back_way1;
    assign dirty_addr = dirty ? lru ? dirty_way0_addr : dirty_way1_addr : 64'b0;
    assign stallreq = miss;


endmodule





