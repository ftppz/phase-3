
`include "defines.v"
`timescale 1ns / 1ps

module ysyx_2022040010_arbit (
    input           clk,
    input           rst,

    // icache interface  // miss  
    input                               icache_re_i,    
    input   [63:0]                      icache_addr_i,
    output  [`AXI_RW_DATA_WIDTH-1:0]    icache_data_o,  // send to icache
    output                              icache_refresh_o,

    // dcache interface   // miss & dirty
    input                               dcache_re_i,
    input                               dcache_we_i,
    input   [ 7:0]                      dcache_mask_i, // from where
    input   [63:0]                      dcache_addr_i,
    input   [`AXI_RW_DATA_WIDTH-1:0]    dcache_olddata_i,  // send to mem
    output  [`AXI_RW_DATA_WIDTH-1:0]    dcache_newdata_o,  // send to dcache
    output                              dcache_refresh_o,
    output                              dcache_w_over_o,

    //uncache interface
    input                               uncache_re_i,
    input                               uncache_we_i,
    input   [ 7:0]                      uncache_mask_i,
    input   [63:0]                      uncache_addr_i,
    output  [`AXI_RW_DATA_WIDTH-1:0]    uncache_rdata_o,  // device read
    input   [`AXI_RW_DATA_WIDTH-1:0]    uncache_wdata_i, // device write
    output                              uncache_refresh_o,

    input   [ 1:0]                      rw_size_i,

    //axi-rw
    output                              rw_valid_o,
    input                               rw_ready_i, // restart and refresh
    input   [1:0]                       rw_r_w_i,   // 10 w_done 01 r_done
    output                              rw_req_o,
    input   [`AXI_RW_DATA_WIDTH-1:0]    data_read_i,
    output  [`AXI_RW_DATA_WIDTH-1:0]    data_write_o,
    output  [63:0]                      rw_addr_o,
    output  [1:0]                       rw_size_o,
    // input  wire [1:0]       rw_resp_i,
    output  [3:0]                       rw_id_o, // icache / dcache / uncache
    input   [3:0]                       rw_id_i,
    output  [7:0]                       w_mask_o

);

    assign rw_valid_o       =   icache_re_i | dcache_re_i | dcache_we_i | uncache_re_i | uncache_we_i;

    wire   rw_r             =   icache_re_i | dcache_re_i | uncache_re_i;
    wire   rw_w             =   dcache_we_i | uncache_we_i;
    assign rw_req_o         =   rw_r ? 1'b0
                            :   rw_w ? 1'b1 : 1'b0;

    assign rw_id_o          =   icache_re_i                 ? 4'b0001
                            :   dcache_re_i  | dcache_we_i  ? 4'b0010
                            :   uncache_re_i | uncache_we_i ? 4'b0100 
                            :   4'b0000; 
    
    assign rw_addr_o        =   icache_re_i  ? icache_addr_i 
                            :   dcache_re_i  | dcache_we_i  ? dcache_addr_i
                            :   uncache_re_i | uncache_we_i ? uncache_addr_i
                            :   64'b0;

    assign data_write_o     =   dcache_we_i ? dcache_olddata_i : 128'b0 ;

    assign rw_size_o        =   icache_re_i | dcache_re_i ? `SIZE_D 
                            :   dcache_we_i ?  `SIZE_D 
                            :   2'b0; 
    assign w_mask_o         =   dcache_we_i ? 8'hff
                            :   uncache_we_i? uncache_mask_i
                            :   8'b0;

    assign icache_data_o    =   ( rw_id_i[0] & rw_ready_i) ? data_read_i : 128'b0; 
    assign dcache_newdata_o =   ( rw_id_i[1] & rw_ready_i) ? data_read_i : 128'b0;
    assign uncache_rdata_o  =   ( rw_id_i[2] & rw_ready_i) ? data_read_i : 128'b0;
    
    assign icache_refresh_o  =  ( icache_re_i & rw_id_i[0]) ? ( rw_ready_i & rw_r_w_i[0]) : 1'b0; 
    assign dcache_refresh_o  =  ( dcache_re_i & rw_id_i[1]) ? ( rw_ready_i & rw_r_w_i[0]) : 1'b0;
    assign dcache_w_over_o   =  ( dcache_we_i & rw_id_i[1]) ? ( rw_ready_i & rw_r_w_i[1]) : 1'b0;
    assign uncache_refresh_o =   rw_id_i[2] ? rw_ready_i : 1'b0;



endmodule



