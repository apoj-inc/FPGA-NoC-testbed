module tb_axi_testenv_multiple;


parameter     DMA_CHANNEL_COUNT                       = 1                      ;
parameter     EXT_FIFO_DATA_WIDTH                     = 128                    ;

parameter int ROUTERS_COUNT       [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{9 }};

parameter int AXI_DATA_WIDTH      [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{32}};
parameter int AXI_ADDR_WIDTH      [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{16}};
parameter int AXI_ID_W_WIDTH      [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{5 }};
parameter int AXI_ID_R_WIDTH      [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{5 }};

parameter int AXI_LD_FIFO_DEPTH   [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{64}};

parameter int PMU_METRIC_COUNT    [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{19}};
parameter int PMU_DATA_WIDTH      [DMA_CHANNEL_COUNT] = '{DMA_CHANNEL_COUNT{32}};

parameter int ROUTERS_ACTIVE [5] = '{7, 6, 4, 3, 0};

int fifo_counter;

apb4_intf     #(
    .DATA_WIDTH (128),
    .ADDR_WIDTH (32 )
) apb_apb_slave(), avalon_apb_slave();

avalon_mm_intf #(
    .DATA_WIDTH (128),
    .ADDR_WIDTH (32 )
) apb_avalon_slave(), avalon_avalon_slave();

logic test_done;

logic                           clk_dma                                 ;
logic                           rst_n_dma                               ;

logic                           clk_axi                                 ;

logic [EXT_FIFO_DATA_WIDTH-1:0] command_data_apb     [DMA_CHANNEL_COUNT];
logic                           command_valid_apb    [DMA_CHANNEL_COUNT];
logic                           command_ready_apb    [DMA_CHANNEL_COUNT];

logic [EXT_FIFO_DATA_WIDTH-1:0] pmu_data_apb         [DMA_CHANNEL_COUNT];
logic                           pmu_valid_apb        [DMA_CHANNEL_COUNT];
logic                           pmu_ready_apb        [DMA_CHANNEL_COUNT];

logic                           user_irq_apb         [DMA_CHANNEL_COUNT];

logic [EXT_FIFO_DATA_WIDTH-1:0] command_data_avalon  [DMA_CHANNEL_COUNT];
logic                           command_valid_avalon [DMA_CHANNEL_COUNT];
logic                           command_ready_avalon [DMA_CHANNEL_COUNT];

logic [EXT_FIFO_DATA_WIDTH-1:0] pmu_data_avalon      [DMA_CHANNEL_COUNT];
logic                           pmu_valid_avalon     [DMA_CHANNEL_COUNT];
logic                           pmu_ready_avalon     [DMA_CHANNEL_COUNT];

logic                           user_irq_avalon      [DMA_CHANNEL_COUNT];

always #4  clk_dma = ~clk_dma;
always #10 clk_axi = ~clk_axi;


testbed_axi_testenv_multiple #(
    .PLATFORM            ("Xilinx"           ),
    .DMA_CHANNEL_COUNT   (DMA_CHANNEL_COUNT  ),
    .EXT_FIFO_DATA_WIDTH (EXT_FIFO_DATA_WIDTH),

    .ROUTERS_COUNT       (ROUTERS_COUNT      ),

    .AXI_DATA_WIDTH      (AXI_DATA_WIDTH     ),
    .AXI_ADDR_WIDTH      (AXI_ADDR_WIDTH     ),
    .AXI_ID_W_WIDTH      (AXI_ID_W_WIDTH     ),
    .AXI_ID_R_WIDTH      (AXI_ID_R_WIDTH     ),

    .AXI_LD_FIFO_DEPTH   (AXI_LD_FIFO_DEPTH  ),

    .PMU_METRIC_COUNT    (PMU_METRIC_COUNT   ),
    .PMU_DATA_WIDTH      (PMU_DATA_WIDTH     )
) dut_xilinx (
    .clk_dma         (clk_dma  ),
    .rst_n_dma       (rst_n_dma),

    .command_data_i  (command_data_apb  ),
    .command_valid_i (command_valid_apb ),
    .command_ready_o (command_ready_apb ),

    .pmu_data_o      (pmu_data_apb      ),
    .pmu_valid_o     (pmu_valid_apb     ),
    .pmu_ready_i     (pmu_ready_apb     ),

    .apb_slave       (apb_apb_slave   ),
    .avalon_slave    (apb_avalon_slave),

    .user_irq_o      (user_irq_apb),

    .clk_axi         (clk_axi)
);


