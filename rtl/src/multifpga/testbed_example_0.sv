module testbed_example_0 (
    input  logic clk_100m     ,

    input  logic aurora_clk_p ,
    input  logic aurora_clk_n ,

    input  logic aurora_rx_p  ,
    input  logic aurora_rx_n  ,
    input  logic aurora_tx_p  ,
    input  logic aurora_tx_n  ,

    output logic clk_gated_o  ,
    output logic clk_ungated_o,
    output logic clken0_o     ,
    input  logic clken1_i     
);
    logic        pma_init;
    logic        reset_pb;

    logic        user_clk;
    logic        sys_rst ;

    logic        tx_valid;
    logic        tx_ready;
    logic [63:0] tx_data ;

    logic        rx_valid;
    logic [63:0] rx_data ;

    logic [31:0] counter = '0;

    assign pma_init = counter < 100;
    assign reset_pb = counter < 150;

    always_ff @(posedge clk_100m) begin : blockName
        counter <= (counter == 150) ? counter : counter + 1;
    end

    logic [31:0] slowclk_counter = '0;
    logic        slowclk_gated       ;
    logic        slowclk_ungated     ;

    always_ff @(posedge clk_100m) begin
        slowclk_counter <= slowclk_counter + 1;
    end

    logic [31:0] transfer_counter_send = '0;
    logic [31:0] transfer_counter_recv     ;

    always_ff @(posedge slowclk_gated) begin
        transfer_counter_send <= transfer_counter_send + 1;
    end

    kdma_aurora_64b66b_0 u_aurora (
        .pma_init          (pma_init    ),
        .reset_pb          (reset_pb    ),

        .drp_clk_in        (clk_100m    ),
        .init_clk          (clk_100m    ),

        .gt_refclk1_p      (aurora_clk_p),
        .gt_refclk1_n      (aurora_clk_n),

        .rxp               (aurora_rx_p ),
        .rxn               (aurora_rx_n ),
        .txp               (aurora_tx_p ),
        .txn               (aurora_tx_n ),

        .user_clk_out      (user_clk ),
        .sys_reset_out     (sys_rst  ),

        .s_axi_tx_tvalid   (tx_valid ),
        .s_axi_tx_tready   (tx_ready ),
        .s_axi_tx_tdata    (tx_data  ),

        .m_axi_rx_tvalid   (rx_valid ),
        .m_axi_rx_tdata    (rx_data  ),

        .s_axi_awaddr      ('0       ),
        .s_axi_araddr      ('0       ),
        .s_axi_wdata       ('0       ),
        .s_axi_wstrb       ('0       ),
        .s_axi_awvalid     ('0       ),
        .s_axi_rready      ('1       ),
        .s_axi_bready      ('1       ),
        .s_axi_arvalid     ('0       ),
        .s_axi_wvalid      ('0       ),

        .gt_rxcdrovrden_in ('0       ),
        .power_down        ('0       ),
        .loopback          ('0       )
    );

    BUFG slowclk_buf (.I(slowclk_counter[8]), .O(slowclk_ungated));
    BUFGCE slowclk_gated_buf (.I(slowclk_counter[8]), .O(slowclk_gated), .CE(clken0_o | clken1_i));

    testbed_multifpga_cont #(
        .INPUT_WIDTH  (32),
        .OUTPUT_WIDTH (32),
        .TXRX_WIDTH   (64)
    ) u_testbed_multifpga_cont (
        .signal_clk_i        (slowclk_ungated      ),
        .signal_rstn_i       (sys_rst              ),

        .signal_clk_enable_o (clken0_o             ),

        .input_i             (transfer_counter_send),
        .output_o            (transfer_counter_recv),


        .txrx_clk_i          (user_clk             ),
        .txrx_rstn_i         (sys_rst              ),

        .aur_tx_valid_o      (tx_valid             ),
        .aur_tx_ready_i      (tx_ready             ),
        .aur_tx_data_o       (tx_data              ),

        .aur_rx_valid_i      (rx_valid             ),
        .aur_rx_data_i       (rx_data              )
    );

    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) ungated (
        .Q (clk_gated_o     ),
        .C (slowclk_ungated ),
        .CE(1'b1            ),
        .D1(1'b0            ),
        .D2(1'b1            ),
        .R (1'b0            ),
        .S (1'b0            ) 
    );

    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) gated (
        .Q (clk_gated_o   ),
        .C (slowclk_gated ),
        .CE(1'b1          ),
        .D1(1'b1          ),
        .D2(1'b0          ),
        .R (1'b0          ),
        .S (1'b0          ) 
    );


    kdma_ila_0 u_ila_aurora (
        .clk    (user_clk ),

        .probe0 ('0      ),
        .probe1 ('0      ),
        .probe2 ('0      ),
        .probe3 (sys_rst ),
        .probe4 (tx_valid),
        .probe5 (tx_ready),
        .probe6 (tx_data ),
        .probe7 (rx_valid),
        .probe8 (rx_data ),
        .probe9 ('0      ),

        .trig_out     (  ),
        .trig_out_ack ('1),
        .trig_in      ('0),
        .trig_in_ack  (  )
    );

    kdma_ila_0 u_ila_sys (
        .clk    (slowclk_gated        ),

        .probe0 ('0                   ),
        .probe1 ('0                   ),
        .probe2 ('0                   ),
        .probe3 ('0                   ),
        .probe4 ('0                   ),
        .probe5 ('0                   ),
        .probe6 (transfer_counter_send),
        .probe7 ('0                   ),
        .probe8 (transfer_counter_recv),
        .probe9 ('0                   ),

        .trig_out     (  ),
        .trig_out_ack ('1),
        .trig_in      ('0),
        .trig_in_ack  (  )
    );
    
endmodule