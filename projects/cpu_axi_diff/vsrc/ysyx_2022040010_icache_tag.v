
`include "defines.v"
`timescale 1ns / 1ps

module ysyx_2022040010_icache_tag (
    input                       clk,
    input                       rst,
    input                       flush,
    
    output                      stallreq,
    input                       cache,

    input                       sram_e,
    input  [63:0]               sram_addr,

    input                       refresh,   //refresh after miss 
    output                      miss,

    // 2 icachedata
    output  [`HIT_WIDTH-1:0]    hit,
    output                      lru
);

    // ----------- get tag index offset ----------------
    wire [`TAG_WIDTH-1:0] tag;  // 55
    wire [`INDEX_WIDTH-1:0] index;           // 6 64lines 
    wire [`OFFSET_WIDTH-1:0] offset;          // 4 2^4=16 8*16 = 128bits

    // 64bits
    assign {
        tag,
        index,
        offset
    } = sram_addr;


    // ------------ updata lru -------------
    reg [`INDEX_LENGTH-1:0] lru_r; //least rencently used

    always @(posedge clk) begin
        if (rst) begin
            lru_r <= `INDEX_LENGTH'b0;
        end
        else if (hit_way0 & ~hit_way1) begin 
            lru_r[index] <= 1'b1;              //1 lru index way1 
        end
        else if (~hit_way0 & hit_way1) begin
            lru_r[index] <= 1'b0;              //0 lru index way0 
        end
        else if (refresh) begin
            lru_r[index] <= ~lru_r[index];   
        end
    end


    // -------------- updata cache tag line -------------
    // TODO: replace width sram S011HD1P_X32Y2D128_BW
    reg [`ITAG_WIDTH-1:0] tag_way0 [`INDEX_LENGTH-1:0];  //cache tag      55 * 64  
    reg [`ITAG_WIDTH-1:0] tag_way1 [`INDEX_LENGTH-1:0];

    always @(posedge clk) begin
        if(rst) begin
            for (int i = 0; i < 64; i++) begin
                tag_way0[i] <= `ITAG_WIDTH'b0;
            end
        end
        else if (refresh & ~lru_r[index]) begin  // lru cache 0
            tag_way0[index] <= {cache, tag};  
        end
    end

    always @(posedge clk) begin
        if(rst) begin
            for (int i = 0; i < 64; i++) begin
                tag_way1[i] <= `ITAG_WIDTH'b0;
            end
        end
        else if (refresh & lru_r[index]) begin    // only one line is replaced after a miss
            tag_way1[index] <= {cache, tag};   // replacement strategy for write back
        end
    end


    // --------------- ouput ------------------
    wire hit_way0 = cache & sram_e & ({1'b1, tag} == tag_way0[index]);
    wire hit_way1 = cache & sram_e & ({1'b1, tag} == tag_way1[index]);
    wire [1:0] hit_temp = {hit_way1, hit_way0};
    
    assign hit      = hit_temp;
    assign lru      = lru_r[index];
    assign miss     = cache & sram_e & ~(hit_way0|hit_way1) & ~flush;
    assign stallreq = miss; //stall whole fsl
    
endmodule



