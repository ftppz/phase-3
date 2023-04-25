//decode func7 and opcode

`include "defines.v"
`timescale 1ns / 1ps

module ysyx_2022040010_decoder_7_128 (
    input  [  6:0] in,
    output [127:0] out
);

    genvar i;
    generate
        for (i = 0; i < 128; i = i + 1)
        begin: decoder7
            assign out[i] = (in == i);
        end
    endgenerate

endmodule