testbed_axi_testenv_multiple #(
    .PLATFORM            ("Altera"           ),
    .DMA_CHANNEL_COUNT   (DMA_CHANNEL_COUNT  ),
    .EXT_FIFO_DATA_WIDTH (EXT_FIFO_DATA_WIDTH),

    .ROUTERS_COUNT       (ROUTERS_COUNT      ),

    .AXI_DATA_WIDTH      (AXI_DATA_WIDTH     ),
    .AXI_ADDR_WIDTH      (AXI_ADDR_WIDTH     ),
    .AXI_ID_W_WIDTH      (AXI_ID_W_WIDTH     ),
    .AXI_ID_R_WIDTH      (AXI_ID_R_WIDTH     ),

    .AXI_LD_FIFO_DEPTH   (AXI_LD_FIFO_DEPTH  ),

    .PMU_METRIC_COUNT    (PMU_METRIC_COUNT   ),
    .PMU_DATA_WIDTH      (PMU_DATA_WIDTH     )
) dut_altera (
    .clk_dma         (clk_dma  ),
    .rst_n_dma       (rst_n_dma),

    .command_data_i  (command_data_avalon  ),
    .command_valid_i (command_valid_avalon ),
    .command_ready_o (command_ready_avalon ),

    .pmu_data_o      (pmu_data_avalon      ),
    .pmu_valid_o     (pmu_valid_avalon     ),
    .pmu_ready_i     (pmu_ready_avalon     ),

    .apb_slave       (avalon_apb_slave   ),
    .avalon_slave    (avalon_avalon_slave),

    .user_irq_o      (user_irq_avalon),

    .clk_axi         (clk_axi)
);

