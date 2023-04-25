
`include "defines.v"
`timescale 1ns / 1ps
module ysyx_2022040010_f2d (
    input                       clk,
    input                       rst,
    input  [`StallBus]          stall,
    input  [`IF_TO_ID_BUS]      if_to_id_bus_i,

    output [`IF_TO_ID_BUS]      if_to_id_bus_o

);

    reg [`IF_TO_ID_BUS]         buf_if_to_id_bus;

    always @(posedge clk) begin
        if (rst) begin
            buf_if_to_id_bus  <= `IF_TO_ID_WD'b0;
        end
        else begin
            if (stall[2]) begin
                buf_if_to_id_bus <= `IF_TO_ID_WD'b0;
            end
            else if (stall[3] | stall[0] | stall[1]) begin
                // keep
            end
            else begin
                buf_if_to_id_bus <= if_to_id_bus_i;
            end
        end
    end

    // --------------- output ---------------
    assign if_to_id_bus_o = buf_if_to_id_bus;
    
endmodule