import testbed_testenv_am_apb_pkg::*;
import testbed_testenv_am_avalon_pkg::*;

module testbed_testenv_flatten #(
    parameter CPUIF              = "Avalon",
    parameter DMA_CHANNEL_COUNT  = 8       ,

    parameter MAX_ROUTERS_COUNT  = 256     ,
    parameter MAX_AXI_DATA_WIDTH = 1024    
) (
    input  logic     clk_dma     ,
    input  logic     rst_n_dma   ,

    apb4_intf.s      apb_slave   ,
    avalon_mm_intf.s avalon_slave,
);

    initial begin
        assert (CPUIF == "Avalon" || CPUIF == "APB") 
        else   $error("Module testbed_testenv_flatten, wrong parameter CPUIF, should be Avalon or APB, not %s", CPUIF);
    end

    generate
        if (CPUIF == "Avalon") begin
            
        end
        else begin
            testbed_testenv_am_apb (
                input wire clk,
                input wire arst_n,

                apb4_intf.slave s_apb,

                input testbed_testenv_am_apb_pkg::testbed_testenv_am__in_t hwif_in,
                output testbed_testenv_am_apb_pkg::testbed_testenv_am__out_t hwif_out
            );
        end
    endgenerate

endmodule