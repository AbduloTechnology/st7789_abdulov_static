`timescale 1ns / 1ps



module st7789_driver (
    input  logic       CLK          ,
    input  logic       RESET        ,
    input  logic       SCLK         , // slowly clk
    input  logic [7:0] S_AXIS_TDATA ,
    input  logic       S_AXIS_TKEEP ,
    input  logic       S_AXIS_TUSER ,
    input  logic       S_AXIS_TVALID,
    input  logic       S_AXIS_TLAST ,
    output logic       S_AXIS_TREADY,
    output logic       LCD_BLK      ,
    output logic       LCD_RST      ,
    output logic       LCD_DC       ,
    output logic       LCD_SDA      ,
    output logic       LCD_SCK
);


    localparam RESET_COUNTER_LIMIT = 500;

    typedef enum {
        RESET_ST, 
        IDLE_ST, 
        TX_DATA_ST 
    } fsm;

    fsm current_state = RESET_ST;

    logic sreset;

    logic [$clog2(RESET_COUNTER_LIMIT)-1:0] reset_counter = '{default:0};

    logic [7:0] in_dout_data                       ;
    logic [7:0] in_dout_data_shifted = '{default:1};
    logic       in_dout_keep                       ;
    logic       in_dout_user                       ;
    logic       in_dout_user_saved   = 1'b1        ;
    logic       in_dout_last                       ;
    logic       in_dout_last_saved   = 1'b0        ;
    logic       in_rden              = 1'b0        ;
    logic       in_empty                           ;

    logic [2:0] bit_cnt = '{default:0};
    logic clk_en ; 

    xpm_cdc_sync_rst #(
        .DEST_SYNC_FF  (4), // DECIMAL; range: 2-10
        .INIT          (1), // DECIMAL; 0=initialize synchronization registers to 0, 1=initialize synchronization
        .INIT_SYNC_FF  (0), // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
        .SIM_ASSERT_CHK(0)  // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    ) xpm_cdc_sync_rst_inst (
        .dest_rst(sreset), // 1-bit output: src_rst synchronized to the destination clock domain. This output
        .dest_clk(SCLK  ), // 1-bit input: Destination clock.
        .src_rst (RESET )  // 1-bit input: Source reset signal.
    );



    always_ff @(posedge SCLK) begin : LCD_SDA_DC_processing
        LCD_SDA <= in_dout_data_shifted[7];
        LCD_DC  <= in_dout_user_saved;
    end 


    always_ff @(posedge SCLK) begin : LCD_RST_processing 
        case (current_state)
            RESET_ST : 
                LCD_RST <= 1'b0;

            default : 
                LCD_RST <= 1'b1;
        endcase // current_state
    end


    always_ff @(posedge SCLK) begin : reset_counter_processing 
        if (RESET) begin 
            reset_counter <= '{default:0};
        end else begin 

            case (current_state)
                RESET_ST : 
                    reset_counter <= reset_counter + 1;

                default : 
                    reset_counter <= '{default:0};
            endcase // current_state

        end 
    end 



    always_ff @(posedge SCLK) begin : current_state_processing 
        if (RESET) begin 
            current_state <= RESET_ST;
        end else begin 
            case (current_state)
                RESET_ST : 
                    if (reset_counter == RESET_COUNTER_LIMIT) begin 
                        current_state <= IDLE_ST;
                    end else begin 
                        current_state <= current_state;
                    end 

                IDLE_ST : 
                    if (!in_empty) begin 
                        current_state <= TX_DATA_ST;
                    end else begin 
                        current_state <= current_state;
                    end 

                TX_DATA_ST : 
                    if (bit_cnt == 7) begin  
                        if (in_dout_last_saved) begin 
                            current_state <= IDLE_ST;
                        end else begin 
                            current_state <= current_state;
                        end 
                    end else begin 
                        current_state <= current_state;
                    end

                default : 
                    current_state <= current_state;

            endcase // current_state
        end  
    end 



    always_ff @(posedge SCLK) begin : LCD_BLK_processing 
        case (current_state)
            RESET_ST : 
                LCD_BLK <= 1'b0;

            default :
                LCD_BLK <= 1'b1;

        endcase // current_state
    end 



    always_ff @(posedge SCLK) begin : bit_cnt_processing
        case (current_state)
            TX_DATA_ST :
                if (bit_cnt < 7) begin
                    bit_cnt <= bit_cnt + 1;
                end else begin
                    bit_cnt <= '{default:0};
                end

            default :
                bit_cnt <= '{default:0};

        endcase // current_state
    end 



    always_ff @(posedge SCLK) begin : in_dout_data_shifted_processing
        case (current_state)
            IDLE_ST :
                if (!in_empty) begin
                    in_dout_data_shifted <= in_dout_data;
                end else begin
                    in_dout_data_shifted <= '{default:1};
                end

            TX_DATA_ST :
                if (bit_cnt == 7) begin
                    in_dout_data_shifted <= in_dout_data;
                end else begin
                    in_dout_data_shifted <= {in_dout_data_shifted[6:0], 1'b1};
                end

            default :
                in_dout_data_shifted <= in_dout_data_shifted;

        endcase // current_state
    end 



    always_ff @(posedge SCLK) begin : in_dout_last_saved_processing
        case (current_state)
            IDLE_ST :
                if (!in_empty) begin
                    in_dout_last_saved <= in_dout_last;
                end else begin
                    in_dout_last_saved <= in_dout_last_saved;
                end

            TX_DATA_ST :
                if (bit_cnt == 7) begin
                    in_dout_last_saved <= in_dout_last;
                end else begin
                    in_dout_last_saved <= in_dout_last_saved;
                end

            default :
                in_dout_last_saved <= in_dout_last_saved;

        endcase // current_state
    end



    always_ff @(posedge SCLK) begin : in_dout_user_saved_processing
        case (current_state)
            IDLE_ST : 
                if (!in_empty) begin 
                    in_dout_user_saved <= in_dout_user;
                end else begin 
                    in_dout_user_saved <= 1'b1;
                end 

            TX_DATA_ST :
                if (bit_cnt == 7) begin
                    in_dout_user_saved <= in_dout_user;
                end else begin
                    in_dout_user_saved <= in_dout_user_saved;
                end 

            default : 
                in_dout_user_saved <= in_dout_user_saved;

        endcase // current_state
    end 



    always_ff @(posedge SCLK) begin : in_rden_processing
        case (current_state)
            TX_DATA_ST : 
                if (!bit_cnt) begin 
                    in_rden <= 1'b1;
                end else begin 
                    in_rden <= 1'b0;
                end 

            default : 
                in_rden <= 1'b0;

        endcase // current_state
    end 



    fifo_in_async_tuser_xpm #(
        .CDC_SYNC  (4      ),
        .DATA_WIDTH(8     ),
        .USER_WIDTH(1      ),
        .MEMTYPE   ("block"),
        .DEPTH     (16     )
    ) fifo_in_async_tuser_xpm_inst (
        .S_AXIS_CLK   (CLK          ),
        .S_AXIS_RESET (RESET        ),
        .M_AXIS_CLK   (SCLK         ),
        // input interface
        .S_AXIS_TDATA (S_AXIS_TDATA ),
        .S_AXIS_TKEEP (S_AXIS_TKEEP ),
        .S_AXIS_TLAST (S_AXIS_TLAST ),
        .S_AXIS_TUSER (S_AXIS_TUSER ),
        .S_AXIS_TVALID(S_AXIS_TVALID),
        .S_AXIS_TREADY(S_AXIS_TREADY),
        // internal fifo interface
        .IN_DOUT_DATA (in_dout_data ),
        .IN_DOUT_KEEP (in_dout_keep ),
        .IN_DOUT_USER (in_dout_user ),
        .IN_DOUT_LAST (in_dout_last ),
        .IN_RDEN      (in_rden      ),
        .IN_EMPTY     (in_empty     )
    );


    always_comb begin 
        case (current_state)
            TX_DATA_ST : 
                clk_en = 1'b0;

            default : 
                clk_en = 1'b1;

        endcase // current_state
    end 


    ODDR #(
        .DDR_CLK_EDGE("OPPOSITE_EDGE"), // "OPPOSITE_EDGE" or "SAME_EDGE"
        .INIT        (1'b1           ), // Initial value of Q: 1'b0 or 1'b1
        .SRTYPE      ("SYNC"         )  // Set/Reset type: "SYNC" or "ASYNC"
    ) ODDR_inst (
        .Q (LCD_SCK), // 1-bit DDR output
        .C (SCLK   ), // 1-bit clock input
        .CE(1'b1   ), // 1-bit clock enable input
        .D1(clk_en ), // 1-bit data input (positive edge)
        .D2(1'b1   ), // 1-bit data input (negative edge)
        .R (1'b0   ), // 1-bit reset
        .S (1'b0   )  // 1-bit set
    );


endmodule
