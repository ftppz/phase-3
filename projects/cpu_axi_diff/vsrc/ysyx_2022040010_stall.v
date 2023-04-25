
`include "defines.v"
`timescale 1ns / 1ps
module ysyx_2022040010_stall(
    input               rst,
    input               stallreq_for_ex,
    input               stallreq_for_bru,
    input               stallreq_for_load,
    input               stallreq_for_cache, 

    output [`StallBus]  stall
);  
    // always @ (*) begin
    //     if (rst) begin
    //         stall = `Stall_WD'b0;
    //     end
    //     else if (stallreq_for_bru) begin //flush
    //         stall = `Stall_WD'b100100;
    //     end
    //     else if (stallreq_for_ex) begin
    //         stall = `Stall_WD'b100010;
    //     end
    //     else if (stallreq_for_load) begin
    //         stall = `Stall_WD'b100001;
    //     end
    //     else if (stallreq_for_cache) begin
    //         stall = `Stall_WD'b101000;
    //     end
    //     else if (rw_over) begin
    //         stall = `Stall_WD'b0;
    //     end
    //     else begin
    //         stall = `Stall_WD'b0; 
    //     end
    // end

    assign stall[0] = stallreq_for_load;
    assign stall[1] = stallreq_for_ex;
    assign stall[2] = stallreq_for_bru;
    assign stall[3] = stallreq_for_cache;
    assign stall[4] = 1'b0;
    assign stall[5] = stallreq_for_load | stallreq_for_ex | stallreq_for_bru | stallreq_for_cache; 



endmodule
