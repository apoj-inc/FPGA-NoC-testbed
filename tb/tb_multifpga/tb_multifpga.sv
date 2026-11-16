module tb_multifpga;

parameter FIFO_COUNT = 8 ;
parameter FIFO_DW    = 32;

logic test_done;

logic aur_clk, aur_rstn;
logic signal_clk, signal_rstn;
logic signal_clk_gated;
logic left_signal_clken, right_signal_clken;

always #10 aur_clk = ~aur_clk;
always #37 signal_clk = ~signal_clk;

logic clksel;

always_ff @(negedge signal_clk or negedge signal_rstn) begin : blockName
    if (!signal_rstn) begin
        clksel <= '1;
    end
    else begin
        clksel <= left_signal_clken && right_signal_clken ? '1 : '0;
    end
end

assign signal_clk_gated = clksel ? signal_clk : '0;

logic [FIFO_COUNT-1:0]         left_fifo_valid_rd;
logic [FIFO_COUNT-1:0]         left_fifo_ready_rd;
logic [FIFO_COUNT*FIFO_DW-1:0] left_fifo_data_rd ;

logic [FIFO_COUNT-1:0]         right_fifo_valid_wr;
logic [FIFO_COUNT-1:0]         right_fifo_ready_wr;
logic [FIFO_COUNT*FIFO_DW-1:0] right_fifo_data_wr ;


logic [FIFO_COUNT-1:0]         right_fifo_valid_rd;
logic [FIFO_COUNT-1:0]         right_fifo_ready_rd;
logic [FIFO_COUNT*FIFO_DW-1:0] right_fifo_data_rd ;

logic [FIFO_COUNT-1:0]         left_fifo_valid_wr;
logic [FIFO_COUNT-1:0]         left_fifo_ready_wr;
logic [FIFO_COUNT*FIFO_DW-1:0] left_fifo_data_wr ;

generate
    for (genvar i = 0; i < FIFO_COUNT; i++) begin : left_fifo
        logic               valid_wr;
        logic               ready_wr;
        logic [FIFO_DW-1:0] data_wr ;

        stream_fifo #(
            .DATA_WIDTH (FIFO_DW),
            .FIFO_DEPTH (4      )
        ) u_stream_fifo (
            .ACLK    (signal_clk_gated                        ),
            .ARESETn (signal_rstn                             ),
            
            .data_i  (data_wr                                 ),
            .valid_i (valid_wr                                ),
            .ready_o (ready_wr                                ),
            .free_o  (                                        ),

            .data_o  (left_fifo_data_rd [i*FIFO_DW +: FIFO_DW]),
            .valid_o (left_fifo_valid_rd[i]                   ),
            .ready_i (left_fifo_ready_rd[i]                   ),
            .count_o (                                        )
        );

        initial begin
            u_stream_fifo.fifo_mem = '{'0, '0, '0, '0};
            u_stream_fifo.data_o   = '0;
        end

        always_ff @(posedge signal_clk_gated or negedge signal_rstn) begin
            if (!signal_rstn) begin
                valid_wr <= '0        ;
                data_wr  <= $urandom();
            end
            else begin
                if (valid_wr && !ready_wr) begin
                    valid_wr <= valid_wr;
                end
                else begin
                    valid_wr <= $urandom_range(0, 9) == 9 ? '1 : '0;
                end

                if (valid_wr && ready_wr) begin
                    data_wr <= $urandom();
                end
            end
        end

        always_ff @(posedge signal_clk_gated or negedge signal_rstn) begin
            if (!signal_rstn) begin
                left_fifo_ready_wr[i] <= '0;
            end
            else begin
                left_fifo_ready_wr[i] <= $urandom_range(0, 9) == 9 ? $urandom() : left_fifo_ready_wr[i];
            end
        end
    end

    for (genvar i = 0; i < FIFO_COUNT; i++) begin : right_fifo
        logic               valid_wr;
        logic               ready_wr;
        logic [FIFO_DW-1:0] data_wr ;

        stream_fifo #(
            .DATA_WIDTH (FIFO_DW),
            .FIFO_DEPTH (4      )
        ) u_stream_fifo (
            .ACLK    (signal_clk_gated                         ),
            .ARESETn (signal_rstn                              ),
            
            .data_i  (data_wr                                  ),
            .valid_i (valid_wr                                 ),
            .ready_o (ready_wr                                 ),
            .free_o  (                                         ),

            .data_o  (right_fifo_data_rd [i*FIFO_DW +: FIFO_DW]),
            .valid_o (right_fifo_valid_rd[i]                   ),
            .ready_i (right_fifo_ready_rd[i]                   ),
            .count_o (                                         )
        );

        initial begin
            u_stream_fifo.fifo_mem = '{'0, '0, '0, '0};
            u_stream_fifo.data_o   = '0;
        end

        always_ff @(posedge signal_clk_gated or negedge signal_rstn) begin
            if (!signal_rstn) begin
                valid_wr <= '0        ;
                data_wr  <= $urandom();
            end
            else begin
                if (valid_wr && !ready_wr) begin
                    valid_wr <= valid_wr;
                end
                else begin
                    valid_wr <= $urandom_range(0, 9) == 9 ? '1 : '0;
                end

                if (valid_wr && ready_wr) begin
                    data_wr <= $urandom();
                end
            end
        end

        always_ff @(posedge signal_clk_gated or negedge signal_rstn) begin
            if (!signal_rstn) begin
                right_fifo_ready_wr[i] <= '0;
            end
            else begin
                right_fifo_ready_wr[i] <= $urandom_range(0, 9) == 9 ? $urandom() : right_fifo_ready_wr[i];
            end
        end
    end
