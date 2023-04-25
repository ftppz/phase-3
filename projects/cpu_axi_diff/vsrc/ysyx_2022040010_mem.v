
/*
    memu
    read dsram(load instruction)
    dsram need to update data before memu
    so, exu nee to output dsram(store instruction)
*/
`include "defines.v"
`timescale 1ns / 1ps

module ysyx_2022040010_mem (
    input                   clk,
    input                   rst,

    // from stall
    input  [`StallBus]      stall,

    // from dcache data
    input  [63: 0]          dsram_rdata,

    // from exe
    input  [`EX_TO_MEM_BUS] ex_to_mem_bus, 

    // to wb
    output [`MEM_TO_WB_BUS] mem_to_wb_bus,

    // to id regfile
    output [`BP_TO_RF_BUS]  mem_to_rf_bus

);

    reg mem_cnt;
    reg [63:0] mem_stall_rdata;


    always @(posedge clk) begin
        if (rst) begin
            mem_cnt <= 1'b0;
        end
        else if (stall[3] & ~mem_cnt) mem_cnt <= 1'b1;
        else if (stall[3] & mem_cnt)  begin end
        else if (~stall[3] & mem_cnt) mem_cnt <= 1'b0;
        else                          mem_cnt <= 1'b0;
    end


    reg [`EX_TO_MEM_BUS] ex_to_mem_bus_r;
    reg [63:0] dsram_rdata_r;

    always @(posedge clk) begin
        if (rst) begin
            ex_to_mem_bus_r     <= `EX_TO_MEM_WD'b0;
            dsram_rdata_r       <= 64'b0;
        end
        else if (stall[3] & ~mem_cnt) begin
            mem_stall_rdata <= dsram_rdata;
        end
        else if (stall[3] & mem_cnt) begin
            //keep
        end
        else if (~stall[3] & mem_cnt) begin
            dsram_rdata_r <= mem_stall_rdata;
            ex_to_mem_bus_r <= ex_to_mem_bus;
        end
        else begin
            dsram_rdata_r       <= dsram_rdata;
            ex_to_mem_bus_r     <= ex_to_mem_bus;
        end
    end

    wire [ 6: 0] load_op;
    wire [63: 0] mem_pc;
    wire dram_e;
    wire dram_we;
    wire [ 7: 0] ex_dsram_sel;
    wire sel_rf_sel;
    wire rf_we;
    wire [ 4: 0] rf_waddr;
    wire [63: 0] ex_result;
// 0 regfiel res from alu_res ; 1 form ld_res
    wire sel_rf_res;    
    wire [1 : 0] sp_bus;
    wire op_sp;
    wire [63: 0] next_pc;
    wire [31: 0] inst;

    assign  {
        sp_bus,     //2
        op_sp,      //1
        load_op,     //143:137
        next_pc,
        mem_pc,      //136:73 
        dram_e,     //    72
        dram_we,    //    71 
        ex_dsram_sel,
        //0 form alu_res, 1 from ld_res
        sel_rf_res, //    66
        rf_we,      //    65
        rf_waddr,   // 68:64
        ex_result,   // 63: 0
        inst
    }   = ex_to_mem_bus_r;

// load part
    wire inst_lb,   inst_lh,    inst_lw,    inst_ld;    
    wire inst_lbu,  inst_lhu,   inst_lwu;

    assign {    inst_lb,    inst_lh,    inst_lw,        inst_ld,
                inst_lbu,   inst_lhu,   inst_lwu
    }   =   load_op;

    wire [ 7: 0] b_data;
    wire [15: 0] h_data;
    wire [31: 0] w_data;
    wire [63: 0] d_data;
    wire [63: 0] mem_result;
    wire [63: 0] rf_wdata;

    assign b_data = ex_dsram_sel[0] ? dsram_rdata_r[ 7: 0] : 
                    ex_dsram_sel[1] ? dsram_rdata_r[15: 8] :
                    ex_dsram_sel[2] ? dsram_rdata_r[23:16] :
                    ex_dsram_sel[3] ? dsram_rdata_r[31:24] :
                    ex_dsram_sel[4] ? dsram_rdata_r[39:32] :
                    ex_dsram_sel[5] ? dsram_rdata_r[47:40] :
                    ex_dsram_sel[6] ? dsram_rdata_r[55:48] :
                    ex_dsram_sel[7] ? dsram_rdata_r[63:56] : 8'b0;

    assign h_data = ex_dsram_sel[0] ? dsram_rdata_r[15: 0] :
                    ex_dsram_sel[2] ? dsram_rdata_r[31:16] :
                    ex_dsram_sel[4] ? dsram_rdata_r[47:32] :
                    ex_dsram_sel[6] ? dsram_rdata_r[63:48] : 16'b0;

    assign w_data = ex_dsram_sel[0] ? dsram_rdata_r[31: 0] :
                    ex_dsram_sel[4] ? dsram_rdata_r[63:32] : 32'b0;

    assign d_data = ex_dsram_sel[0] ? dsram_rdata_r : 64'b0;

    assign mem_result = inst_lb     ?   { {56{b_data[7]}} , b_data} :
                        inst_lbu    ?   { {56'b0},b_data } :
                        inst_lh     ?   { {48{h_data[15]}}, h_data} :
                        inst_lhu    ?   { {48'b0},h_data } :
                        inst_lw     ?   { {32{w_data[31]}}, w_data} :
                        inst_lwu    ?   { {32'b0},w_data } :
                        inst_ld     ?   d_data  : 64'b0;

    assign rf_wdata = (sel_rf_res & dram_e) ? mem_result : ex_result;

    assign mem_to_wb_bus = {
        sp_bus,     //          2
        op_sp,      //          1
        next_pc,    //          64
        mem_pc,     //133:70    64
        rf_we,      //    69    1
        rf_waddr,   // 68:64    5
        rf_wdata,    // 63: 0   64
        inst         //         32
    };

    wire rf_we_o;
    assign rf_we_o = (rf_waddr == 5'b0) ? 1'b0 : rf_we;

    assign mem_to_rf_bus = {
        rf_we_o,
        rf_waddr,
        rf_wdata
    };


    
endmodule




