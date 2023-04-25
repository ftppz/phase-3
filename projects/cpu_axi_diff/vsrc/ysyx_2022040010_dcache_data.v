
`include "defines.v"
`timescale 1ns / 1ps
module ysyx_2022040010_dcache_data (
    input                           clk, 
    input                           rst,

    input                           write_back,
    input  [`HIT_WIDTH-1:0]         hit,
    input                           lru,  //least rencently used

    // mmu
    input                           cache,

    //sram_interface
    input                           sram_e,
    input                           sram_we,
    input  [ 7:0]                   sram_sel,
    input  [63:0]                   sram_addr,
    input  [63:0]                   sram_wdata,
    output [63:0]                   sram_rdata,

    //axi
    input                           refresh,
    input  [`AXI_RW_DATA_WIDTH-1:0] cacheline_new,
    output [`AXI_RW_DATA_WIDTH-1:0] cacheline_old
);

    // ----------- get tag index offset ----------------
    wire [`TAG_WIDTH-1:0] tag;              // 54  
    wire [`INDEX_WIDTH-1:0] index;           // 6   cache index 64 lines
    wire [`OFFSET_WIDTH-1:0] offset;          // 4   128bits
    
    assign { 
        tag, 
        index, 
        offset 
    } = sram_addr;


    // -------------------- dcache mask --------------------
    parameter Bits = 128;
	parameter Add_Width = 6;
	parameter Wen_Width = 128;

    wire [63:0] half_mask = {{8{sram_sel[7]}}, {8{sram_sel[6]}}, {8{sram_sel[5]}}, {8{sram_sel[4]}}, {8{sram_sel[3]}},
                             {8{sram_sel[2]}}, {8{sram_sel[1]}}, {8{sram_sel[0]}}};
    wire low = offset<8;
    wire [63:0] low_mask = low ? half_mask : 64'b0;
    wire [63:0] high_mask = ~low ? half_mask : 64'b0; 
    wire [Bits-1:0] mask = refresh ? 128'b0 : ~{high_mask, low_mask};
    wire [Bits-1:0] sram_wdata_new = low ? {64'b0, sram_wdata} : {sram_wdata, 64'b0};

    // ------------- dcache bank read or write ------------------
    wire [Bits-1:0]         Q0;
    wire                    CLK0 = clk;
    wire                    CEN0 = cache&refresh | cache&sram_e&hit[0] | write_back ;
    wire                    WEN0 = refresh ? ~lru : (sram_we&hit[0]);
    wire [Wen_Width-1:0]    BWEN0 = mask;
    wire [Add_Width-1:0]    A0 = index;
    wire [Bits-1:0]         D0 = refresh ? cacheline_new : sram_wdata_new;

    wire [Bits-1:0]         Q1;
    wire                    CLK1 = clk;
    wire                    CEN1 = cache&refresh | cache&sram_e&hit[1] | write_back;
    wire                    WEN1 = refresh ? lru : (sram_we&hit[1]);
    wire [Wen_Width-1:0]    BWEN1 = mask;
    wire [Add_Width-1:0]    A1 = index;
    wire [Bits-1:0]         D1 = refresh ? cacheline_new : sram_wdata_new;


    S011HD1P_X32Y2D128_BW dcache_data_way0(
        .Q      (Q0),
        .CLK    (CLK0),
        .CEN    (~CEN0),
        .WEN    (~WEN0),
        .BWEN   (BWEN0),
        .A      (A0),
        .D      (D0)
    );

    S011HD1P_X32Y2D128_BW dcache_data_way1(
        .Q      (Q1), // read output data 128
        .CLK    (CLK1), // clock
        .CEN    (~CEN1), // en
        .WEN    (~WEN1), // we
        .BWEN   (BWEN1), // wmask mask
        .A      (A1), // index
        .D      (D1)  // write input data 128
    );

    // ---------------- prepara for output ---------------

    reg low_r, write_back_r, lru_r;
    reg [1:0] hit_r;

    always @(posedge clk) begin
        if (rst) begin
            low_r <= 1'b0;
            hit_r <= 2'b0;
            write_back_r <= 1'b0;
            lru_r <= 1'b0;
        end
        else begin
            low_r <= low;
            hit_r <= hit;
            write_back_r <= write_back;
            lru_r <= lru;
        end
    end

    wire [63:0] sram_rdata_way0 = low_r ? Q0[63:0] : Q0[127:64];
    wire [63:0] sram_rdata_way1 = low_r ? Q1[63:0] : Q1[127:64];


    // ------------------ output --------------------
    assign sram_rdata = hit_r[0] ? sram_rdata_way0 : 
                        hit_r[1] ? sram_rdata_way1 : 64'b0;
    assign cacheline_old = write_back_r ? lru_r ? Q0 : Q1 : 128'b0;

 
endmodule



