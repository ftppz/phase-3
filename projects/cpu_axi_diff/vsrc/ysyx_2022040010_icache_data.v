
`include "defines.v"
`timescale 1ns / 1ps

module ysyx_2022040010_icache_data (
    input                           clk, 
    input                           rst,

    input  [`HIT_WIDTH-1:0]         hit,    //way sel
    input                           lru,  //least rencently used
    input                           cache,

    //isram_interface
    input                           sram_e,
    input  [63:0]                   sram_addr,
    output [31:0]                   sram_rdata_o,

    //axi
    input                           refresh,
    input  [`AXI_RW_DATA_WIDTH-1:0] cacheline_new
);
//128*64

    // ----------- get tag index offset ----------------
    wire [`TAG_WIDTH-1:0] tag;   // 64-6-4=54
    wire [`INDEX_WIDTH-1:0] index;            // 6  cache index 64 lines
    wire [`OFFSET_WIDTH-1:0] offset;           // 4  cache lines 8bytes     0->3'b000 / 4->3'b100


    assign {
        tag,
        index,
        offset
    } = sram_addr;


    // ------- icache bank read ----------------
    parameter Bits = 128;
	parameter Add_Width = 6;
	parameter Wen_Width = 128;
    parameter No_Cache_Mask = 128'h0;

    wire [Bits-1:0]         Q0;
    wire                    CLK0 = clk;
    wire                    CEN0 = cache&refresh  | cache&sram_e&hit[0];
    wire                    WEN0 = refresh?~lru?1'b1:1'b0:1'b0;
    wire [Wen_Width-1:0]    BWEN0 = No_Cache_Mask;
    wire [Add_Width-1:0]    A0 = index;
    wire [Bits-1:0]         D0 = refresh ? cacheline_new : 128'b0;

    wire [Bits-1:0]         Q1;
    wire                    CLK1 = clk;
    wire                    CEN1 = cache&refresh | cache&sram_e&hit[1];
    wire                    WEN1 = refresh?lru?1'b1:1'b0:1'b0;
    wire [Wen_Width-1:0]    BWEN1 = No_Cache_Mask;
    wire [Add_Width-1:0]    A1 = index;
    wire [Bits-1:0]         D1 = refresh ? cacheline_new : 128'b0;


    S011HD1P_X32Y2D128_BW icachebank_way0(
        .Q      (Q0),     // out data
        .CLK    (CLK0),
        .CEN    (~CEN0),  // en
        .WEN    (~WEN0),  // wen
        .BWEN   (BWEN0),  // mask
        .A      (A0),     //index
        .D      (D0)      // in data
    );

    S011HD1P_X32Y2D128_BW icachebank_way1(
        .Q      (Q1), 
        .CLK    (CLK1), 
        .CEN    (~CEN1), 
        .WEN    (~WEN1),
        .BWEN   (BWEN1), 
        .A      (A1), 
        .D      (D1)
    );
  

    // ---------------- prepara for output ---------------
    reg [1:0] hit_r;
    reg [`OFFSET_WIDTH-1:0] offset_r;

    always @(posedge clk) begin
        if (rst) begin
            hit_r <= 2'b0;
            offset_r <= `OFFSET_WIDTH'b0;
        end
        else begin
           hit_r <= hit; 
           offset_r <= offset;
        end
    end


    wire [31:0] icache_inst_way0    = (offset_r==`OFFSET_WIDTH'h0) ? Q0[31:0]   // 0
                                    : (offset_r==`OFFSET_WIDTH'h4) ? Q0[63:32]  // 4
                                    : (offset_r==`OFFSET_WIDTH'h8) ? Q0[95:64]  // 8
                                    : (offset_r==`OFFSET_WIDTH'hc) ? Q0[127:96] // c 12
                                    : 32'b0;
    wire [31:0] icache_inst_way1    = (offset_r==`OFFSET_WIDTH'h0) ? Q1[31:0] 
                                    : (offset_r==`OFFSET_WIDTH'h4) ? Q1[63:32]
                                    : (offset_r==`OFFSET_WIDTH'h8) ? Q1[95:64]
                                    : (offset_r==`OFFSET_WIDTH'hc) ? Q1[127:96]
                                    : 32'b0;
        

    // --------------- output ----------------------
    assign sram_rdata_o =   hit_r[0] ? icache_inst_way0
                        :   hit_r[1] ? icache_inst_way1 : 32'b0;


endmodule
