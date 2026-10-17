`include "axi_defines.svh"

module axi_testenv_multiple #(
    parameter     CPUIF                                   = "Avalon"               ,
    parameter     DMA_CHANNEL_COUNT                       = 8                      ,
    parameter     EXT_FIFO_DATA_WIDTH                     = 128                    ,

    parameter int ROUTERS_COUNT       [DMA_CHANNEL_COUNT] = {DMA_CHANNEL_COUNT{16}},

    parameter int AXI_DATA_WIDTH      [DMA_CHANNEL_COUNT] = {DMA_CHANNEL_COUNT{32}},
    parameter int AXI_ADDR_WIDTH      [DMA_CHANNEL_COUNT] = {DMA_CHANNEL_COUNT{16}},
    parameter int AXI_ID_W_WIDTH      [DMA_CHANNEL_COUNT] = {DMA_CHANNEL_COUNT{5 }},
    parameter int AXI_ID_R_WIDTH      [DMA_CHANNEL_COUNT] = {DMA_CHANNEL_COUNT{5 }},

    parameter int AXI_LD_FIFO_DEPTH   [DMA_CHANNEL_COUNT] = {DMA_CHANNEL_COUNT{64}},

    parameter int PMU_METRIC_COUNT    [DMA_CHANNEL_COUNT] = {DMA_CHANNEL_COUNT{19}},
    parameter int PMU_DATA_WIDTH      [DMA_CHANNEL_COUNT] = {DMA_CHANNEL_COUNT{32}}
) (
    input  logic                           clk_dma                            ,
    input  logic                           rst_n_dma                          ,

    input  logic [EXT_FIFO_DATA_WIDTH-1:0] command_data_i  [DMA_CHANNEL_COUNT],
    input  logic                           command_valid_i [DMA_CHANNEL_COUNT],
    output logic                           command_ready_o [DMA_CHANNEL_COUNT],

    output logic [EXT_FIFO_DATA_WIDTH-1:0] pmu_data_o      [DMA_CHANNEL_COUNT],
    output logic                           pmu_valid_o     [DMA_CHANNEL_COUNT],
    input  logic                           pmu_ready_i     [DMA_CHANNEL_COUNT],

    apb4_intf.s                            apb_slave                          ,
    avalon_mm_intf.s                       avalon_slave                       ,

    output logic                           user_irq_o      [DMA_CHANNEL_COUNT],

    input  logic                           clk_axi                            
);

    generate
        genvar i;

        for (i = 0; i < DMA_CHANNEL_COUNT; i++) begin

            axi_if #(
                .AXI_DATA_WIDTH (AXI_DATA_WIDTH[i]),
                .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH[i]),
                .AXI_ID_W_WIDTH (AXI_ID_W_WIDTH[i]),
                .AXI_ID_R_WIDTH (AXI_ID_R_WIDTH[i])
            ) u_axi_if[ROUTERS_COUNT[i]](), u_axi_if_ram[ROUTERS_COUNT[i]]();

            axi_testenv_single #(
                .EXT_FIFO_DATA_WIDTH (EXT_FIFO_DATA_WIDTH  ),

                .ROUTERS_COUNT       (ROUTERS_COUNT     [i]),

                .AXI_DATA_WIDTH      (AXI_DATA_WIDTH    [i]),
                .AXI_ADDR_WIDTH      (AXI_ADDR_WIDTH    [i]),
                .AXI_ID_W_WIDTH      (AXI_ID_W_WIDTH    [i]),
                .AXI_ID_R_WIDTH      (AXI_ID_R_WIDTH    [i]),

                .AXI_LD_FIFO_DEPTH   (AXI_LD_FIFO_DEPTH [i]),

                .PMU_METRIC_COUNT    (PMU_METRIC_COUNT  [i]),
                .PMU_DATA_WIDTH      (PMU_DATA_WIDTH    [i]),
            ) (
                .clk_dma         (clk_dma        ),
                .rst_n_dma       (rst_n_dma      ),

                .command_data_i  (command_data_i ),
                .command_valid_i (command_valid_i),
                .command_ready_o (command_ready_o),

                .pmu_data_o      (pmu_data_o     ),
                .pmu_valid_o     (pmu_valid_o    ),
                .pmu_ready_i     (pmu_ready_i    ),

                input  logic                           ld_start_i                     ,
                input  logic                           ld_read_pmu_i                  ,
                output logic [ROUTERS_COUNT-1:0]       ld_idle_o                      ,
                output logic [ROUTERS_COUNT-1:0]       ld_finished_o                  ,
                output logic [AXI_DATA_WIDTH-1:0]      ld_rdata_o      [ROUTERS_COUNT],

                .clk_axi         (clk_axi),
                input  logic                           rst_n_axi                      ,

                .m_axi_if_o      (u_axi_if),
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
                .ACLK   (clk_axi     ),
                .ARESETn(  ), // TODO

                .s_axi_i(u_axi_if    ),
                .m_axi_o(u_axi_if_ram)
            );

            genvar j;
            for (j = 0; j < ROUTERS_COUNT[i]; j++) begin : rams
                axi_ram #(
                    .AXI_DATA_WIDTH (AXI_DATA_WIDTH[i]),
                    .AXI_ID_W_WIDTH (AXI_ID_W_WIDTH[i]),
                    .AXI_ID_R_WIDTH (AXI_ID_R_WIDTH[i]),
                    .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH[i])
                ) u_axi_ram (
                    .clk_i   (clk_axi    ),
                    .rst_n_i (  ), // TODO
                    
                    .s_axi_i (u_axi_if_ram[j])
                );
            end
        end
    endgenerate

endmodule