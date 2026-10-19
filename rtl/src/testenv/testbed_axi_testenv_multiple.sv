`include "axi_defines.svh"

module testbed_axi_testenv_multiple #(
    parameter     PLATFORM                                = "Altera"               ,
    parameter     DMA_CHANNEL_COUNT                       = 8                      ,
    parameter     EXT_FIFO_DATA_WIDTH                     = 128                    ,

    parameter int ROUTERS_COUNT       [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{9 }},

    parameter int AXI_DATA_WIDTH      [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{32}},
    parameter int AXI_ADDR_WIDTH      [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{16}},
    parameter int AXI_ID_W_WIDTH      [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{5 }},
    parameter int AXI_ID_R_WIDTH      [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{5 }},

    parameter int AXI_LD_FIFO_DEPTH   [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{64}},

    parameter int PMU_METRIC_COUNT    [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{19}},
    parameter int PMU_DATA_WIDTH      [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{32}}
) (
    input  logic                           clk_dma                            ,
    input  logic                           rst_n_dma                          ,

    input  logic [EXT_FIFO_DATA_WIDTH-1:0] command_data_i  [DMA_CHANNEL_COUNT],
    input  logic                           command_valid_i [DMA_CHANNEL_COUNT],
    output logic                           command_ready_o [DMA_CHANNEL_COUNT],

    output logic [EXT_FIFO_DATA_WIDTH-1:0] pmu_data_o      [DMA_CHANNEL_COUNT],
    output logic                           pmu_valid_o     [DMA_CHANNEL_COUNT],
    input  logic                           pmu_ready_i     [DMA_CHANNEL_COUNT],

    apb4_intf.slave                        apb_slave                          ,
    avalon_mm_intf.agent                   avalon_slave                       ,

    output logic [DMA_CHANNEL_COUNT-1:0]   user_irq_o                         ,

    input  logic                           clk_axi                            
);

    function int max(int ARRAY [DMA_CHANNEL_COUNT]);
        max = 0;
        for (int i = 0; i < DMA_CHANNEL_COUNT; i++) begin
            if (ARRAY[i]>max) max = ARRAY[i];
        end
    endfunction

    localparam MAX_ROUTERS_COUNT  = max(ROUTERS_COUNT) ;
    localparam MAX_AXI_DATA_WIDTH = max(AXI_DATA_WIDTH);

    logic [DMA_CHANNEL_COUNT-1:0]  testenv_rstn                        ;

    logic [DMA_CHANNEL_COUNT-1:0]  start_model                         ;
    logic [DMA_CHANNEL_COUNT-1:0]  read_pmu                            ;
    logic [MAX_ROUTERS_COUNT-1:0]  ld_enable        [DMA_CHANNEL_COUNT];
    logic [MAX_ROUTERS_COUNT-1:0]  ld_idle          [DMA_CHANNEL_COUNT];

    logic [127:0]                  rdata_sel        [DMA_CHANNEL_COUNT];
    logic [MAX_AXI_DATA_WIDTH-1:0] rdata            [DMA_CHANNEL_COUNT];

    logic [DMA_CHANNEL_COUNT-1:0]  axi_resetn_synced                   ;

    testbed_testenv_flatten #(
        .PLATFORM           (PLATFORM          ),
        .DMA_CHANNEL_COUNT  (DMA_CHANNEL_COUNT ),

        .MAX_ROUTERS_COUNT  (MAX_ROUTERS_COUNT ),
        .MAX_AXI_DATA_WIDTH (MAX_AXI_DATA_WIDTH)
    ) u_testbed_testenv_flatten (
        .clk_dma            (clk_dma           ),
        .rst_n_dma          (rst_n_dma         ),

        .apb_slave          (apb_slave         ),
        .avalon_slave       (avalon_slave      ),

        .testenv_rstn_o     (testenv_rstn      ),
        .testenv_rstn_sts_i (axi_resetn_synced ),

        .start_model_o      (start_model       ),
        .read_pmu_o         (read_pmu          ),
        .ld_enable_o        (ld_enable         ),
        .ld_idle_i          (ld_idle           ),

        .rdata_sel_o        (rdata_sel         ),
        .rdata_i            (rdata             )
    );

    generate
        genvar i;

        for (i = 0; i < DMA_CHANNEL_COUNT; i++) begin : single_test_channel
            logic [ROUTERS_COUNT[i]-1:0] ld_finished;
            assign user_irq_o[i] = ~|(ld_finished ^ ld_enable[i][ROUTERS_COUNT[i]-1:0]) & |(ld_enable[i][ROUTERS_COUNT[i]-1:0]);

            logic [AXI_DATA_WIDTH[i]-1:0] ld_rdata_loc [ROUTERS_COUNT[i]];
            assign rdata[i] = ld_rdata_loc[rdata_sel[i]];

            axi_if #(
                .AXI_DATA_WIDTH (AXI_DATA_WIDTH[i]),
                .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH[i]),
                .AXI_ID_W_WIDTH (AXI_ID_W_WIDTH[i]),
                .AXI_ID_R_WIDTH (AXI_ID_R_WIDTH[i])
            ) u_axi_if[ROUTERS_COUNT[i]](), u_axi_if_ram[ROUTERS_COUNT[i]]();

            sync_rst #(
                .FF3 ()
            ) u_sync_rst (
                .rst_n_i (testenv_rstn     [i]),

                .clk_tgt (clk_axi             ),
                .rst_n_o (axi_resetn_synced[i])
            );

            testbed_axi_testenv_single #(
                .EXT_FIFO_DATA_WIDTH (EXT_FIFO_DATA_WIDTH  ),

                .ROUTERS_COUNT       (ROUTERS_COUNT     [i]),

                .AXI_DATA_WIDTH      (AXI_DATA_WIDTH    [i]),
                .AXI_ADDR_WIDTH      (AXI_ADDR_WIDTH    [i]),
                .AXI_ID_W_WIDTH      (AXI_ID_W_WIDTH    [i]),
                .AXI_ID_R_WIDTH      (AXI_ID_R_WIDTH    [i]),

                .AXI_LD_FIFO_DEPTH   (AXI_LD_FIFO_DEPTH [i]),

                .PMU_METRIC_COUNT    (PMU_METRIC_COUNT  [i]),
                .PMU_DATA_WIDTH      (PMU_DATA_WIDTH    [i])
            ) u_testbed_axi_testenv_single (
                .clk_dma         (clk_dma           ),
                .rst_n_dma       (rst_n_dma         ),

                .command_data_i  (command_data_i [i]),
                .command_valid_i (command_valid_i[i]),
                .command_ready_o (command_ready_o[i]),

                .pmu_data_o      (pmu_data_o     [i]),
                .pmu_valid_o     (pmu_valid_o    [i]),
                .pmu_ready_i     (pmu_ready_i    [i]),

                .ld_start_i      (start_model    [i]),
                .ld_read_pmu_i   (read_pmu       [i]),
                .ld_idle_o       (ld_idle        [i]),
                .ld_finished_o   (ld_finished       ),
                .ld_rdata_o      (ld_rdata_loc      ),

                .clk_axi         (clk_axi),
                .rst_n_axi       (axi_resetn_synced),

                .m_axi_if_o      (u_axi_if)
            );

            mesh #(.AXI_DATA_WIDTH(AXI_DATA_WIDTH[i]),
                .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH[i]),
                .AXI_ID_W_WIDTH(AXI_ID_W_WIDTH[i]),
                .AXI_ID_R_WIDTH(AXI_ID_R_WIDTH[i]),
                .MAX_ROUTERS_X(3),
                .MAX_ROUTERS_Y(3),
                .VIRTUAL_CHANNEL_NUMBER(2),
                .VIRTUAL_NETWORKS('{1, 1}),
                //.ALGORITHM("EWn_SNe"),
                .BUFFER_ALLOCATOR("KeepInNetwork"),
                .SIMULTANIOUS_VIRTUAL_NETWORK_ROUTING(1)
            ) dut (
                .ACLK   (clk_axi          ),
                .ARESETn(axi_resetn_synced),

                .s_axi_i(u_axi_if         ),
                .m_axi_o(u_axi_if_ram     )
            );

            genvar j;
            for (j = 0; j < ROUTERS_COUNT[i]; j++) begin : rams
                axi_ram #(
                    .AXI_DATA_WIDTH (AXI_DATA_WIDTH[i]),
                    .AXI_ID_W_WIDTH (AXI_ID_W_WIDTH[i]),
                    .AXI_ID_R_WIDTH (AXI_ID_R_WIDTH[i]),
                    .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH[i])
                ) u_axi_ram (
                    .clk_i   (clk_axi          ),
                    .rst_n_i (axi_resetn_synced),
                    
                    .s_axi_i (u_axi_if_ram[j]  )
                );
            end
        end
    endgenerate

endmodule