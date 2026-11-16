module testbed_multifpga_cont #(
    parameter INPUT_WIDTH  = 200,
    parameter OUTPUT_WIDTH = 100,
    parameter TXRX_WIDTH   = 64 
) (
    input  logic                    signal_clk_i       ,
    input  logic                    signal_rstn_i      ,

    output logic                    signal_clk_enable_o,

    input  logic [INPUT_WIDTH-1:0]  input_i            ,
    output logic [OUTPUT_WIDTH-1:0] output_o           ,

    
    input  logic                    txrx_clk_i         ,
    input  logic                    txrx_rstn_i        ,

    output logic                    aur_tx_valid_o     ,
    input  logic                    aur_tx_ready_i     ,
    output logic [TXRX_WIDTH-1:0]   aur_tx_data_o      ,

    input  logic                    aur_rx_valid_i     ,
    input  logic [TXRX_WIDTH-1:0]   aur_rx_data_i      
);

    logic                    send_tx_valid ;
    logic                    send_tx_ready ;
    logic [TXRX_WIDTH-1:0]   send_tx_data  ;
    logic                    send_tx_tlast ;

    logic                    send_rx_valid ;
    logic [TXRX_WIDTH-1:0]   send_rx_data  ;


    logic                    recv_tx_valid ;
    logic                    recv_tx_ready ;
    logic [TXRX_WIDTH-1:0]   recv_tx_data  ;
    logic                    recv_tx_tlast ;

    logic                    recv_rx_valid ;
    logic [TXRX_WIDTH-1:0]   recv_rx_data  ;

    testbed_multifpga_send #(
        .INPUT_WIDTH (INPUT_WIDTH),
        .TXRX_WIDTH  (TXRX_WIDTH )
    ) u_testbed_multifpga_send (
        .input_clk_i        (signal_clk_i       ),
        .input_rstn_i       (signal_rstn_i      ),

        .input_clk_enable_o (signal_clk_enable_o),

        .input_i            (input_i            ),

        
        .txrx_clk_i         (txrx_clk_i         ),
        .txrx_rstn_i        (txrx_rstn_i        ),

        .tx_valid_o         (send_tx_valid      ),
        .tx_ready_i         (send_tx_ready      ),
        .tx_data_o          (send_tx_data       ),
        .tx_tlast_o         (send_tx_tlast      ),

        .rx_valid_i         (send_rx_valid      ),
        .rx_data_i          (send_rx_data       )
    );

    testbed_multifpga_receive #(
        .OUTPUT_WIDTH (OUTPUT_WIDTH),
        .TXRX_WIDTH   (TXRX_WIDTH  )
    ) u_testbed_multifpga_receive (
        .txrx_clk_i  (txrx_clk_i   ),
        .txrx_rstn_i (txrx_rstn_i  ),

        .output_o    (output_o     ),

        .tx_valid_o  (recv_tx_valid),
        .tx_ready_i  (recv_tx_ready),
        .tx_data_o   (recv_tx_data ),
        .tx_tlast_o  (recv_tx_tlast),

        .rx_valid_i  (recv_rx_valid),
        .rx_data_i   (recv_rx_data )
    );

    testbed_multifpga_connector #(
        .DATA_WIDTH (TXRX_WIDTH)
    ) u_testbed_multifpga_connector (
        .txrx_clk_i      (txrx_clk_i    ),
        .txrx_rstn_i     (txrx_rstn_i   ),

        .send_tx_valid_i (send_tx_valid ),
        .send_tx_ready_o (send_tx_ready ),
        .send_tx_data_i  (send_tx_data  ),
        .send_tx_tlast_i (send_tx_tlast ),

        .send_rx_valid_o (send_rx_valid ),
        .send_rx_data_o  (send_rx_data  ),

        .recv_tx_valid_i (recv_tx_valid ),
        .recv_tx_ready_o (recv_tx_ready ),
        .recv_tx_data_i  (recv_tx_data  ),
        .recv_tx_tlast_i (recv_tx_tlast ),

        .recv_rx_valid_o (recv_rx_valid ),
        .recv_rx_data_o  (recv_rx_data  ),


        .aur_tx_valid_o  (aur_tx_valid_o),
        .aur_tx_ready_i  (aur_tx_ready_i),
        .aur_tx_data_o   (aur_tx_data_o ),

        .aur_rx_valid_i  (aur_rx_valid_i),
        .aur_rx_data_i   (aur_rx_data_i )
    );
    
endmodule