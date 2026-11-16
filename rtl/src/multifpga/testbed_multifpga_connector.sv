module testbed_multifpga_connector #(
    parameter DATA_WIDTH = 64
) (
    input  logic                    txrx_clk_i      ,
    input  logic                    txrx_rstn_i     ,

    input  logic                    send_tx_valid_i ,
    output logic                    send_tx_ready_o ,
    input  logic [DATA_WIDTH-1:0]   send_tx_data_i  ,
    input  logic                    send_tx_tlast_i ,

    output logic                    send_rx_valid_o ,
    output logic [DATA_WIDTH-1:0]   send_rx_data_o  ,

    input  logic                    recv_tx_valid_i ,
    output logic                    recv_tx_ready_o ,
    input  logic [DATA_WIDTH-1:0]   recv_tx_data_i  ,
    input  logic                    recv_tx_tlast_i ,

    output logic                    recv_rx_valid_o ,
    output logic [DATA_WIDTH-1:0]   recv_rx_data_o  ,


    output logic                    aur_tx_valid_o  ,
    input  logic                    aur_tx_ready_i  ,
    output logic [DATA_WIDTH-1:0]   aur_tx_data_o   ,

    input  logic                    aur_rx_valid_i  ,
    input  logic [DATA_WIDTH-1:0]   aur_rx_data_i   
);

    logic [1:0]            arb_valid    ;
    logic [1:0]            arb_ready    ;
    logic [DATA_WIDTH-1:0] arb_data  [2];
    logic [1:0]            arb_last     ;

    assign arb_valid[0] = send_tx_valid_i;
    assign arb_data [0] = send_tx_data_i ;
    assign arb_last [0] = send_tx_tlast_i;
    assign send_tx_ready_o = arb_ready[0];

    assign arb_valid[1] = recv_tx_valid_i;
    assign arb_data [1] = recv_tx_data_i ;
    assign arb_last [1] = recv_tx_tlast_i;
    assign recv_tx_ready_o = arb_ready[1];


    stream_wrmhl_arbiter #(
        .DATA_WIDTH (DATA_WIDTH),
        .INPUT_NUM  (2         )
    ) u_stream_wrmhl_arbiter (
        .clk     (txrx_clk_i    ),
        .rst_n   (txrx_rstn_i   ),

        .valid_i (arb_valid     ),
        .ready_o (arb_ready     ),
        .data_i  (arb_data      ),
        .last_i  (arb_last      ),

        .valid_o (aur_tx_valid_o),
        .ready_i (aur_tx_ready_i),
        .data_o  (aur_tx_data_o ),
        .last_o  (              ),

        .sel_o   (              )
    );


    logic demux_select, demux_select_next;
    logic [31:0] hs_counter       , hs_counter_next       ;
    logic [31:0] hs_counter_target, hs_counter_target_next;

    always_comb begin
        send_rx_valid_o = '0;
        send_rx_data_o  = '0;

        recv_rx_valid_o = '0;
        recv_rx_data_o  = '0;

        if (!demux_select_next) begin
            send_rx_valid_o = aur_rx_valid_i;
            send_rx_data_o  = aur_rx_data_i ;
        end
        else begin
            recv_rx_valid_o = aur_rx_valid_i;
            recv_rx_data_o  = aur_rx_data_i ;
        end
    end

    always_ff @(posedge txrx_clk_i or negedge txrx_rstn_i) begin
        if (!txrx_rstn_i) begin
            demux_select <= '0;

            hs_counter        <= '0;
            hs_counter_target <= '0;
        end
        else begin
            demux_select <= demux_select_next;

            hs_counter        <= hs_counter_next       ;
            hs_counter_target <= hs_counter_target_next;
        end
    end

    always_comb begin
        demux_select_next = demux_select;

        hs_counter_next        = hs_counter       ;
        hs_counter_target_next = hs_counter_target;

        if (aur_rx_valid_i) begin
            if (hs_counter == 0) begin
                demux_select_next = aur_rx_data_i[0] ? 1'b0 : 1'b1;

                if (aur_rx_data_i[DATA_WIDTH-1:8] != '0) begin
                    hs_counter_next = 1;
                    hs_counter_target_next = aur_rx_data_i[DATA_WIDTH-1:8];
                end
            end
            else begin
                if (hs_counter == hs_counter_target) begin
                    hs_counter_next = '0;
                end
                else begin
                    hs_counter_next = hs_counter + 1;
                end
            end
        end
    end
    
endmodule