module testbed_altera #(
    parameter     DMA_CHANNEL_COUNT                       = 1                        ,

    parameter     DMA_BYTES_WIDTH                         = 22                       ,
    parameter     DMA_OFFFSET_WIDTH                       = 22                       ,

    parameter int DMA_WORD_BYTES      [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{16 }},
    parameter int DMA_WQ_DEPTH        [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{64 }},
    parameter int DMA_RQ_DEPTH        [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{64 }},
    parameter     DMA_TQ_DEPTH                            = 8                        ,

    parameter     MAX_WQ_DEPTH                            = 64                       ,
    parameter     MAX_RQ_DEPTH                            = 64                       ,

    parameter int ROUTERS_COUNT       [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{9 }} ,
    parameter int AXI_DATA_WIDTH      [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{32}} ,
    parameter int AXI_ADDR_WIDTH      [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{12}} ,
    parameter int AXI_ID_W_WIDTH      [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{5 }} ,
    parameter int AXI_ID_R_WIDTH      [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{5 }} ,
    parameter int AXI_LD_FIFO_DEPTH   [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{64}} ,
    parameter int PMU_METRIC_COUNT    [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{19}} ,
    parameter int PMU_DATA_WIDTH      [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{32}} ,

    parameter DMA_WQ_ADDR_WIDTH = $clog2(MAX_WQ_DEPTH),
    parameter DMA_RQ_ADDR_WIDTH = $clog2(MAX_RQ_DEPTH)
) (
    output logic       FAN_CTRL     ,

    input  logic       PCIE_PERST_n ,
    input  logic       PCIE_REFCLK_p,
    input  logic [3:0] PCIE_RX_p    ,
    output logic [3:0] PCIE_TX_p    
);

    logic                         dma_wrdata_valid_rd     [DMA_CHANNEL_COUNT];
    logic                         dma_wrdata_ready_rd     [DMA_CHANNEL_COUNT];
    logic [DMA_WQ_ADDR_WIDTH:0]   dma_wrdata_count_rd     [DMA_CHANNEL_COUNT];
    logic [127:0]                 dma_wrdata_data_rd      [DMA_CHANNEL_COUNT];

    logic                         dma_rddata_valid_wr     [DMA_CHANNEL_COUNT];
    logic                         dma_rddata_ready_wr     [DMA_CHANNEL_COUNT];
    logic [DMA_RQ_ADDR_WIDTH:0]   dma_rddata_free_wr      [DMA_CHANNEL_COUNT];
    logic [127:0]                 dma_rddata_data_wr      [DMA_CHANNEL_COUNT];

    logic                         env_csr_m_chipselect                       ;
    logic [15:0]                  env_csr_m_byteenable                       ;
    logic [127:0]                 env_csr_m_readdata                         ;
    logic [127:0]                 env_csr_m_writedata                        ;
    logic                         env_csr_m_read                             ;
    logic                         env_csr_m_write                            ;
    logic                         env_csr_m_readdatavalid                    ;
    logic                         env_csr_m_waitrequest                      ;
    logic [12:0]                  env_csr_m_address                          ;

    logic [DMA_CHANNEL_COUNT-1:0] user_irq                                   ;

    logic                         dma_clk                                    ;
    logic                         dma_resetn                                 ;
    logic                         pcie_resetn                                ;

    logic                         pll_50mhz_clk                              ;

    logic                         dma_wrdata_valid_wr     [DMA_CHANNEL_COUNT];
    logic                         dma_wrdata_ready_wr     [DMA_CHANNEL_COUNT];
    logic [127:0]                 dma_wrdata_data_wr      [DMA_CHANNEL_COUNT];

    logic                         dma_rddata_valid_rd     [DMA_CHANNEL_COUNT];
    logic                         dma_rddata_ready_rd     [DMA_CHANNEL_COUNT];
    logic [127:0]                 dma_rddata_data_rd      [DMA_CHANNEL_COUNT];

    apb4_intf #(
        .DATA_WIDTH(128),
        .ADDR_WIDTH(13 )
    ) apb();

    avalon_mm_intf #(
        .DATA_WIDTH(128),
        .ADDR_WIDTH(9  )
    ) avalon();

    always_comb begin
        apb.PSEL    = '0;
        apb.PENABLE = '0;

        avalon.read       = env_csr_m_read        ;
        avalon.write      = env_csr_m_write       ;
        avalon.address    = env_csr_m_address >> 4; // Byte addressing to Word addressing
        avalon.writedata  = env_csr_m_writedata   ; 
        avalon.byteenable = env_csr_m_byteenable  ; 

        env_csr_m_waitrequest   = avalon.waitrequest       ;
        env_csr_m_readdatavalid = avalon.readdatavalid     ;
        env_csr_m_readdata      = avalon.readdata          ;
    end

    avmm_dma_toplevel #(
        .DMA_CHANNEL_COUNT (DMA_CHANNEL_COUNT ),

        .DMA_BYTES_WIDTH   (DMA_BYTES_WIDTH   ),
        .DMA_OFFFSET_WIDTH (DMA_OFFFSET_WIDTH ),

        .DMA_WORD_BYTES    (DMA_WORD_BYTES    ),
        .DMA_WQ_DEPTH      (DMA_WQ_DEPTH      ),
        .DMA_RQ_DEPTH      (DMA_RQ_DEPTH      ),
        .DMA_TQ_DEPTH      (DMA_TQ_DEPTH      ),

        .MAX_WQ_DEPTH      (MAX_WQ_DEPTH      ),
        .MAX_RQ_DEPTH      (MAX_RQ_DEPTH      )
    ) u_avmm_dma_toplevel (

        .FAN_CTRL                (FAN_CTRL               ),

        .PCIE_PERST_n            (PCIE_PERST_n           ),
        .PCIE_REFCLK_p           (PCIE_REFCLK_p          ),
        .PCIE_RX_p               (PCIE_RX_p              ),
        .PCIE_TX_p               (PCIE_TX_p              ),

        .dma_wrdata_valid_i      (dma_wrdata_valid_rd    ),
        .dma_wrdata_ready_o      (dma_wrdata_ready_rd    ),
        .dma_wrdata_count_i      (dma_wrdata_count_rd    ),
        .dma_wrdata_data_i       (dma_wrdata_data_rd     ),

        .dma_rddata_valid_o      (dma_rddata_valid_wr    ),
        .dma_rddata_ready_i      (dma_rddata_ready_wr    ),
        .dma_rddata_free_i       (dma_rddata_free_wr     ),
        .dma_rddata_data_o       (dma_rddata_data_wr     ),

        
        .env_csr_m_chipselect    (env_csr_m_chipselect   ),
        .env_csr_m_byteenable    (env_csr_m_byteenable   ),
        .env_csr_m_readdata      (env_csr_m_readdata     ),
        .env_csr_m_writedata     (env_csr_m_writedata    ),
        .env_csr_m_read          (env_csr_m_read         ),
        .env_csr_m_write         (env_csr_m_write        ),
        .env_csr_m_readdatavalid (env_csr_m_readdatavalid),
        .env_csr_m_waitrequest   (env_csr_m_waitrequest  ),
        .env_csr_m_address       (env_csr_m_address      ),

        .user_irq_i              (user_irq               ),

        .dma_clk_o               (dma_clk                ),
        .dma_resetn_o            (dma_resetn             ),
        .pcie_resetn_o           (pcie_resetn            ),

        .pll_50mhz_clk_o         (pll_50mhz_clk          )
    );

    generate
        genvar i;

        for (i = 0; i < DMA_CHANNEL_COUNT; i++) begin : connect_fifos

            stream_fifo #(
                .DATA_WIDTH (128            ),
                .FIFO_DEPTH (DMA_RQ_DEPTH[i])
            ) fifo_rd (
                .ACLK    (dma_clk               ),
                .ARESETn (dma_resetn            ),

                .data_i  (dma_rddata_data_wr [i]),
                .valid_i (dma_rddata_valid_wr[i]),
                .ready_o (dma_rddata_ready_wr[i]),
                .free_o  (dma_rddata_free_wr [i]),

                .data_o  (dma_rddata_data_rd [i]),
                .valid_o (dma_rddata_valid_rd[i]),
                .ready_i (dma_rddata_ready_rd[i]),
                .count_o (                      )
            );

            stream_fifo #(
                .DATA_WIDTH (128            ),
                .FIFO_DEPTH (DMA_WQ_DEPTH[i])
            ) fifo_wr (
                .ACLK    (dma_clk               ),
                .ARESETn (dma_resetn            ),

                .data_i  (dma_wrdata_data_wr [i]),
                .valid_i (dma_wrdata_valid_wr[i]),
                .ready_o (dma_wrdata_ready_wr[i]),
                .free_o  (                      ),

                .data_o  (dma_wrdata_data_rd [i]),
                .valid_o (dma_wrdata_valid_rd[i]),
                .ready_i (dma_wrdata_ready_rd[i]),
                .count_o (dma_wrdata_count_rd[i])
            );
        end
    endgenerate

    testbed_axi_testenv_multiple #(
        .PLATFORM            ("Altera"         ),
        .DMA_CHANNEL_COUNT   (DMA_CHANNEL_COUNT),
        .EXT_FIFO_DATA_WIDTH (128              ),

        .ROUTERS_COUNT       (ROUTERS_COUNT    ),

        .AXI_DATA_WIDTH      (AXI_DATA_WIDTH   ),
        .AXI_ADDR_WIDTH      (AXI_ADDR_WIDTH   ),
        .AXI_ID_W_WIDTH      (AXI_ID_W_WIDTH   ),
        .AXI_ID_R_WIDTH      (AXI_ID_R_WIDTH   ),

        .AXI_LD_FIFO_DEPTH   (AXI_LD_FIFO_DEPTH),

        .PMU_METRIC_COUNT    (PMU_METRIC_COUNT ),
        .PMU_DATA_WIDTH      (PMU_DATA_WIDTH   )
    ) u_testbed_axi_testenv_multiple (
        .clk_dma         (dma_clk            ),
        .rst_n_dma       (dma_resetn         ),

        .command_data_i  (dma_rddata_data_rd ),
        .command_valid_i (dma_rddata_valid_rd),
        .command_ready_o (dma_rddata_ready_rd),

        .pmu_data_o      (dma_wrdata_data_wr ),
        .pmu_valid_o     (dma_wrdata_valid_wr),
        .pmu_ready_i     (dma_wrdata_ready_wr),

        .apb_slave       (apb                ),
        .avalon_slave    (avalon             ),

        .user_irq_o      (user_irq           ),

        .clk_axi         (pll_50mhz_clk      )                   
    );
endmodule