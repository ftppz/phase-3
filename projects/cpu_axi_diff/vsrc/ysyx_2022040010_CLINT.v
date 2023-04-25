// Core Local Interrupt
// include timer and soft
// because this is a single core processor
// just use timer 

module CLINT (
     input  clk
    ,input  rst

    ,input                  clint_re_i
    ,input  [15:0]          clint_raddr_i
    ,output reg [`RegBus]   clint_rdata_o

    ,input                  clint_we_i
    ,input  [15:0]          clint_waddr_i
    ,input  [`RegBus]       clint_wdata_i

    ,output msip
    ,output mtip
    ,output reg clint_mtime_int
);

    // Machine Timer Registers
    reg [`RegBus] mtime;
    reg [`RegBus] mtimecmp; // time >= mtimecmp interrupt
/* 
    *   Privilege   MRW     MRW       
    *   Name        mtime   mtimecmp
    *   Width       64      64
*/

    // read CLINT-time handler
    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            clint_rdata_o <= 64'b0;    
        end
        else if(clint_re_i) begin
            case (clint_raddr_i) // need mmio transform, raddr[15:0]->clint_raddr_i
                16'h4000: clint_rdata_o <= mtimecmp;
                16'hBff8: clint_rdata_o <= mtime;
                default: 
            endcase
        end
        else ;
    end

    // time interrupt handler
    always @(*) begin
        if(mtime >= mtimecmp) begin
            clint_mtime_int = 1'b1;
        end
        else begin
            clint_mtime_int = 1'b0;
        end
    end



    
endmodule




// external 
// PLIC(Platform-Level-Interrupt Controller)

/*
    CLINT
    Machine Timer Registers
    mtime   mtimecmp
    64      64
    the interrupt will only be taken if interrupts are enabled and the MTIME bit is set in the mie register
    Writes to mtime and mtimecmp are guaranteed to be reflected in MTIP eventually, but not necessarily immediately.


    解决方案: 让异常处理函数重定向
    1.新处理器访问mtime CSR时抛出非法指令异常
    2.异常处理函数对指令译码
    3.若原指令读mtime CSR, 则访问MMIO的mtime, 将结果写入寄存器
    4.更新PC, 从异常处理返回
*/


