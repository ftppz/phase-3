module csr (
     input              clk
    ,input              rst
    ,input  [`StallBus] stall

    ,input              csr_re_i
    ,input  [11:0]      csr_raddr_i
    ,output [`RegBus]   csr_rdata_o
    ,input  [`RegBus]   csr_we_i
    ,input  [11:0]      csr_waddr_i
    ,input  [`RegBus]   csr_wdata_i
);
    reg [`RegBus] csr_MIR [0:4]; // 0xf11 - 0xf15 // Machine Information Registers
/* 
    *   Number       0xf11       0xf12   0xf13   0xf14   0xf15     
    *   Privilege    MRO         MRO     MRO     MRO     MRO       
    *   Name         mvendorid   marchid mimpid  mhartid mconfigptr
    *   Width       32          MXLEN   MXLEN   MXLEN   MXLEN
*/
    
    reg [`RegBus] csr_MTS_r [0:6]; // 0x300 - 0x306 // Machine Trap Setup
/*
    *   Number       0x300   0x301   0x302   0x303   0x304   0x305   0x306      
    *   Privilege    MRW     MRW     MRW     MRW     MRW     MRW     MRW        
    *   Name         mstatus misa    medeleg mideleg mie     mtvec   mcounteren 
    *   Width                                        16
*/
    
    reg [`RegBus] csr_MTH_r [0:4]; // 0x340 - 0x34B // Machine Trap Handling
/* 
    *   Number       0x340      0x341   0x342   0x343   0x344
    *   Privilege    MRW        MRW     MRW     MRW     MRW  
    *   Name         mstcrath   mepc    mcause  mtval   mip  
    *   Width                                           16
*/

    wire type_MIR = csr_raddr_i[11:4] == 8'hf1 | csr_waddr_i[11:4] == 8'hf1;
    wire type_MTS = csr_raddr_i[11:4] == 8'030 | csr_waddr_i[11:4] == 8'h30;
    wire type_MTH = csr_raddr_i[11:4] == 8'h34 | csr_waddr_i[11:4] == 8'h34;
    wire [2:0] MIR_NO = csr_raddr_i[2:0] | csr_waddr[2:0];
    wire [2:0] MTS_NO = csr_raddr_i[2:0] | csr_waddr[2:0];
    wire [2:0] MTH_NO = csr_raddr_i[2:0] | csr_waddr[2:0];

    // write csr MTS
    always @(posedge clk) begin
        if (rst) begin
            for (int i=0; i<=6; i++) begin
                csr_MTS_r[i] = 64'b0;
            end
        end
        else begin
            if (stall[3]) begin
                // keep
            end
            else if (csr_we && type_MTS) begin
                csr_MTS_r[MTS_NO] <= csr_wdata;
            end
            else ;
        end
    end
    
    // write csr MTH
    always @(posedge clk) begin
        if (rst) begin
            for (int i=0; i<=4; i++) begin
                csr_MTH_r[i] <= 64'b0;
            end
        end
        else begin
            if (stall[3]) begin
                // keep
            end
            else if (csr_we && type_MTS) begin
                csr_MTH_r[MTH_NO] <= csr_wdata;
            end
            else ;
        end
    end


    // read csr Machine Information Registers
    reg [`RegBus] csr_rdata_MIR_r;
    always @(*) begin
        if (rst) begin
            csr_rdata_MIR_r = `ZeroWord; // TODO: init mhartid-cpuid
        end
        else if (csr_re_i && type_MIR) begin
            csr_rdata_MIR_r = csr_MIR[MIR_NO];
        end
        else begin
            csr_rdata_MIR_r = `ZeroWord;
        end
    end

    // read csr Machine Trap Setup
    reg [`RegBus] csr_rdata_MTS_r;
    always @(*) begin
        if (rst) begin
            csr_rdata_MTS_r = `ZeroWord;
        end
        else if (csr_re_i && type_MTS) begin
            csr_rdata_MTS_r = csr_MTS_r[MTS_NO];
        end
        else begin
            csr_rdata_MTS_r = `ZeroWord;
        end
    end

    // read csr Machine Trap Handling
    reg [`RegBus] csr_rdata_MTH_r;
    always @(*) begin
        if (rst) begin
            csr_rdata_MTH_r = `ZeroWord;
        end
        else if (csr_re_i && type_MTH) begin
            csr_rdata_MTH_r = csr_MTH_r[MTH_NO];
        end
        else begin
            csr_rdata_MTH_r = `ZeroWord;
        end
    end

    assign  csr_rdata_o = type_MIR ? csr_rdata_MIR_r[`RegBus] 
                        : type_MTS ? csr_rdata_MTS_r[`RegBus]
                        : type_MTH ? csr_rdata_MTH_r[`RegBus];

endmodule

// csr inst behavior
/*
csrrw: csr -> rd(!x0), rs1 -> csr
csrrs: csr -> rd, csr | rs1(!x0) -> csr
csrrc: csr -> rd, csr & ~rs1(!x0) -> csr

csrrwi: csr -> rd(!x0), (0e)uimm -> csr
csrrsi: csr -> rd, csr | (0e)uimm(!0) -> csr
csrrci: csr -> rd, csr & ~(0e)4uimm(!0) -> csr

read  csr_data, rd_addr, rs1_data/uimm, csr_addr
write rd(!x0), csr 


mtvec mstatus mie medeleg mideleg
when interrupting, mstatus csr SIE[1] MIE[3] bit will be seted 0.

exception -> abstract protect -> jump to exection handler -> soft save
ecall -> mepc(pc+4) mcause(cause) mstatus(status) pc(mtvec) -> soft handler -> mret
目前不用考虑mepc不加4的情况, mepc的值分为两种情况, 恢复异常, 中断处理, 恢复异常现场的话, 是不加4, 只是恢复发生异常的原pc, 
中断处理, 恢复上下文, 处理完毕后需要进行pc的下一条指令, 需要pc+4(简单理解就是, ecall执行, 进入异常处理, 处理完毕, 不能再指令ecall, 不然就是loop, 会死机, 所以需要指令ecall的下一条指令, 即原ecall的pc+4)


*/




