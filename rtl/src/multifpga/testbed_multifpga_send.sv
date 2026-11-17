module testbed_multifpga_send #(
    parameter INPUT_WIDTH = 200,
    parameter TXRX_WIDTH  = 64 ,

    parameter TXRX_DIV     = INPUT_WIDTH / TXRX_WIDTH  ,
    parameter TXRX_REM     = INPUT_WIDTH % TXRX_WIDTH  ,
    parameter TXRX_TOT     = TXRX_DIV + (TXRX_REM != 0),
    parameter TXRX_WIDTH_W = $clog2(TXRX_WIDTH)        
) (
    input  logic                   input_clk_i       ,
    input  logic                   input_rstn_i      ,

    output logic                   input_clk_enable_o,

    input  logic [INPUT_WIDTH-1:0] input_i           ,

    
    input  logic                   txrx_clk_i        ,
    input  logic                   txrx_rstn_i       ,

    output logic                   tx_valid_o        ,
    input  logic                   tx_ready_i        ,
    output logic [TXRX_WIDTH-1:0]  tx_data_o         ,
    output logic                   tx_tlast_o        ,

    input  logic                   rx_valid_i        ,
    input  logic [TXRX_WIDTH-1:0]  rx_data_i         
);

    typedef enum logic [1:0] {
        INP_RESET,
        INP_IDLE ,
        INP_DATA  
    } state_input_t;

    typedef enum logic [1:0] {
        TXRX_RESET,
        TXRX_IDLE ,
        TXRX_SEND ,
        TXRX_ACK  
    } state_txrx_t;

    state_input_t state_input, state_input_next;
    state_txrx_t  state_txrx , state_txrx_next ;

    logic [INPUT_WIDTH-1:0] input_ff  ;
    logic                   input_diff;

    logic input_clk_enable, input_clk_enable_next;

    logic cycle_done;

    logic [31:0] hs_counter, hs_counter_next;


    state_input_t state_input_sync;
    logic state_input_sync_valid;

    cdc_stream_afifo #(
        .DATA_WIDTH (2),
        .ADDR_WIDTH (2)
    ) state_input_synchronizer (
        .clk_wr   (input_clk_i ),
        .rst_n_wr (input_rstn_i),

        .data_i   (state_input[1:0]),
        .valid_i  (1'b1),
        .ready_o  (),
        .free_o   (),

        .clk_rd   (txrx_clk_i ),
        .rst_n_rd (txrx_rstn_i),

        .data_o   (state_input_sync[1:0]),
        .valid_o  (state_input_sync_valid),
        .ready_i  (1'b1),
        .count_o  ()
    );

    cdc_stream_afifo #(
        .DATA_WIDTH (2),
        .ADDR_WIDTH (2)
    ) cycle_done_sync (
        .clk_wr   (txrx_clk_i ),
        .rst_n_wr (txrx_rstn_i),

        .data_i   ('0),
        .valid_i  (rx_valid_i),
        .ready_o  (),
        .free_o   (),

        .clk_rd   (input_clk_i ),
        .rst_n_rd (input_rstn_i),

        .data_o   (),
        .valid_o  (cycle_done),
        .ready_i  (1'b1),
        .count_o  ()
    );


    assign input_diff = |(input_i ^ input_ff);
    assign input_clk_enable_o = ~input_diff & input_clk_enable;

    always_ff @(posedge input_clk_i or negedge input_rstn_i) begin : blockName
        if (!input_rstn_i) begin
            input_ff <= '0;
        end
        else begin
            input_ff <= input_i;
        end
    end


    always_ff @(posedge input_clk_i or negedge input_rstn_i) begin
        if (!input_rstn_i) begin
            state_input <= INP_RESET;

            input_clk_enable <= '1;
        end
        else begin
            state_input <= state_input_next;

            input_clk_enable <= input_clk_enable_next;
        end
    end

    always_comb begin
        state_input_next = state_input;

        case (state_input)
            INP_RESET  : begin
                state_input_next = INP_IDLE;
            end
            INP_IDLE   : begin
                if (input_diff) begin
                    state_input_next = INP_DATA;
                end
                else begin
                    state_input_next = state_input;
                end
            end
            INP_DATA   : begin
                if (cycle_done) begin
                    state_input_next = INP_IDLE;
                end
                else begin
                    state_input_next = state_input;
                end
            end
            default    : begin
                state_input_next = INP_IDLE;
            end
        endcase
    end

    always_comb begin
        input_clk_enable_next = '1;

        case (state_input)
            INP_RESET: begin
                input_clk_enable_next = '1;
            end
            INP_IDLE : begin
                if (input_diff) begin
                    input_clk_enable_next = '0;
                end
                else begin
                    input_clk_enable_next = '1;
                end
            end
            INP_DATA: begin
                input_clk_enable_next = '0;
            end
            default  : begin
                input_clk_enable_next = '0;
            end
        endcase
    end



    always_ff @(posedge txrx_clk_i or negedge txrx_rstn_i) begin
        if (!input_rstn_i) begin
            state_txrx <= TXRX_RESET;
            hs_counter <= '0        ;
        end
        else begin
            state_txrx <= state_txrx_next;
            hs_counter <= hs_counter_next;
        end
    end

    always_comb begin
        state_txrx_next = state_txrx;

        case (state_txrx)
            TXRX_RESET: begin
                state_txrx_next = TXRX_IDLE;
            end
            TXRX_IDLE : begin
                if (state_input_sync == INP_DATA && state_input_sync_valid) begin
                    state_txrx_next = TXRX_SEND;
                end
                else begin
                    state_txrx_next = state_txrx;
                end
            end
            TXRX_SEND : begin
                if (hs_counter == TXRX_TOT && (tx_valid_o && tx_ready_i)) begin
                    state_txrx_next = TXRX_ACK;
                end
                else begin
                    state_txrx_next = state_txrx;
                end
            end
            TXRX_ACK  : begin
                if (state_input_sync == INP_IDLE && state_input_sync_valid) begin
                    state_txrx_next = TXRX_IDLE;
                end
                else begin
                    state_txrx_next = state_txrx;
                end
            end
        endcase
    end

    always_comb begin
        hs_counter_next = hs_counter;

        tx_valid_o = '0;
        tx_data_o  = '0;
        tx_tlast_o = '0;

        case (state_txrx)
            TXRX_RESET, TXRX_IDLE : begin
                hs_counter_next = '0;

                tx_valid_o = '0;
                tx_data_o  = '0;
                tx_tlast_o = '0;
            end
            TXRX_SEND : begin
                if (hs_counter == 0) begin
                    tx_valid_o = '1;
                    tx_data_o  = {TXRX_TOT, 8'b0}; // [0:0] - packet type (1'b0 - data, 1'b1 - ack), the rest - packet count
                end
                else if (hs_counter < TXRX_TOT) begin
                    tx_valid_o = '1;
                    tx_data_o  = input_i[((hs_counter - 1) << TXRX_WIDTH_W) +: TXRX_WIDTH]; // input_i is quasi-static for txrx-domain in this state
                end
                else begin
                    tx_valid_o = '1;
                    tx_data_o  = input_i[((hs_counter - 1) << TXRX_WIDTH_W) +: TXRX_REM]; // input_i is quasi-static for txrx-domain in this state
                    tx_tlast_o = '1;
                end
                
                if (tx_valid_o && tx_ready_i) begin
                    hs_counter_next = hs_counter + 1;
                end
            end
            TXRX_ACK  : begin
                hs_counter_next = '0;

                tx_valid_o = '0;
                tx_data_o  = '0;
                tx_tlast_o = '0;
            end
        endcase
    end

endmodule