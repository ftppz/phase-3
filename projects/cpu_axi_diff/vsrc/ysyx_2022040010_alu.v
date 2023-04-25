

//TODO: don't needto consider the case of unsigned
`include "defines.v"
`timescale 1ns / 1ps
module ysyx_2022040010_alu (
    input  [`AluOpBus]      alu_op, //TODO:  

    // input wire alu_signed;
    input  [63:0]           alu_src1,
    input  [63:0]           alu_src2,
//    output reg [63:0] mem_addr, //reduce delay expenses
    input                   alu_32,
    output [63:0]           alu_result,
    output                  alu_over
);

    wire op_add;
    wire op_sub;
    wire op_slt;
    wire op_sltu;
    wire op_and;
    wire op_or;
    wire op_xor;
    wire op_sll;
    wire op_srl;
    wire op_sra;

    wire op_nop;
    // no operation at present
    wire op_sp;

    assign  {   op_add,     op_sub,     op_slt,         op_sltu ,
                op_and,     op_or,      op_xor,
                op_sll,     op_srl,     op_sra,
                op_nop,     op_sp   
    }   =   alu_op;

    wire [63:0] add_sub_auipc_result;
    wire [63:0] slt_result;
    wire [63:0] sltu_result;
    // wire [63:0] sll_result;    
    // wire [63:0] srl_result;
    // wire [63:0] sra_result;    
    wire [63:0] shift_result;
    wire [63:0] and_result;
    wire [63:0] or_result;
    wire [63:0] xor_result;
    // wire [63:0] lui_result;
    wire [63:0] nop_result;// include lui


//logic
    assign and_result = alu_src1 & alu_src2;
    assign or_result  = alu_src1 | alu_src2;
    assign xor_result = alu_src1 ^ alu_src2;
    assign nop_result = alu_src2;

//add
    wire [63: 0] adder_a;
    wire [63: 0] adder_b;
    wire         adder_cin;
    wire [63: 0] adder_result;
    wire         adder_cout;

    assign adder_a = alu_src1;
    assign adder_b = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;
    assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1 : 1'b0;

    //TODO:有无符号的区别目前不知道这个不能不用
    ysyx_2022040010_add add_u (
        .in_a   (adder_a        ),
        .in_b   (adder_b        ),
        .in_c   (adder_cin      ),
        .out_s  (adder_result   ),
        .out_c  (adder_cout     ),
        .alu_32 (alu_32         )
    );
    
    // assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;
    assign add_sub_auipc_result = adder_result[63: 0];

//shift
    ysyx_2022040010_shift   shift_u  (
        .shift_operand  (alu_src1                   ),
        .shift_amount   (alu_src2                   ),
        .shift_op       ({op_sll, op_srl, op_sra}   ),
        .alu_32         (alu_32                     ),
        .shift_result   (shift_result               )
    );

    assign slt_result[63:1] = 63'b0;
    assign slt_result[0] = (alu_src1[63] & ~alu_src2[63])
                        |  (~(alu_src1[63]^alu_src2[63]) & adder_result[63]);

    assign sltu_result[63: 1] = 63'b0;
    assign sltu_result[0] = ~adder_cout;
    

    assign  alu_result  =   ({64{op_add | op_sub           }} & add_sub_auipc_result)
                        |   ({64{op_sll | op_srl | op_sra  }} & shift_result        )
                        |   ({64{op_and                    }} & and_result          )
                        |   ({64{op_or                     }} & or_result           )
                        |   ({64{op_xor                    }} & xor_result          )
                        |   ({64{op_slt                    }} & slt_result          )
                        |   ({64{op_sltu                   }} & sltu_result         )
                        |   ({64{op_nop                    }} & nop_result          );

    assign alu_over     =   (op_add | op_sub) ? 1'b1 :
                            (op_sll | op_srl | op_sra) ? 1'b1 :
                            op_and ? 1'b1 :
                            op_or  ? 1'b1 :
                            op_xor ? 1'b1 :
                            op_slt ? 1'b1 :
                            op_sltu? 1'b1 :
                            op_nop ? 1'b1 : 1'b0;



endmodule

