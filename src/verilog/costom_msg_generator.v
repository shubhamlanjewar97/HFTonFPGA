`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2025
// Design Name: 
// Module Name: custom_msg_generator
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Sends message bytes one by one to a UART TX module
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module custom_msg_generator (
    input                  clk_in,
    input                  reset_in, 
    
    input [15:0] o_Quantity0,        // Order quantity for asset 0
    input [15:0] o_Quantity1,        // Order quantity for asset 1
    input [15:0] o_Quantity2,        // Order quantity for asset 2
    input [15:0] o_Quantity3,        // Order quantity for asset 3
    input signed [15:0] o_BestPrice0, // Best price used for asset 0
    input signed [15:0] o_BestPrice1, // Best price used for asset 1
    input signed [15:0] o_BestPrice2, // Best price used for asset 2
    input signed [15:0] o_BestPrice3, // Best price used for asset 3
    input o_Valid,                   // Order valid signal
    input o_BuySellIndicator0,       // Buy/Sell indicator for asset 0
    input o_BuySellIndicator1,       // Buy/Sell indicator for asset 1
    input o_BuySellIndicator2,       // Buy/Sell indicator for asset 2
    input o_BuySellIndicator3,       // Buy/Sell indicator for asset 3
    
    // UART TX interface signals
    output reg             tx_start,  // Start transmission signal for UART
    output reg [7:0]       tx_data,   // Data byte to transmit
    input                  tx_busy,   // UART busy signal
    
    // Optional status signals (can be used for debugging)
    output reg             msg_sending,  // Indicates active message transmission
    output reg             msg_done      // Indicates message transmission complete
);

    // Define parameters for message construction
    localparam TOTAL_BYTES = 28;     // 7 bytes * 4 messages
    localparam MESSAGE_SIZE = 56;    // 7 bytes * 8 bits per message
    
    // State machine parameters
    localparam IDLE = 4'b0000;
    localparam GENERATE_MESSAGES = 4'b0001;
    localparam COMBINE_MESSAGES = 4'b0010;
    localparam SEND_BYTE = 4'b0011;
    localparam WAIT_UART = 4'b0100;
    localparam WAIT_UART_2 = 4'b0101;
    localparam WAIT_UART_3 = 4'b0110;
    localparam WAIT_NEXT_BYTE = 4'b0111;
    localparam DONE = 4'b1000;
    
    reg [2:0] state, next_state;
    
    // Internal message holders
    reg [MESSAGE_SIZE-1:0] message0, message1, message2, message3;
    reg [4*MESSAGE_SIZE-1:0] all_messages;
    
    // Byte counter
    reg [4:0] byte_counter, next_byte_counter;  // 0-27 (need 5 bits)
    
    // State machine
    always @(posedge clk_in or posedge reset_in) begin
        if (reset_in) begin
            state <= IDLE;
            byte_counter <= 5'd0;
            msg_sending <= 1'b0;
            msg_done <= 1'b0;
            tx_start <= 1'b0;
            tx_data <= 8'b0;
        end else begin
            state <= next_state;
            byte_counter <= next_byte_counter;
            
            // Update output signals based on state
            case (state)
                IDLE: begin
                    msg_sending <= 1'b0;
                    msg_done <= 1'b0;
                    tx_start <= 1'b0;
                end
                
                GENERATE_MESSAGES: begin
                    msg_sending <= 1'b1;
                    msg_done <= 1'b0;
                    tx_start <= 1'b0;
                    
                    // Generate messages for all 4 stocks
                    
                    // Message for stock 0
                    message0 <= {
                        8'd7,                                   // Length (6 bytes)
                        8'd0,                                   // Stock ID (0)
                        o_BuySellIndicator0 ? 8'h01 : 8'h00,    // Buy=01, Sell=00
                        o_Quantity0[15:0],                      // Quantity (2 bytes)
                        o_BestPrice0[15:0]                      // Best Price (2 bytes)
                    };
                    
                    // Message for stock 1
                    message1 <= {
                        8'd7,                                   // Length (6 bytes)
                        8'd1,                                   // Stock ID (1)
                        o_BuySellIndicator1 ? 8'h01 : 8'h00,    // Buy=01, Sell=00
                        o_Quantity1[15:0],                      // Quantity (2 bytes)
                        o_BestPrice1[15:0]                      // Best Price (2 bytes)
                    };
                    
                    // Message for stock 2
                    message2 <= {
                        8'd7,                                   // Length (6 bytes)
                        8'd2,                                   // Stock ID (2)
                        o_BuySellIndicator2 ? 8'h01 : 8'h00,    // Buy=01, Sell=00
                        o_Quantity2[15:0],                      // Quantity (2 bytes)
                        o_BestPrice2[15:0]                      // Best Price (2 bytes)
                    };
                    
                    // Message for stock 3
                    message3 <= {
                        8'd7,                                   // Length (6 bytes)
                        8'd3,                                   // Stock ID (3)
                        o_BuySellIndicator3 ? 8'h01 : 8'h00,    // Buy=01, Sell=00
                        o_Quantity3[15:0],                      // Quantity (2 bytes)
                        o_BestPrice3[15:0]                      // Best Price (2 bytes)
                    };

//                    // Message for stock 0
//                    message0 <= {
//                        8'd7,                                   // Length (6 bytes)
//                        8'h01,                                   // Stock ID (3)
//                        8'h02,    // Buy=01, Sell=00
//                        16'h0304,                      // Quantity (2 bytes)
//                        16'h0506                      // Best Price (2 bytes)
//                    };
                    
//                    // Message for stock 1
//                    message1 <= {
//                        8'd7,                                   // Length (6 bytes)
//                        8'h01,                                   // Stock ID (3)
//                        8'h02,    // Buy=01, Sell=00
//                        16'h0304,                      // Quantity (2 bytes)
//                        16'h0506                      // Best Price (2 bytes)
//                    };
                    
//                    // Message for stock 2
//                    message2 <= {
//                        8'd7,                                   // Length (6 bytes)
//                        8'h01,                                   // Stock ID (3)
//                        8'h02,    // Buy=01, Sell=00
//                        16'h0304,                      // Quantity (2 bytes)
//                        16'h0506                      // Best Price (2 bytes)
//                    };
                    
//                    // Message for stock 3
//                    message3 <= {
//                        8'd7,                                   // Length (6 bytes)
//                        8'h01,                                   // Stock ID (3)
//                        8'h02,    // Buy=01, Sell=00
//                        16'h0304,                      // Quantity (2 bytes)
//                        16'h0506                      // Best Price (2 bytes)
//                    };
                    
                    // Combine all messages (MSB first)
                    all_messages <= {message0, message1, message2, message3};
                end
                
                COMBINE_MESSAGES: begin
                    all_messages <= {message0, message1, message2, message3};
                end
                
                SEND_BYTE: begin
                    msg_sending <= 1'b1;
                    msg_done <= 1'b0;
                    tx_start <= 1'b1;  // Start the UART transmission
                    
                    // Select the current byte to send (MSB to LSB)
                    tx_data <= all_messages[4*MESSAGE_SIZE-1 - (byte_counter*8) -: 8];
                end
                
                WAIT_UART: begin
                    msg_sending <= 1'b1;
                    msg_done <= 1'b0;
                    tx_start <= 1'b0;  // Clear start signal after UART has seen it
                end
                
                WAIT_UART_2: begin
                    msg_sending <= 1'b1;
                    msg_done <= 1'b0;
                    tx_start <= 1'b0;  // Clear start signal after UART has seen it
                end
                
                
                WAIT_UART_3: begin
                    msg_sending <= 1'b1;
                    msg_done <= 1'b0;
                    tx_start <= 1'b0;  // Clear start signal after UART has seen it
                end
                
                
                WAIT_NEXT_BYTE: begin
                    msg_sending <= 1'b1;
                    msg_done <= 1'b0;
                    tx_start <= 1'b0;
                end
                
                DONE: begin
                    msg_sending <= 1'b0;
                    msg_done <= 1'b1;
                    tx_start <= 1'b0;
                end
                
                default: begin
                    msg_sending <= 1'b0;
                    msg_done <= 1'b0;
                    tx_start <= 1'b0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        next_byte_counter = byte_counter;
        
        case (state)
            IDLE: begin
                next_byte_counter = 5'd0;
                if (o_Valid)
                    next_state = GENERATE_MESSAGES;
            end
            
            GENERATE_MESSAGES: begin
                next_state = COMBINE_MESSAGES;
            end
            
            
            COMBINE_MESSAGES: begin
                next_state = SEND_BYTE;
            end
            
                       
            SEND_BYTE: begin
                next_state = WAIT_UART;
            end

            WAIT_UART: begin
                next_state = WAIT_UART_2;
            end
            
            WAIT_UART_2: begin
                next_state = WAIT_UART_3;
            end
            
            WAIT_UART_3: begin
                // Wait for UART to become busy (it accepted our byte)
                if (tx_busy) begin
                    next_state = WAIT_NEXT_BYTE;
                    end
                else begin
                    next_state = SEND_BYTE;
                    next_byte_counter = byte_counter + 1'b1;
                end
            end
            
            WAIT_NEXT_BYTE: begin
                // Wait for UART to finish transmitting current byte
                if (!tx_busy) begin
                    if (byte_counter == TOTAL_BYTES - 1) begin
                        next_state = DONE;
                    end else begin
                        next_byte_counter = byte_counter + 1'b1;
                        next_state = SEND_BYTE;
                    end
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule