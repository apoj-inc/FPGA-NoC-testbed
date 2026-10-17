import testbed_testenv_am_pkg::*;

module testbed_testenv_flatten #(
    parameter PLATFORM           = "Altera",
    parameter DMA_CHANNEL_COUNT  = 8       ,

    parameter MAX_ROUTERS_COUNT  = 256     ,
    parameter MAX_AXI_DATA_WIDTH = 1024    ,

    parameter ROUTERS_REG_COUNT  = (MAX_ROUTERS_COUNT   / 128) + (MAX_ROUTERS_COUNT   % 128 != 0),
    parameter AXI_DATA_REG_COUNT = (MAX_AXI_DATA_WIDTH  / 128) + (MAX_AXI_DATA_WIDTH  % 128 != 0)
) (
    input  logic                          clk_dma                               ,
    input  logic                          rst_n_dma                             ,

    apb4_intf.slave                       apb_slave                             ,
    avalon_mm_intf.agent                  avalon_slave                          ,

    output logic [DMA_CHANNEL_COUNT-1:0]  testenv_rstn_o                        ,
    input  logic [DMA_CHANNEL_COUNT-1:0]  testenv_rstn_sts_i                    ,

    output logic [DMA_CHANNEL_COUNT-1:0]  start_model_o                         ,
    output logic [DMA_CHANNEL_COUNT-1:0]  read_pmu_o                            ,
    output logic [MAX_ROUTERS_COUNT-1:0]  ld_enable_o        [DMA_CHANNEL_COUNT],
    input  logic [MAX_ROUTERS_COUNT-1:0]  ld_idle_i          [DMA_CHANNEL_COUNT],

    output logic [127:0]                  rdata_sel_o        [DMA_CHANNEL_COUNT],
    input  logic [MAX_AXI_DATA_WIDTH-1:0] rdata_i            [DMA_CHANNEL_COUNT]
);

    initial begin
        assert (PLATFORM == "Altera" || PLATFORM == "Xilinx") 
        else   $error("Module testbed_testenv_flatten, wrong parameter PLATFORM, should be Altera or Xilinx, not %s", PLATFORM);
    end

    testbed_testenv_am__in_t  hwif_in ;
    testbed_testenv_am__out_t hwif_out;

    generate
        if (PLATFORM == "Altera") begin : avalon_regblock
            testbed_testenv_am_avalon u_testbed_testenv_am_avalon(
                .clk      (clk_dma     ),
                .arst_n   (rst_n_dma   ),

                .avalon   (avalon_slave),

                .hwif_in  (hwif_in     ),
                .hwif_out (hwif_out    )
            );

            assign apb_slave.PRDATA  = '0;
            assign apb_slave.PREADY  = '1;
            assign apb_slave.PSLVERR = '0;
        end
        else begin : apb_regblock
            testbed_testenv_am_apb u_testbed_testenv_am_apb(
                .clk      (clk_dma  ),
                .arst_n   (rst_n_dma),

                .s_apb    (apb_slave),

                .hwif_in  (hwif_in  ),
                .hwif_out (hwif_out )
            );

            assign avalon_slave.readdatavalid      = '1;     
            assign avalon_slave.writeresponsevalid = '1;
            assign avalon_slave.readdata           = '0;          
            assign avalon_slave.response           = '0;          
        end
    endgenerate

    generate
        genvar i;

        for (i = 0; i < DMA_CHANNEL_COUNT; i++) begin : single_test_channel
            always_comb begin
                testenv_rstn_o[i] = hwif_out.TESTBED_CHANNEL_REGFILE[i].TESTBED_CONTROL_STATUS_REG.RESETN_CONTROL.value;
                start_model_o [i] = hwif_out.TESTBED_CHANNEL_REGFILE[i].TESTBED_CONTROL_STATUS_REG.START_MODEL.value   ;
                read_pmu_o    [i] = hwif_out.TESTBED_CHANNEL_REGFILE[i].TESTBED_CONTROL_STATUS_REG.READ_PMU.value      ;

                rdata_sel_o   [i] = hwif_out.TESTBED_CHANNEL_REGFILE[i].TESTBED_RDATA_SEL_REG.RDATA_SEL.value          ;

                for (int j = 0; j < ROUTERS_REG_COUNT; j++) begin
                    ld_enable_o[i][128*j +: 128] = hwif_out.TESTBED_CHANNEL_REGFILE[i].TESTBED_LOADER_ENABLE_REG[j].LOADER_ENABLE.value;
                end


                hwif_in.TESTBED_CHANNEL_REGFILE[i].TESTBED_CONTROL_STATUS_REG.NEXT_PTR.next      = 'hE0 * ((i+1) % DMA_CHANNEL_COUNT);
                hwif_in.TESTBED_CHANNEL_REGFILE[i].TESTBED_CONTROL_STATUS_REG.RESETN_STATUS.next = testenv_rstn_sts_i[i];

                for (int j = 0; j < ROUTERS_REG_COUNT; j++) begin
                    hwif_in.TESTBED_CHANNEL_REGFILE[i].TESTBED_LOADER_IDLE_REG[j].LOADER_IDLE.next = ld_idle_i[i][128*j +: 128];
                end

                for (int j = 0; j < AXI_DATA_REG_COUNT; j++) begin
                    hwif_in.TESTBED_CHANNEL_REGFILE[i].TESTBED_RDATA_REG[j].RDATA.next = rdata_i[i][128*j +: 128];
                end
            end
        end
    endgenerate

endmodule