endgenerate


logic        left_aur_tx_valid_o;
logic        left_aur_tx_ready_i;
logic [63:0] left_aur_tx_data_o ;

logic        right_aur_tx_valid_o;
logic        right_aur_tx_ready_i;
logic [63:0] right_aur_tx_data_o ;

logic        ltr_aur_layer_valid [8];
logic [63:0] ltr_aur_layer_data  [8];

logic        rtl_aur_layer_valid [8];
logic [63:0] rtl_aur_layer_data  [8];

always_ff @(posedge aur_clk or negedge aur_rstn) begin
    if (!aur_rstn) begin
        left_aur_tx_ready_i  <= '0;
        right_aur_tx_ready_i <= '0;
    end
    else begin
        left_aur_tx_ready_i  <= $urandom_range(0, 9) == 9 ? '0 : '1;
        right_aur_tx_ready_i <= $urandom_range(0, 9) == 9 ? '0 : '1;
    end
end

testbed_multifpga_cont #(
    .INPUT_WIDTH  (FIFO_COUNT + FIFO_COUNT*FIFO_DW + FIFO_COUNT),
    .OUTPUT_WIDTH (FIFO_COUNT + FIFO_COUNT*FIFO_DW + FIFO_COUNT),
    .TXRX_WIDTH   (64                                          )
) left_dut (
    .signal_clk_i  (signal_clk ),
    .signal_rstn_i (signal_rstn),

    .signal_clk_enable_o (left_signal_clken),

    .input_i  ({left_fifo_valid_rd, left_fifo_data_rd, left_fifo_ready_wr}),
    .output_o ({left_fifo_valid_wr, left_fifo_data_wr, left_fifo_ready_rd}),


    .txrx_clk_i     (aur_clk            ),
    .txrx_rstn_i    (aur_rstn           ),

    .aur_tx_valid_o (left_aur_tx_valid_o),
    .aur_tx_ready_i (left_aur_tx_ready_i),
    .aur_tx_data_o  (left_aur_tx_data_o ),

    .aur_rx_valid_i (rtl_aur_layer_valid[7]),
    .aur_rx_data_i  (rtl_aur_layer_data [7])
);

always_ff @(posedge aur_clk or negedge aur_rstn) begin
    if (!aur_rstn) begin
        ltr_aur_layer_valid <= '{default: '0};
        ltr_aur_layer_data  <= '{default: '0};

        rtl_aur_layer_valid <= '{default: '0};
        rtl_aur_layer_data  <= '{default: '0};
    end
    else begin
        ltr_aur_layer_valid[0] <= left_aur_tx_ready_i ? left_aur_tx_valid_o : '0;
        ltr_aur_layer_data [0] <= left_aur_tx_ready_i ? left_aur_tx_data_o  : '0;

        rtl_aur_layer_valid[0] <= right_aur_tx_ready_i ? right_aur_tx_valid_o : '0;
        rtl_aur_layer_data [0] <= right_aur_tx_ready_i ? right_aur_tx_data_o  : '0;

        for (int i = 1; i < 8; i++) begin
            ltr_aur_layer_valid[i] <= ltr_aur_layer_valid[i-1];
            ltr_aur_layer_data [i] <= ltr_aur_layer_data [i-1];

            rtl_aur_layer_valid[i] <= rtl_aur_layer_valid[i-1];
            rtl_aur_layer_data [i] <= rtl_aur_layer_data [i-1];
        end
    end
end

testbed_multifpga_cont #(
    .INPUT_WIDTH  (FIFO_COUNT + FIFO_COUNT*FIFO_DW + FIFO_COUNT),
    .OUTPUT_WIDTH (FIFO_COUNT + FIFO_COUNT*FIFO_DW + FIFO_COUNT),
    .TXRX_WIDTH   (64                                          )
) right_dut (
    .signal_clk_i  (signal_clk ),
    .signal_rstn_i (signal_rstn),

    .signal_clk_enable_o (right_signal_clken),

    .input_i  ({right_fifo_valid_rd, right_fifo_data_rd, right_fifo_ready_wr}),
    .output_o ({right_fifo_valid_wr, right_fifo_data_wr, right_fifo_ready_rd}),


    .txrx_clk_i     (aur_clk            ),
    .txrx_rstn_i    (aur_rstn           ),

    .aur_tx_valid_o (right_aur_tx_valid_o),
    .aur_tx_ready_i (right_aur_tx_ready_i),
    .aur_tx_data_o  (right_aur_tx_data_o ),

    .aur_rx_valid_i (ltr_aur_layer_valid[7]),
    .aur_rx_data_i  (ltr_aur_layer_data [7])
);

initial begin
    test_done = '0;
    signal_clk = '1;
    aur_clk = '1;

    #3;
    aur_rstn = '0;
    signal_rstn = '0;

    fork
        begin   
            @(posedge aur_clk);
            aur_rstn = '1;
        end
        begin
            @(posedge signal_clk);
            signal_rstn = '1;
        end
    join

    repeat (1000) @(posedge signal_clk_gated);

    test_done = '1;

end

endmodule