initial begin
    test_done = 0;
    fifo_counter = 0;

    clk_dma   = 1;
    clk_axi   = 1;
    rst_n_dma = 1;

    #5;
    rst_n_dma = 0;
    
    command_data_apb  = '{default: '0};
    command_valid_apb = '{default: '0};
    pmu_ready_apb     = '{default: '1};
    
    command_data_avalon  = '{default: '0};
    command_valid_avalon = '{default: '0};
    pmu_ready_avalon     = '{default: '1};

    apb_apb_slave.PSEL    = '0;
    apb_apb_slave.PENABLE = '0;
    avalon_avalon_slave.read  = '0;
    avalon_avalon_slave.write = '0;

    @(posedge clk_dma);
    rst_n_dma = 1;
    @(posedge clk_dma);

    apb_apb_slave.PSEL    = '1;
    apb_apb_slave.PENABLE = '0;
    apb_apb_slave.PWRITE  = '1;
    apb_apb_slave.PADDR   = '0;
    apb_apb_slave.PWDATA  = 1;
    apb_apb_slave.PSTRB   = 'h000F;
    @(posedge clk_dma);
    apb_apb_slave.PENABLE = '1;

    @(posedge clk_dma);
    while (!apb_apb_slave.PREADY) begin
        @(posedge clk_dma);
    end

    while (apb_apb_slave.PRDATA[1] != 1'b1) begin
        apb_apb_slave.PSEL    = '1;
        apb_apb_slave.PENABLE = '0;
        apb_apb_slave.PWRITE  = '0;
        apb_apb_slave.PADDR   = '0;
        apb_apb_slave.PWDATA  = 1;
        apb_apb_slave.PSTRB   = 'h000F;
        @(posedge clk_dma);
        apb_apb_slave.PENABLE = '1;

        @(posedge clk_dma);
        while (!apb_apb_slave.PREADY) begin
            @(posedge clk_dma);
        end
    end

    apb_apb_slave.PSEL    = '1;
    apb_apb_slave.PENABLE = '0;
    apb_apb_slave.PWRITE  = '1;
    apb_apb_slave.PADDR   = 'h10;
    apb_apb_slave.PWDATA  = 9'b011011001;
    apb_apb_slave.PSTRB   = 'h000F;
    @(posedge clk_dma);
    apb_apb_slave.PENABLE = '1;

    @(posedge clk_dma);
    while (!apb_apb_slave.PREADY) begin
        @(posedge clk_dma);
    end
    apb_apb_slave.PSEL    = '0;
    apb_apb_slave.PENABLE = '0;

    @(posedge clk_dma);

    for (int i = 0; i < 5; i++) begin
        for (int j = 0; j < 32; j++) begin
            command_data_apb[0]  = {8'(ROUTERS_ACTIVE[i]),
                                    8'b0,
                                    ((AXI_ID_W_WIDTH[0] / 8 + (AXI_ID_W_WIDTH[0] % 8 != 0)) * 8)'({$urandom_range(1, ROUTERS_COUNT[0])}),
                                    8'b1,
                                    ((AXI_ADDR_WIDTH[0] / 8 + (AXI_ADDR_WIDTH[0] % 8 != 0)) * 8)'({$urandom(), 2'b0}),
                                    8'($urandom_range(0, 255)),
                                    AXI_DATA_WIDTH[0]'($urandom()),
                                    8'h0F};
            command_valid_apb[0] = '1;
            @(posedge clk_dma);
            while (!command_ready_apb[0]) begin
                @(posedge clk_dma);
            end
        end
    
        for (int j = 0; j < 32; j++) begin
            command_data_apb[0]  = {8'(ROUTERS_ACTIVE[i]),                                                                          // channel_num
                                    8'b0,                                                                                           // resp_wait
                                    ((AXI_ID_W_WIDTH[0] / 8 + (AXI_ID_W_WIDTH[0] % 8 != 0)) * 8)'({$urandom_range(1, ROUTERS_COUNT[0])}), // axi_id
                                    8'b0,                                                                                           // axi_write
                                    ((AXI_ADDR_WIDTH[0] / 8 + (AXI_ADDR_WIDTH[0] % 8 != 0)) * 8)'({$urandom(), 2'b0}),              // axi_addr
                                    8'($urandom_range(0, 255)),                                                                     // axi_len
                                    AXI_DATA_WIDTH[0]'($urandom()),                                                                 // axi_wdata
                                    8'h0F};                                                                                         // axi_wstrb
            command_valid_apb[0] = '1;
            @(posedge clk_dma);
            while (!command_ready_apb[0]) begin
                @(posedge clk_dma);
            end
        end
    end
    command_valid_apb[0] = '0;
    @(posedge clk_dma);

    apb_apb_slave.PSEL    = '1;
    apb_apb_slave.PENABLE = '0;
    apb_apb_slave.PWRITE  = '1;
    apb_apb_slave.PADDR   = 'h0;
    apb_apb_slave.PWDATA  = 3'b101;
    apb_apb_slave.PSTRB   = 'h000F;
    @(posedge clk_dma);
    apb_apb_slave.PENABLE = '1;

    @(posedge clk_dma);
    while (!apb_apb_slave.PREADY) begin
        @(posedge clk_dma);
    end
    apb_apb_slave.PSEL    = '0;
    apb_apb_slave.PENABLE = '0;

    @(posedge user_irq_apb[0]);

    apb_apb_slave.PSEL    = '1;
    apb_apb_slave.PENABLE = '0;
    apb_apb_slave.PWRITE  = '1;
    apb_apb_slave.PADDR   = 'h0;
    apb_apb_slave.PWDATA  = 4'b1001;
    apb_apb_slave.PSTRB   = 'h000F;
    @(posedge clk_dma);
    apb_apb_slave.PENABLE = '1;

    @(posedge clk_dma);
    while (!apb_apb_slave.PREADY) begin
        @(posedge clk_dma);
    end
    apb_apb_slave.PSEL    = '0;
    apb_apb_slave.PENABLE = '0;

    while (fifo_counter != ROUTERS_COUNT[0]*((PMU_METRIC_COUNT[0] / (128 / PMU_DATA_WIDTH[0])) + ((PMU_METRIC_COUNT[0] % (128 / PMU_DATA_WIDTH[0])) != 0))) begin
        fifo_counter = fifo_counter + (pmu_valid_apb[0] & pmu_ready_apb[0]);
        @(posedge clk_dma);
    end

    apb_apb_slave.PSEL    = '1;
    apb_apb_slave.PENABLE = '0;
    apb_apb_slave.PWRITE  = '1;
    apb_apb_slave.PADDR   = 'h0;
    apb_apb_slave.PWDATA  = '0;
    apb_apb_slave.PSTRB   = 'h000F;
    @(posedge clk_dma);
    apb_apb_slave.PENABLE = '1;

    @(posedge clk_dma);
    while (!apb_apb_slave.PREADY) begin
        @(posedge clk_dma);
    end

    apb_apb_slave.PSEL    = '1;
    apb_apb_slave.PENABLE = '0;
    apb_apb_slave.PWRITE  = '1;
    apb_apb_slave.PADDR   = 'h0;
    apb_apb_slave.PWDATA  = 1'b1;
    apb_apb_slave.PSTRB   = 'h000F;
    @(posedge clk_dma);
    apb_apb_slave.PENABLE = '1;

    @(posedge clk_dma);
    while (!apb_apb_slave.PREADY) begin
        @(posedge clk_dma);
    end
    apb_apb_slave.PSEL    = '0;
    apb_apb_slave.PENABLE = '0;

    repeat (10) @(posedge clk_dma);

    assert (user_irq_apb[0] == 0) 
    else  $error("IRQ didn't deassert");

    repeat (10) @(posedge clk_dma);

    fifo_counter = 0;

    rst_n_dma = 1;

    #5;
    rst_n_dma = 0;
    
    command_data_apb  = '{default: '0};
    command_valid_apb = '{default: '0};
    pmu_ready_apb     = '{default: '1};
    
    command_data_avalon  = '{default: '0};
    command_valid_avalon = '{default: '0};
    pmu_ready_avalon     = '{default: '1};

    apb_apb_slave.PSEL    = '0;
    apb_apb_slave.PENABLE = '0;
    avalon_avalon_slave.read  = '0;
    avalon_avalon_slave.write = '0;

    @(posedge clk_dma);
    rst_n_dma = 1;
    @(posedge clk_dma);

    avalon_avalon_slave.write      = '1;
    avalon_avalon_slave.read       = '0;
    avalon_avalon_slave.address    = '0;
    avalon_avalon_slave.writedata  = 1;
    avalon_avalon_slave.byteenable = 'h000F;
    @(posedge clk_dma);
    while (avalon_avalon_slave.waitrequest) begin
        @(posedge clk_dma);
    end

    while (avalon_avalon_slave.readdata[1] != 1'b1) begin
        avalon_avalon_slave.write      = '0;
        avalon_avalon_slave.read       = '1;
        avalon_avalon_slave.address    = '0;
        avalon_avalon_slave.writedata  = 1;
        avalon_avalon_slave.byteenable = 'h000F;
        @(posedge clk_dma);
        while (avalon_avalon_slave.waitrequest) begin
            @(posedge clk_dma);
        end
        @(posedge clk_dma);
        while (!avalon_avalon_slave.readdatavalid) begin
            @(posedge clk_dma);
        end
    end

    avalon_avalon_slave.write      = '1;
    avalon_avalon_slave.read       = '0;
    avalon_avalon_slave.address    = 'h10 >> 4;
    avalon_avalon_slave.writedata  = 9'b011011001;
    avalon_avalon_slave.byteenable = 'h000F;
    @(posedge clk_dma);
    while (avalon_avalon_slave.waitrequest) begin
        @(posedge clk_dma);
    end
    avalon_avalon_slave.write      = '0;
    avalon_avalon_slave.read       = '0;

    @(posedge clk_dma);

    for (int i = 0; i < 5; i++) begin
        for (int j = 0; j < 32; j++) begin
            command_data_avalon[0]  = {8'(ROUTERS_ACTIVE[i]),
                                    8'b0,
                                    ((AXI_ID_W_WIDTH[0] / 8 + (AXI_ID_W_WIDTH[0] % 8 != 0)) * 8)'({$urandom_range(1, ROUTERS_COUNT[0])}),
                                    8'b1,
                                    ((AXI_ADDR_WIDTH[0] / 8 + (AXI_ADDR_WIDTH[0] % 8 != 0)) * 8)'({$urandom(), 2'b0}),
                                    8'($urandom_range(0, 255)),
                                    AXI_DATA_WIDTH[0]'($urandom()),
                                    8'h0F};
            command_valid_avalon[0] = '1;
            @(posedge clk_dma);
            while (!command_ready_avalon[0]) begin
                @(posedge clk_dma);
            end
        end
    
        for (int j = 0; j < 32; j++) begin
            command_data_avalon[0]  = {8'(ROUTERS_ACTIVE[i]),                                                                        // channel_num
                                    8'b0,                                                                                           // resp_wait
                                    ((AXI_ID_W_WIDTH[0] / 8 + (AXI_ID_W_WIDTH[0] % 8 != 0)) * 8)'({$urandom_range(1, ROUTERS_COUNT[0])}), // axi_id
                                    8'b0,                                                                                           // axi_write
                                    ((AXI_ADDR_WIDTH[0] / 8 + (AXI_ADDR_WIDTH[0] % 8 != 0)) * 8)'({$urandom(), 2'b0}),              // axi_addr
                                    8'($urandom_range(0, 255)),                                                                     // axi_len
                                    AXI_DATA_WIDTH[0]'($urandom()),                                                                 // axi_wdata
                                    8'h0F};                                                                                         // axi_wstrb
            command_valid_avalon[0] = '1;
            @(posedge clk_dma);
            while (!command_ready_avalon[0]) begin
                @(posedge clk_dma);
            end
        end
    end
    command_valid_avalon[0] = '0;
    @(posedge clk_dma);

    avalon_avalon_slave.write      = '1;
    avalon_avalon_slave.read       = '0;
    avalon_avalon_slave.address    = '0;
    avalon_avalon_slave.writedata  = 3'b101;
    avalon_avalon_slave.byteenable = 'h000F;
    @(posedge clk_dma);
    while (avalon_avalon_slave.waitrequest) begin
        @(posedge clk_dma);
    end
    avalon_avalon_slave.write      = '0;
    avalon_avalon_slave.read       = '0;

    @(posedge user_irq_avalon[0]);

    avalon_avalon_slave.write      = '1;
    avalon_avalon_slave.read       = '0;
    avalon_avalon_slave.address    = '0;
    avalon_avalon_slave.writedata  = 4'b1001;
    avalon_avalon_slave.byteenable = 'h000F;
    @(posedge clk_dma);
    while (avalon_avalon_slave.waitrequest) begin
        @(posedge clk_dma);
    end
    avalon_avalon_slave.write      = '0;
    avalon_avalon_slave.read       = '0;

    while (fifo_counter != ROUTERS_COUNT[0]*((PMU_METRIC_COUNT[0] / (128 / PMU_DATA_WIDTH[0])) + ((PMU_METRIC_COUNT[0] % (128 / PMU_DATA_WIDTH[0])) != 0))) begin
        fifo_counter = fifo_counter + (pmu_valid_avalon[0] & pmu_ready_avalon[0]);
        @(posedge clk_dma);
    end

    avalon_avalon_slave.write      = '1;
    avalon_avalon_slave.read       = '0;
    avalon_avalon_slave.address    = '0;
    avalon_avalon_slave.writedata  = 1'b0;
    avalon_avalon_slave.byteenable = 'h000F;
    @(posedge clk_dma);
    while (avalon_avalon_slave.waitrequest) begin
        @(posedge clk_dma);
    end

    avalon_avalon_slave.write      = '1;
    avalon_avalon_slave.read       = '0;
    avalon_avalon_slave.address    = '0;
    avalon_avalon_slave.writedata  = 1'b1;
    avalon_avalon_slave.byteenable = 'h000F;
    @(posedge clk_dma);
    while (avalon_avalon_slave.waitrequest) begin
        @(posedge clk_dma);
    end
    avalon_avalon_slave.write      = '0;
    avalon_avalon_slave.read       = '0;

    repeat (10) @(posedge clk_dma);

    assert (user_irq_avalon[0] == 0) 
    else  $error("IRQ didn't deassert");

    repeat (10) @(posedge clk_dma);

    test_done = 1;
end

endmodule