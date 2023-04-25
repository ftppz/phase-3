`include "defines.v"
`timescale 1ns / 1ps

module ysyx_2022040010_e2m (
    input                       clk,
    input                       rst,

    input  [`StallBus]          stall,

    // from ex
    input  [`EX_TO_MEM_BUS]     ex_to_mem_bus_i,

    // to mem
    output [`EX_TO_MEM_BUS]     ex_to_mem_bus_o,

    // to id
    output [`BP_TO_RF_BUS]      e2m_to_rf_bus,

    // to stall
    output                      stallreq_for_load,

    // to id
    output [ 6:0]               e2m_to_id_for_stallload

);

    reg e2m_cnt;
    always @(posedge clk) begin
        if (rst) e2m_cnt <= 1'b0;
        else if (stall[0] & ~e2m_cnt) e2m_cnt <= 1'b1;
        else if (stall[0] & e2m_cnt) e2m_cnt <= 1'b0;
        else e2m_cnt <= 1'b0;
    end
    // assign stallreq_for_load = e2m_cnt;
    assign stallreq_for_load = 1'b0;


    // -------------- get data ----------------
    reg [`EX_TO_MEM_BUS] buf_ex_to_mem_bus;

    always @(posedge clk) begin
        if (rst) buf_ex_to_mem_bus  <= `EX_TO_MEM_WD'b0;
        else if (stall[3]) begin end
        else buf_ex_to_mem_bus <= ex_to_mem_bus_i;
    end


    // ---------------- prepara for output ---------------
    wire [ 6: 0] load_op;
    wire [63: 0] e2m_pc;

    wire dram_e;            // <--
    wire dram_we;           // <--

    wire [ 7: 0] ex_dsram_sel;
    wire sel_rf_sel;

    wire rf_we;              // <--
    wire [ 4: 0] rf_waddr;   // <--
    wire [63: 0] ex_result;  // <--

    wire sel_rf_res;    
    wire [1 : 0] sp_bus;
    wire op_sp;
    wire [63: 0] next_pc;
    wire [31: 0] inst;

    assign  {
        sp_bus,      // 250:249
        op_sp,       // 248 
        load_op,     // 247:241
        next_pc,     // 240:177
        e2m_pc,      // 176:113
        dram_e,      // 112
        dram_we,     // 111
        ex_dsram_sel,// 110:103
        sel_rf_res,  // 102
        rf_we,       // 101    <--
        rf_waddr,    // 100:96 <--
        ex_result,   // 95:32  <--
        inst         // 31:0
    }   = buf_ex_to_mem_bus;

    wire rf_we_o = (rf_waddr == 5'b0) ? 1'b0 : rf_we;
    wire [ 4:0] rf_waddr_o = rf_waddr;
    wire [63:0] rf_wdata_o = ex_result;


    // --------------- output ---------------
    assign ex_to_mem_bus_o = buf_ex_to_mem_bus;
    assign e2m_to_rf_bus = {rf_we_o, rf_waddr_o, rf_wdata_o};
    assign e2m_to_id_for_stallload = {rf_waddr, dram_we, dram_e};

endmodule
