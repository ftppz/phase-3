
`include "defines.v"
`timescale 1ns / 1ps
module ysyx_2022040010_id (
    input                   clk,
    input                   rst,
    
    input  [`StallBus]      stall,

    output                  stallreq_for_load,
    
    // from ex
    input  [ 6:0]           ex_to_id_for_stallload,
    //from e2m
    input  [6:0]            e2m_to_id_for_stallload,

    input  [`IF_TO_ID_BUS]  if_to_id_bus,

    input  [31:0]           isram_rdata,

 
    input  [`BP_TO_RF_BUS]  ex_to_rf_bus,
    input  [`BP_TO_RF_BUS]  e2m_to_rf_bus,
    input  [`BP_TO_RF_BUS]  mem_to_rf_bus,
    input  [`BP_TO_RF_BUS]  wb_to_rf_bus,
    input  [76:0]  wb_to_csr_bus,

    output [`ID_TO_EX_BUS]  id_to_ex_bus,
    output [63:0]           regs_o[0:31] // TODO: DIFFTEST
);

    // -------------- updata data --------------
    reg [31:0] buf_inst;    
    reg [`IF_TO_ID_BUS] buf_if_to_id_bus;

    reg [31:0] id_stall_inst;
    wire id_stall = stall[3] | stall[1] | stall[0];
    reg id_cnt;

    always @(posedge clk) begin
        if (rst) begin
            id_cnt <= 1'b0;
        end
        else if (id_stall & ~id_cnt) id_cnt <= 1'b1;
        else if (id_stall & id_cnt)  begin  end
        else if (~id_stall & id_cnt) id_cnt <= 1'b0;
        else                         id_cnt <= 1'b0;
    end


    always @(posedge clk) begin
        if (rst) begin
            buf_inst <= 32'b0;
            buf_if_to_id_bus <= `IF_TO_ID_WD'b0;
        end
        else if (stall[2]) begin //bru flush
            buf_inst <= 32'b0;
            buf_if_to_id_bus <= `IF_TO_ID_WD'b0;
        end
        else if (id_stall & ~id_cnt) begin
            id_stall_inst <= isram_rdata;
        end
        else if (id_stall & id_cnt) begin
            //keep
        end
        else if (~id_stall & id_cnt) begin
            buf_inst <= id_stall_inst;
            buf_if_to_id_bus <= if_to_id_bus;
            id_stall_inst <= 32'b0;
        end
        else if (stall[1]) begin
            //keep
        end
        else begin
            buf_inst <= isram_rdata;
            buf_if_to_id_bus <= if_to_id_bus;
        end
    end

    wire ce_i;
    wire [63:0] id_pc_i, next_pc_i;
    wire [31:0] inst_i;
    
    assign {
        ce_i, 
        id_pc_i, 
        next_pc_i
    } = buf_if_to_id_bus[`IF_TO_ID_WD-1] ? buf_if_to_id_bus : `IF_TO_ID_WD'b0;

    wire [31:0] inst_i = ce_i ? buf_inst : 32'b0;


    // --------------- decomposition instruction ---------------
    // |- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -| 
    // |31- - - 27262524- - - 2019- - - - 1514- 1211- - - 7 6 - - - - - 0|  
    // |   func7     |   rs2   |    rs1    |func3|   rd    |    opcode   | R-type
    // |        imm[11:0]      |    rs1    |func3|   rd    |    opcode   | I-type
    // |  imm[11:5]  |   rs2   |    rs1    |func3|   rd    |    opcode   | S-type
    // | imm[12|10:5]|   rs2   |    rs1    |func3|   rd    |    opcode   | B-type
    // |            imm[31:12]                   |   rd    |    opcode   | U-type
    // |        imm[20|10:1|11|19:12]            |   rd    |    opcode   | J-type
    
    wire [ 6:0] opcode;
    wire [ 2:0] func3;
    wire [ 6:0] func7;
    wire [ 4:0] rs1, rs2, rd;
    wire [63:0] rs1_data, rs2_data;

    assign opcode   = inst_i[ 6:0];
    assign rs1      = inst_i[19:15]; 
    assign rs2      = inst_i[24:20];
    assign rd       = inst_i[11:7];
    assign func3    = inst_i[14:12];
    assign func7    = inst_i[31:25];

    //decoder output variable
    wire [127:0] op_d, func7_d;
    wire [  7:0] func3_d;

    //decoder
    ysyx_2022040010_decoder_7_128   decoder_7_128_u0 (   .in(opcode),    .out(op_d)      );
    ysyx_2022040010_decoder_7_128   decoder_7_128_u1 (   .in(func7),     .out(func7_d)   );
    ysyx_2022040010_decoder_3_8     decoder_3_8_u0   (   .in(func3),     .out(func3_d)   );


    // ------------ Instruction Classification -------------
    //ALU  30
    wire inst_lui,      inst_auipc;
    wire inst_addi,     inst_add;
    wire inst_addiw,    inst_addw;
    wire inst_sub,      inst_subw;
    wire inst_slti,     inst_sltiu;
    wire inst_slt,      inst_sltu;
    wire inst_slli,     inst_srli,  inst_srai; //special R
    wire inst_slliw,    inst_srliw, inst_sraiw;     
    wire inst_sll,      inst_srl,   inst_sra;
    wire inst_sllw,     inst_srlw,  inst_sraw;
    wire inst_xori,     inst_ori,   inst_andi;
    wire inst_xor,      inst_or,    inst_and; 

    //ALU-special  2 
    // wire inst_fence,    inst_fencei;  ---related to cache
    wire inst_ecall;    // related to special registers
    wire inst_ebreak;
    wire inst_mret; 

    //LSU --can be merged with ALU   11
    wire inst_lb,   inst_lh,    inst_lw,    inst_ld;    
    wire inst_lbu,  inst_lhu,   inst_lwu;
    wire inst_sb,   inst_sh,    inst_sw,    inst_sd;

    //BRU --branch   8
    wire inst_jal,  inst_jalr;
    wire inst_beq,  inst_bne, inst_blt, inst_bge, inst_bltu, inst_bgeu;

    //CSR --special register   6
    wire inst_csrrw, inst_csrrs, inst_csrrc,     inst_csrrwi,    inst_csrrsi,    inst_csrrci;

    //MUL   *    5
    wire inst_mul,   inst_mulh,  inst_mulhsu,    inst_mulhu;
    wire inst_mulw;

    //DIV & REM   /  %   8
    wire inst_div,   inst_divu,    inst_divw,  inst_divuw;
    wire inst_remw,  inst_remuw,   inst_rem,   inst_remu;
    
    //alu_op  12
    wire op_add,    op_sub,     op_slt,  op_sltu;
    wire op_and,    op_or,      op_xor;            //op_nor
    wire op_sll,    op_srl,     op_sra;
    wire op_nop;
    wire op_sp;


    // ------------- Determine instruction type -----------
//inst
    //ALU  
    assign inst_lui     =   op_d[7'b0110_111];
    assign inst_auipc   =   op_d[7'b0010_111];
    assign inst_addi    =   op_d[7'b0010_011] & func3_d[3'b000];
    assign inst_addiw   =   op_d[7'b0011_011] & func3_d[3'b000];
    assign inst_add     =   op_d[7'b0110_011] & func3_d[3'b000] & func7_d[7'b0000_000];
    assign inst_addw    =   op_d[7'b0111_011] & func3_d[3'b000] & func7_d[7'b0000_000];
    assign inst_sub     =   op_d[7'b0110_011] & func3_d[3'b000] & func7_d[7'b0100_000];
    assign inst_subw    =   op_d[7'b0111_011] & func3_d[3'b000] & func7_d[7'b0100_000];
    assign inst_slti    =   op_d[7'b0010_011] & func3_d[3'b010];
    assign inst_sltiu   =   op_d[7'b0010_011] & func3_d[3'b011];
    //special-I 
    //imm[5:0] = shamt
    assign inst_slli    =   op_d[7'b0010_011] & func3_d[3'b001] & ~inst_i[30];
    assign inst_srli    =   op_d[7'b0010_011] & func3_d[3'b101] & ~inst_i[30];
    assign inst_srai    =   op_d[7'b0010_011] & func3_d[3'b101] &  inst_i[30];
    //imm[4:0] = shamt
    assign inst_slliw   =   op_d[7'b0011_011] & func3_d[3'b001] & ~inst_i[30];
    assign inst_srliw   =   op_d[7'b0011_011] & func3_d[3'b101] & ~inst_i[30];
    assign inst_sraiw   =   op_d[7'b0011_011] & func3_d[3'b101] &  inst_i[30];
    assign inst_sll     =   op_d[7'b0110_011] & func3_d[3'b001] & func7_d[7'b0000_000];
    assign inst_sllw    =   op_d[7'b0111_011] & func3_d[3'b001] & func7_d[7'b0000_000];
    assign inst_slt     =   op_d[7'b0110_011] & func3_d[3'b010] & func7_d[7'b0000_000];
    assign inst_sltu    =   op_d[7'b0110_011] & func3_d[3'b011] & func7_d[7'b0000_000];
    assign inst_srl     =   op_d[7'b0110_011] & func3_d[3'b101] & func7_d[7'b0000_000];
    assign inst_srlw    =   op_d[7'b0111_011] & func3_d[3'b101] & func7_d[7'b0000_000];
    assign inst_sra     =   op_d[7'b0110_011] & func3_d[3'b101] & func7_d[7'b0100_000];
    assign inst_sraw    =   op_d[7'b0111_011] & func3_d[3'b101] & func7_d[7'b0100_000];
    assign inst_xori    =   op_d[7'b0010_011] & func3_d[3'b100];
    assign inst_ori     =   op_d[7'b0010_011] & func3_d[3'b110];
    assign inst_andi    =   op_d[7'b0010_011] & func3_d[3'b111]; 
    assign inst_xor     =   op_d[7'b0110_011] & func3_d[3'b100] & func7_d[7'b0000_000];
    assign inst_or      =   op_d[7'b0110_011] & func3_d[3'b110] & func7_d[7'b0000_000];
    assign inst_and     =   op_d[7'b0110_011] & func3_d[3'b111] & func7_d[7'b0000_000];
    //ALU-special   No operation processing and structure processing
    assign inst_ecall   =   op_d[7'b1110_011] & func3_d[3'b000] & ~inst_i[20];
    assign inst_ebreak  =   op_d[7'b1110_011] & func3_d[3'b000] & inst_i[20];
    assign inst_mret    =   op_d[7'b1110_011] & func3_d[3'b000] & func7_d[7'b0011_000];
    //LSU
    assign inst_lb      =   op_d[7'b0000_011] & func3_d[3'b000];
    assign inst_lh      =   op_d[7'b0000_011] & func3_d[3'b001];
    assign inst_lw      =   op_d[7'b0000_011] & func3_d[3'b010];
    assign inst_lwu     =   op_d[7'b0000_011] & func3_d[3'b110];
    assign inst_lbu     =   op_d[7'b0000_011] & func3_d[3'b100];
    assign inst_lhu     =   op_d[7'b0000_011] & func3_d[3'b101];
    assign inst_ld      =   op_d[7'b0000_011] & func3_d[3'b011];
    assign inst_sb      =   op_d[7'b0100_011] & func3_d[3'b000];
    assign inst_sh      =   op_d[7'b0100_011] & func3_d[3'b001];
    assign inst_sw      =   op_d[7'b0100_011] & func3_d[3'b010];
    assign inst_sd      =   op_d[7'b0100_011] & func3_d[3'b011];
    
    //BRU
    assign inst_jal     =   op_d[7'b1101_111];
    assign inst_jalr    =   op_d[7'b1100_111] & func3_d[3'b000];
    assign inst_beq     =   op_d[7'b1100_011] & func3_d[3'b000];
    assign inst_bne     =   op_d[7'b1100_011] & func3_d[3'b001];
    assign inst_blt     =   op_d[7'b1100_011] & func3_d[3'b100];
    assign inst_bge     =   op_d[7'b1100_011] & func3_d[3'b101];
    assign inst_bltu    =   op_d[7'b1100_011] & func3_d[3'b110];
    assign inst_bgeu    =   op_d[7'b1100_011] & func3_d[3'b111];
    
    //CSR
    assign inst_csrrw   =   op_d[7'b1110_011] & func3_d[3'b001];
    assign inst_csrrs   =   op_d[7'b1110_011] & func3_d[3'b010];
    assign inst_csrrc   =   op_d[7'b1110_011] & func3_d[3'b011]; 
    assign inst_csrrwi  =   op_d[7'b1110_011] & func3_d[3'b101];
    assign inst_csrrsi  =   op_d[7'b1110_011] & func3_d[3'b110];
    assign inst_csrrci  =   op_d[7'b1110_011] & func3_d[3'b111];
    
    //MUL
    assign inst_mul     =   op_d[7'b0110_011] & func3_d[3'b000] & func7_d[7'b0000_001];
    assign inst_mulh    =   op_d[7'b0110_011] & func3_d[3'b001] & func7_d[7'b0000_001];
    assign inst_mulhsu  =   op_d[7'b0110_011] & func3_d[3'b010] & func7_d[7'b0000_001];
    assign inst_mulhu   =   op_d[7'b0110_011] & func3_d[3'b011] & func7_d[7'b0000_001];
    assign inst_mulw    =   op_d[7'b0111_011] & func3_d[3'b000] & func7_d[7'b0000_001];
    
    //DIV
    assign inst_div     =   op_d[7'b0110_011] & func3_d[3'b100] & func7_d[7'b0000_001];
    assign inst_divu    =   op_d[7'b0110_011] & func3_d[3'b101] & func7_d[7'b0000_001];
    assign inst_divw    =   op_d[7'b0111_011] & func3_d[3'b100] & func7_d[7'b0000_001];
    assign inst_divuw   =   op_d[7'b0111_011] & func3_d[3'b101] & func7_d[7'b0000_001];
    //%
    assign inst_rem     =   op_d[7'b0110_011] & func3_d[3'b110] & func7_d[7'b0000_001];
    assign inst_remu    =   op_d[7'b0110_011] & func3_d[3'b111] & func7_d[7'b0000_001];
    assign inst_remw    =   op_d[7'b0111_011] & func3_d[3'b110] & func7_d[7'b0000_001];
    assign inst_remuw   =   op_d[7'b0111_011] & func3_d[3'b111] & func7_d[7'b0000_001];


    // -------------- Instruction secondary classification --------------
    wire [ 7: 0] bru_op;
    wire [`SP_BUS]      sp_bus;
    wire lsu_8, lsu_16, lsu_32, lsu_64, mul_32, div_32, alu_32;
    wire [10:0]         mem_op;       //classify instruction into mem
    wire [ 4:0]         mul_op;       //classify instruction into mul
    wire [ 3:0]         rem_op;
    wire [ 3:0]         div_op;       //classify instruction into div
    wire [ 5:0]         sru_op;   
    wire [`AluOpBus]    alu_op;       //classify instruction into alu
    wire [`AluSel1Bus]  sel_alu_src1; //alu src1 classification
    wire [`AluSel2Bus]  sel_alu_src2; //alu src2 classification  
    // dram
    wire dram_e; 
    wire dram_we;
    // regfile
    wire rf_we;
    wire [ 4:0] rf_waddr;
    wire sel_rf_res;
    wire [`RegBus] rf_rdata1;
    wire [`RegBus] rf_rdata2;
    // csr
    wire csr_re;
    wire [11:0] csr_raddr;
    wire [`RegBus] csr_rdata;
    wire csr_we;
    wire [11:0] csr_waddr;
    wire [`RegBus] csr_wdata;
    wire [11:0] csr_addr; // csr_source and csr_dest
    wire [11:0] csr_dest;
    assign csr_addr = inst_i[31:20];
    assign csr_raddr = csr_addr;
    assign csr_dest  = csr_addr;

    
//alu src1 src2
    // rs1 to src1
    assign sel_alu_src1[0]  = inst_addi  |  inst_addiw   |   inst_add    |   inst_addw   
                            | inst_sub   |  inst_subw    |   inst_slti   |   inst_sltiu
                            | inst_slli  |  inst_srli    |   inst_srai   |   inst_slliw
                            | inst_srliw |  inst_sraiw   |   inst_sll    |   inst_sllw
                            | inst_slt   |  inst_sltu    |   inst_srl    |   inst_srlw
                            | inst_sra   |  inst_sraw    |   inst_xori   |   inst_ori
                            | inst_andi  |  inst_xor     |   inst_or     |   inst_and
                            | inst_lb    |  inst_lh      |   inst_lw     |   inst_lwu
                            | inst_lbu   |  inst_lhu     |   inst_ld     |   inst_sb
                            | inst_sh    |  inst_sw      |   inst_sd     
                            | inst_csrrw |  inst_csrrs   |   inst_csrrc; 
    
    // pc to src1
    assign sel_alu_src1[1]  = inst_auipc |  inst_jal     |   inst_jalr;
    
    //nop
    assign sel_alu_src1[2]  = inst_lui;

    //csr uimm to src1
    assign sel_alu_src1[3] = inst_csrrwi |  inst_csrrsi  |   inst_csrrci;

    //rs2 to src2
    assign sel_alu_src2[0]  = inst_add   |   inst_addw   |  inst_sub    |   inst_subw  
                            | inst_sll   |   inst_slt    |  inst_sltu
                            | inst_srl   |   inst_sra
                            | inst_xor   |   inst_or     |  inst_and;


    /// imm_sign_extend to src2 I-type
    assign sel_alu_src2[1]  = inst_addi  |   inst_addiw  |  inst_slti   |   inst_sltiu
                            | inst_xori  |   inst_ori    |  inst_andi   |   inst_lb
                            | inst_lh    |   inst_lw     |  inst_ld     |   inst_lbu   |   inst_lhu    |  inst_lwu;

    // imm_sign_extend to src2 U-type
    assign sel_alu_src2[2]  = inst_lui   |   inst_auipc;

    //shamt to src2
    assign sel_alu_src2[3]  = inst_slli  |   inst_srli   |   inst_srai   
                            | inst_slliw |   inst_srliw  |   inst_sraiw;  
    // src2 = 4
    assign sel_alu_src2[4]  = inst_jal   |   inst_jalr;  
    // imm_sign_extend to src2 S-type
    assign sel_alu_src2[5]  = inst_sb    |   inst_sw     |   inst_sh     |   inst_sd;
         
    // zextend(rs2[4:0])
    assign sel_alu_src2[6]  = inst_sllw  |   inst_srlw   |  inst_sraw;

    // csr_rdata to rs2
    assign sel_alu_src2[7]  = inst_csrrw | inst_csrrs    | inst_csrrc
                            | inst_csrrwi| inst_csrrsi   | inst_csrrci;
//op
    //ALU-special
    assign op_sp    =   inst_ecall  | inst_ebreak | inst_mret;

    assign sp_bus   =   {inst_ecall,    inst_ebreak}; // TODO: +mret 
    //special end

    assign op_add   =   inst_add    |   inst_addw   |   inst_addi   |   inst_addiw  
                    |   inst_lb     |   inst_lh     |   inst_lw     |   inst_ld
                    |   inst_lbu    |   inst_lhu    |   inst_lwu    |   inst_sb
                    |   inst_sh     |   inst_sw     |   inst_sd     |   inst_auipc
                    |   inst_jal    |   inst_jalr;
    assign op_sub   =   inst_sub    |   inst_subw;  

    assign op_slt   =   inst_slt    |   inst_slti;
    assign op_sltu  =   inst_sltu   |   inst_sltiu;
    assign op_sll   =   inst_sll    |   inst_slli   |   inst_slliw  |   inst_sllw;
    assign op_srl   =   inst_srl    |   inst_srli   |   inst_srliw  |   inst_srlw;
    assign op_sra   =   inst_sra    |   inst_srai   |   inst_sraiw  |   inst_sraw;
    assign op_and   =   inst_and    |   inst_andi   |   inst_csrrc  |   inst_csrrci;
    assign op_or    =   inst_or     |   inst_ori    |   inst_csrrs  |   inst_csrrsi;
    assign op_xor   =   inst_xor    |   inst_xori;
    assign op_nop   =   inst_lui    |   inst_csrrw  |   inst_csrrwi;

    assign alu_op   =   {   op_add,     op_sub,     op_slt,         op_sltu ,
                            op_and,     op_or,      op_xor,
                            op_sll,     op_srl,     op_sra,
                            op_nop,     op_sp   };

    assign mul_op   =   {   inst_mul,   inst_mulh,  inst_mulhsu,    inst_mulhu, inst_mulw };
    
    assign div_op   =   {   inst_div,   inst_divu,  inst_divw,      inst_divuw   };

    assign rem_op   =   {   inst_rem,   inst_remu,  inst_remw,      inst_remuw  };

    assign mem_op   =   {   inst_lb,    inst_lh,    inst_lw,        inst_ld,
                            inst_lbu,   inst_lhu,   inst_lwu,
                            inst_sb,    inst_sh,    inst_sw,        inst_sd };
    //specail_regs_u
    assign sru_op   =   {   inst_csrrw, inst_csrrs, inst_csrrc,     
                            inst_csrrwi,inst_csrrsi,inst_csrrci };


//dram
    //data ram load and store enable
    assign dram_e   =   inst_lb     |   inst_lh     |   inst_lw     |   inst_ld
                    |   inst_lbu    |   inst_lhu    |   inst_lwu
                    |   inst_sb     |   inst_sh     |   inst_sw     |   inst_sd;
    //data ram write enable
    assign dram_we  =   inst_sb     |   inst_sh     |   inst_sw     |   inst_sd;

    // 0 regfile res from alu_res ; 1 form ld_res 
    assign sel_rf_res   =   inst_lb     |   inst_lh     |   inst_lw     |   inst_ld
                        |   inst_lbu    |   inst_lhu    |   inst_lwu;

    assign  lsu_8   =   inst_lb     |   inst_lbu    |   inst_sb;
    assign  lsu_16  =   inst_lh     |   inst_lhu    |   inst_sh;    
    assign  lsu_32  =   inst_lw     |   inst_lwu    |   inst_sw;
    assign  mul_32  =   inst_mulw;
    assign  div_32  =   inst_divw   |   inst_divuw  |   inst_remw   |   inst_remuw;
    assign  alu_32  =   inst_addiw  |   inst_addw   |   inst_subw   |   inst_slliw
                    |   inst_srliw  |   inst_sraiw  |   inst_sllw   |   inst_srlw
                    |   inst_sraw;
    assign  lsu_64   =   inst_sd     |   inst_ld;

//regfile store enable
    assign rf_we    =   inst_lui    |   inst_auipc  |   inst_jal    |   inst_jalr
                    |   inst_lb     |   inst_lh     |   inst_lw
                    |   inst_lbu    |   inst_lhu    |   inst_addi   |   inst_slti
                    |   inst_sltiu  |   inst_xori   |   inst_ori    |   inst_andi
                    |   inst_slli   |   inst_srli   |   inst_srai   |   inst_add
                    |   inst_sub    |   inst_sll    |   inst_slt    |   inst_sltu
                    |   inst_xor    |   inst_srl    |   inst_sra    |   inst_or
                    |   inst_and    |   inst_lwu    |   inst_ld     
                    |   inst_srli   |   inst_srai   |   inst_addiw  |   inst_slliw
                    |   inst_srliw  |   inst_sraiw  |   inst_addw   |   inst_subw
                    |   inst_sllw   |   inst_srlw   |   inst_sraw   
                    |   inst_mul    |   inst_mulh   |   inst_mulhsu
                    |   inst_mulhu  |   inst_div    |   inst_divu   |   inst_rem
                    |   inst_remu   |   inst_mulw   |   inst_divw   |   inst_divuw 
                    |   inst_remw   |   inst_remuw  |   inst_csrrw  |   inst_csrrs
                    |   inst_csrrc  |   inst_csrrwi |   inst_csrrsi |   inst_csrrci;

    assign csr_re   =   (inst_csrrw & rd!=5'b0)  |  inst_csrrs  |   inst_csrrc
                    |   (inst_csrrwi& rd!=5'b0)  |  inst_csrrsi |   inst_csrrci  
    assign csr_we   =   inst_csrrw  |   (inst_csrrs & rs1!=5'b0)    |   (inst_csrrc & rs1!=5'b0)  
                    |   inst_csrrwi |   (inst_csrrsi& rs1!=5'b0)    |   (inst_csrrci& rs1!=5'b0);

//branch
    assign bru_op   =   {   inst_jal,   inst_jalr,  inst_beq,   inst_bne,   inst_blt,
                            inst_bge,   inst_bltu,  inst_bgeu   }; 




//end
    // ------------- bypass data ----------
    wire ex_rf_we,e2m_rf_we, mem_rf_we, wb_rf_we;
    wire [ 4:0] ex_rf_waddr, e2m_rf_waddr, mem_rf_waddr, wb_rf_waddr;
    wire [`RegBus] ex_rf_wdata, e2m_rf_wdata, mem_rf_wdata, wb_rf_wdata;

    assign {
         ex_rf_we,
        ,ex_rf_waddr
        ,ex_rf_wdata
    } = ex_to_rf_bus;

    assign {
         e2m_rf_we
        ,e2m_rf_waddr
        ,e2m_rf_wdata
    } = e2m_to_rf_bus;

    assign {
         mem_rf_we
        ,mem_rf_waddr
        ,mem_rf_wdata
    } = mem_to_rf_bus;

    assign {
         wb_rf_we
        ,wb_rf_waddr
        ,wb_rf_wdata
    } = wb_to_rf_bus;

    assign rf_rdata1 =  (ex_rf_we  & (ex_rf_waddr  == rs1)) ? ex_rf_wdata
                    :   (e2m_rf_we & (e2m_rf_waddr == rs1)) ? e2m_rf_wdata
                    :   (mem_rf_we & (mem_rf_waddr == rs1)) ? mem_rf_wdata
                    :   (wb_rf_we  & (wb_rf_waddr  == rs1)) ? wb_rf_wdata
                    :   rs1_data;
    assign rf_rdata2 =  (ex_rf_we  & (ex_rf_waddr  == rs2)) ? ex_rf_wdata 
                    :   (e2m_rf_we & (e2m_rf_waddr == rs2)) ? e2m_rf_wdata
                    :   (mem_rf_we & (mem_rf_waddr == rs2)) ? mem_rf_wdata
                    :   (wb_rf_we  & (wb_rf_waddr  == rs2)) ? wb_rf_wdata 
                    :   rs2_data;
    assign rf_waddr  =   rd;


    // ------------- Prepare Data For Output ------------
    wire [`ID_TO_EX_BUS] id_to_ex_bus_temp;
    assign id_to_ex_bus_temp = {
        bru_op,         // 366
        sp_bus,         // 358
        lsu_8,          // 356
        lsu_16,         // 355
        lsu_32,         // 354
        lsu_64,         // 353
        mul_32,         // 352
        div_32,         // 351
        alu_32,         // 350
        mem_op,         // 349
        mul_op,         // 338
        rem_op,         // 333
        div_op,         // 329
        sru_op,         // 325
        next_pc_i,      // 319
        id_pc_i,        // 255
        inst_i,         // 191
        alu_op,         // 159
        sel_alu_src1,   // 147
        sel_alu_src2,   // 144
        dram_e,         // 137
        dram_we,        // 136
        rf_we,          // 135
        rf_waddr,       // 134
        sel_rf_res,     // 129
        rf_rdata1,      // 128
        rf_rdata2,      // 64
        csr_rdata,      // 64
        csr_dest,       // 12



    };

    wire [4:0] ex_rd, e2m_rd;
    wire ex_dram_we, ex_dram_e;
    wire e2m_dram_we, e2m_dram_e;

    assign { ex_rd, ex_dram_we, ex_dram_e } = ex_to_id_for_stallload;
    wire stallreq_for_load_ex = ((ex_rd == rs1) | (ex_rd == rs2)) & ex_dram_e & ~ex_dram_we;

    assign {e2m_rd, e2m_dram_we, e2m_dram_e} = e2m_to_id_for_stallload;
    wire stallreq_for_load_e2m = ((e2m_rd == rs1) | (e2m_rd == rs2)) & e2m_dram_e & ~e2m_dram_we;


    // ------------- output ------------
    assign stallreq_for_load =  stallreq_for_load_ex | stallreq_for_load_e2m;
    assign id_to_ex_bus = id_to_ex_bus_temp;


    // ---------- regfile ----------
    ysyx_2022040010_regfile regfile_id(
        .clk    (clk        ),
        .rst    (rst        ),
        .stall  (stall      ),

        .re1    ( 1'b1      ),
        .raddr1 (rs1        ),
        .rdata1 (rs1_data   ),

        .re2    ( 1'b1      ),
        .raddr2 (rs2        ),
        .rdata2 (rs2_data   ),

        .we     (wb_rf_we   ),
        .waddr  (wb_rf_waddr),
        .wdata  (wb_rf_wdata),
        .regs_o (regs_o     ) // TODO:difftest
    );


    // ---------- csr ----------
    wire 
    wire wb_csr_we;
    wire [11:0] wb_csr_waddr;
    wire [63:0] wb_csr_wdata;
    assign {
         wb_csr_we
        ,wb_csr_waddr
        ,wb_csr_wdata
    } = wb_to_csr_bus;

    // assign csr_waddr = inst[31:20];
    
    ysyx_2022040010_csr csr_id (
         .clk           (clk)
        ,.rst           (rst)
        ,.stall         (stall)

        ,.csr_re_i      (csr_re)
        ,.csr_raddr_i   (csr_raddr)
        ,.csr_rdata_o   (csr_rdata)

        ,.csr_we_i      (wb_csr_we)
        ,.csr_waddr_i   (wb_csr_waddr)
        ,.csr_wdata_i   (wb_csr_wdata)
    );
    

endmodule


// Machine-Leval CSRs

// mepc;    // triggle exception pc
// mstatus; // cpu status //Not commonly used
// mcause;  // exception reason
// mtvec;   // exception entry address



