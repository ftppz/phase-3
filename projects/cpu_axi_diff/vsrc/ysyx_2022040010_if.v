
`include "defines.v"
`timescale 1ns / 1ps
module ysyx_2022040010_if (
    input                   clk,
    input                   rst,
    input  [`StallBus]      stall,

    input  [`BR_TO_IF_BUS]  br_bus,

    output [`IF_TO_ID_BUS]  if_to_id_bus,

    output                  isram_e,
    output [63:0]           isram_addr
);

    // -------------- get branch --------------
    wire        if_br_e;
    wire [63:0] if_br_addr;

    assign {    if_br_e,
                if_br_addr
    }   =   br_bus;



    // -------------- updata pc ----------------
    reg [63: 0] if_pc_r;
    reg         if_ce_r;

    always @( posedge clk ) begin
        if ( rst ) begin
            if_pc_r <= `PC_START;
            if_ce_r <= 1'b0;
        end
        else if (stall[2]) begin
            if_pc_r <= if_next_pc;
            if_ce_r <= 1'b1;
        end
        else if (stall[3] | stall[0] | stall[1]) begin
            // keep
        end
        else begin
            if_pc_r <= if_next_pc;
            if_ce_r <= 1'b1;
        end
    end


    // -------------- if to id -----------------
    wire [63:0] if_next_pc = if_br_e ? if_br_addr : if_pc_r + 64'h4;
    wire [63:0] if_pc = (if_pc_r == `PC_START) ? 64'b0 : if_pc_r;
    wire if_ce = if_ce_r;

    assign if_to_id_bus = {
        if_ce,    //   64
        if_pc,     //63: 0
        if_next_pc
    };


    // ------------ send to icache ----------------
    assign isram_e  = if_ce;
    assign isram_addr  = if_pc;


endmodule




