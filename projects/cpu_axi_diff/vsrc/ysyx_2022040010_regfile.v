//riscv64 gpr


`include "defines.v"
`timescale 1ns / 1ps
//write back
module ysyx_2022040010_regfile (
    input                       clk,
    input                       rst,
    input       [`StallBus]     stall,
    //write port
    input                       we,  //     enable
    input       [`RegAddrBus]   waddr,
    input       [`RegBus]       wdata,

    //read port 1
    input                       re1,
    input       [`RegAddrBus]   raddr1,
    output reg  [`RegBus]       rdata1,  

    //read port 2
    input                       re2,
    input       [`RegAddrBus]   raddr2, //4:0
    output reg  [`RegBus]       rdata2,      //63:0

    output      [63:0]          regs_o [0:31]  // TODO:DIFFTEST
);

    //init number:32 bits:64 gpr
    reg[`RegBus] gpr[0:`RegNum-1];

    //write handler
    always @(posedge clk) begin
        if (rst) begin
            for (int i=0; i<=32; i++) begin
                gpr[i] <= `ZeroWord; 
            end
        end
        else begin
            if (stall[3]) begin
                // keep
            end
            else if ((we == `WriteEnable) && (waddr != `RegNumLog2'h0)) begin
                gpr[waddr] <= wdata;
                // $display("npc-regfile-rd = %x", waddr);
                // $display("npc-regfile-wdata = %x", wdata);
            end
            else ;
        end
    end

    //read1 handler
    always @(*) begin
        if (rst == `RstEnable) begin
            rdata1 = `ZeroWord;
        end
        else if (raddr1 == `RegNumLog2'h0) begin
            rdata1 = `ZeroWord;
        end
        else if ((raddr1 == waddr) && (we == `WriteEnable) && (re1 == `ReadEnable)) begin//correlation resolution with interal of 2 (RAW)
            rdata1 = wdata;
        end
        else if (re1 == `ReadEnable) begin
            rdata1 = gpr[raddr1];
        end
        else begin
            rdata1 = `ZeroWord;
        end
    end

    //read2 handler
    always @(*) begin
        if (rst == `RstEnable) begin
            rdata2 = `ZeroWord;
        end
        else if (raddr2 == `RegNumLog2'h0) begin
            rdata2 = `ZeroWord;
        end
        else if ((raddr2 == waddr) && (we == `WriteEnable) && (re2 == `ReadEnable)) begin
            rdata2 = wdata;
        end
        else if (re2 == `ReadEnable) begin
            rdata2 = gpr[raddr2];
        end
        else begin
            rdata2 = `ZeroWord;
        end
    end

// TODO:DIFFTEST
	genvar i;
	generate
		for (i = 0; i < 32; i = i + 1) begin
			assign regs_o[i] = (we & waddr == i & i != 0) ? wdata : gpr[i];
		end
	endgenerate

endmodule
