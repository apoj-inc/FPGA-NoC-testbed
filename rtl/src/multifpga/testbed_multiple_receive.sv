module testbed_multifpga_receive #(
    parameter OUTPUT_WIDTH = 200,
    parameter TXRX_WIDTH   = 64 ,

    parameter TXRX_DIV     = OUTPUT_WIDTH / TXRX_WIDTH ,
    parameter TXRX_REM     = OUTPUT_WIDTH % TXRX_WIDTH ,
    parameter TXRX_TOT     = TXRX_DIV + (TXRX_REM != 0),
    parameter TXRX_WIDTH_W = $clog2(TXRX_WIDTH)        
) (
    input  logic                    txrx_clk_i ,
    input  logic                    txrx_rstn_i,

    output logic [OUTPUT_WIDTH-1:0] output_o   ,

    output logic                    tx_valid_o ,
    input  logic                    tx_ready_i ,
    output logic [TXRX_WIDTH-1:0]   tx_data_o  ,
    output logic                    tx_tlast_o ,

    input  logic                    rx_valid_i ,
    input  logic [TXRX_WIDTH-1:0]   rx_data_i  
);
    
    typedef enum logic [1:0] {
        RESET,
        IDLE ,
        REC  ,
        ACK  
    } state_t;

    state_t state, state_next;

    logic [31:0] hs_counter, hs_counter_next;
    logic [OUTPUT_WIDTH-1:0] output_next;

    assign tx_tlast_o = '1;

    always_ff @(posedge txrx_clk_i or negedge txrx_rstn_i) begin
        if (!txrx_rstn_i) begin
            state <= RESET;
            hs_counter <= '0;
            output_o <= '0;
        end
        else begin
            state <= state_next;
            hs_counter <= hs_counter_next;
            output_o <= output_next;
        end
    end

    always_comb begin
        state_next = state;

        case (state)
            RESET: begin
                state_next = IDLE;
            end
            IDLE : begin
                if (rx_valid_i) begin
                    state_next = REC;
                end
                else begin
                    state_next = state;
                end
            end
            REC  : begin
                if (hs_counter == TXRX_TOT) begin
                    state_next = ACK;
                end
                else begin
                    state_next = state;
                end
            end
            ACK  : begin
                if (tx_valid_o && tx_ready_i) begin
                    state_next = IDLE;
                end
                else begin
                    state_next = state;
                end
            end
        endcase
    end

    always_comb begin
        hs_counter_next = hs_counter;
        output_next     = output_o  ;
        
        tx_valid_o = '0;
        tx_data_o  = '0;

        case (state)
            RESET: begin
                hs_counter_next = '0;
                output_next     = '0;
            end
            IDLE : begin
            end
            REC  : begin
                if (rx_valid_i) begin
                    hs_counter_next = hs_counter + 1;
                    output_next[(hs_counter << TXRX_WIDTH_W) +: TXRX_WIDTH] = rx_data_i;
                end
            end
            ACK  : begin
                hs_counter_next = '0;

                tx_valid_o = '1;
                tx_data_o  = {'0, 8'b1};
            end
        endcase
    end

endmodule