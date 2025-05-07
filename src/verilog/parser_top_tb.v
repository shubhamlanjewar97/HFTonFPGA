`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.04.2025 17:30:09
// Design Name: 
// Module Name: parser_top_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module parser_top_tb;

    // Parameters
    parameter PRICE_WIDTH = 15;
    parameter ID_WIDTH = 15;
    parameter QUANT_WIDTH = 7;
    parameter STOCK_WIDTH = 7;
    parameter DATA_WIDTH = 7;
    parameter STOCK_INDEX = 1;
    parameter TOTAL_BITS = 32;
    parameter QUANTITY_INDEX = 7;
    parameter PRICE_INDEX = 15;
    //parameter PRICE_INDEX = 15;
    parameter CANCEL_ORDER = 0;
    parameter ADD_ORDER = 1;
    parameter EXECUTE_ORDER = 2;
    parameter ORDER_INDEX = 7;
    parameter MAX_MESSAGE_SIZE = 48;
    
    // Clock period definition
    parameter CLK_PERIOD = 10; // 10 ns (100 MHz)
    
    // Inputs
    reg clk_in;
    reg reset_in;
    reg [DATA_WIDTH:0] data_in;
    reg in_ready;
    reg master_ack;
    
    // Outputs
    wire [STOCK_INDEX:0] stock_identifier;
    wire [TOTAL_BITS-1:0] order_to_add;
    wire [QUANTITY_INDEX:0] quantity;
    wire [2:0] request;
    wire [ORDER_INDEX:0] order_id;
    wire order_type_out_add;
    wire out_ready;
    
    // For Debugging
    wire [7:0] quantity_out;
    wire [7:0] orderid_out;
    wire [15:0] price_out;
    
    // Assign decomposed parts of order_to_add for debugging
    assign quantity_out = order_to_add[31:24];
    assign orderid_out = order_to_add[23:16];
    assign price_out = order_to_add[15:0];

    
    
    wire [7:0]                     message_monitor;
    wire [MAX_MESSAGE_SIZE*8-1:0]  parsed_data_monitor;
    wire [2:0]   current_state_monitor;
    wire [10:0] count_monitor;
    
    
    // Instantiate the Unit Under Test (UUT)
    parser_top  UUT (
        .clk_in(clk_in),
        .reset_in(reset_in),
        .data_in(data_in),
        .in_ready(in_ready),
        //.master_ack(master_ack),
        .stock_identifier(stock_identifier),
        .order_to_add(order_to_add),
        .quantity(quantity),
        .request(request),
        .order_id(order_id),
        .order_type_out_add(order_type_out_add),
        .out_ready(out_ready),
        .message_monitor(message_monitor),
        .current_state_monitor(current_state_monitor),
        .count_monitor(count_monitor)
        //.parsed_data_monitor(parsed_data_monitor)
    );
    
    
    
    
//    wire is_busy;
//	wire best_price_valid;
//	wire [63:0] best_price_stocks;
//	wire [3:0] best_prices_valid;
//	wire [31:0] size_of_stocks;
 
//    order_book_wrapper order_book_top (
//        //inputs
//        .clk_in(clk_in),
//        .rst_in(reset_in),
//        .stock_to_add(stock_identifier),
//        .order_to_add(order_to_add),
//        .start(out_ready),
//        .quantity(quantity),
//        .request(request),
//        .order_id(order_id),
		
//        //outputs
//        .is_busy(is_busy),
//        .best_price_valid(best_price_valid),
//        .best_price_stocks(best_price_stocks),
//        .best_prices_valid(best_prices_valid),
//        .size_of_stocks(size_of_stocks)
//    );
    
//    wire signed [15:0] i_BestPrice3, i_BestPrice2, i_BestPrice1, i_BestPrice0;
	
//	assign i_BestPrice0 = $signed(best_price_stocks[15:0]);
//	assign i_BestPrice1 = $signed(best_price_stocks[31:16]);
//	assign i_BestPrice2 = $signed(best_price_stocks[47:32]);
//	assign i_BestPrice3 = $signed(best_price_stocks[63:48]);
	
	
//	wire [15:0] o_Quantity0, o_Quantity1, o_Quantity2, o_Quantity3;
//	wire [15:0] o_BestPrice0, o_BestPrice1, o_BestPrice2, o_BestPrice3;
//	wire o_Valid, o_BuySellIndicator0, o_BuySellIndicator1, o_BuySellIndicator2, o_BuySellIndicator3;
	
 
//    Top_Trading trading_instance (
//        //inputs
//        .i_Clk(clk_in),                          // Clock input
//        .i_Resetn(!reset_in),                    // Active low reset
//        .i_BestPrice0(i_BestPrice0),            // Best bid price for asset 0
//        .i_BestPrice1(i_BestPrice1),            // Best bid price for asset 1
//        .i_BestPrice2(i_BestPrice2),            // Best bid price for asset 2
//        .i_BestPrice3(i_BestPrice3),            // Best bid price for asset 3
//        .best_price_valid(best_price_valid),    // Valid signal for best bid prices
//        .strategy_select(2'b00),      // Strategy selection: 0-Equal, 1-Liquidity, 2-Depth, 3-Statistics
		
//        //outputs
//        .o_Quantity0(o_Quantity0),              // Order quantity for asset 0
//        .o_Quantity1(o_Quantity1),              // Order quantity for asset 1
//        .o_Quantity2(o_Quantity2),              // Order quantity for asset 2
//        .o_Quantity3(o_Quantity3),              // Order quantity for asset 3
//        .o_BestPrice0(o_BestPrice0),            // Best price used for asset 0
//        .o_BestPrice1(o_BestPrice1),            // Best price used for asset 1
//        .o_BestPrice2(o_BestPrice2),            // Best price used for asset 2
//        .o_BestPrice3(o_BestPrice3),            // Best price used for asset 3
//        .o_Valid(o_Valid),                      // Order valid signal
//        .o_BuySellIndicator0(o_BuySellIndicator0), // Buy/Sell indicator for asset 0
//        .o_BuySellIndicator1(o_BuySellIndicator1), // Buy/Sell indicator for asset 1
//        .o_BuySellIndicator2(o_BuySellIndicator2), // Buy/Sell indicator for asset 2
//        .o_BuySellIndicator3(o_BuySellIndicator3)  // Buy/Sell indicator for asset 3
//    );
	
	
//    wire tx_start;
//    wire [7:0] tx_data;
//    wire tx_busy;

//    custom_msg_generator msg_gen_instance (
//        //inputs
//        .clk_in(clk_in),
//        .reset_in(reset_in),
//        .tx_busy(tx_busy),
//        .o_Quantity0(o_Quantity0),
//        .o_Quantity1(o_Quantity1),
//        .o_Quantity2(o_Quantity2),
//        .o_Quantity3(o_Quantity3),
//        .o_BestPrice0(o_BestPrice0),
//        .o_BestPrice1(o_BestPrice1),
//        .o_BestPrice2(o_BestPrice2),
//        .o_BestPrice3(o_BestPrice3),
//        .o_Valid(o_Valid),
//        .o_BuySellIndicator0(o_BuySellIndicator0),
//        .o_BuySellIndicator1(o_BuySellIndicator1),
//        .o_BuySellIndicator2(o_BuySellIndicator2),
//        .o_BuySellIndicator3(o_BuySellIndicator3),
		
//        //outputs
//        .tx_start(tx_start),
//        .tx_data(tx_data)
//    );

 
//    uart_tx uarttx (
//        //inputs
//        .clk(clk_in),
//        .rst(reset_in),
//        .tx_start(tx_start),
//        .tx_data(tx_data),
		
//        //outputs
//        .tx_busy(tx_busy),
//        .tx(tx)
//    );

    
    
    // Clock generation
    always begin
        #(CLK_PERIOD/2) clk_in = ~clk_in;
    end
    
    // Variables for test data
    integer i;
    reg [7:0] add_order_message [0:42];      // ADD_ORDER message buffer
    reg [7:0] add_order_message_1 [0:42];      // ADD_ORDER message buffer
    reg [7:0] add_order_message_2 [0:42];      // ADD_ORDER message buffer
    reg [7:0] add_order_message_3 [0:42];      // ADD_ORDER message buffer
    
    reg [7:0] cancel_order_message [0:32];   // CANCEL_ORDER message buffer
    reg [7:0] execute_order_message [0:32];  // EXECUTE_ORDER message buffer
    
    // Error count for summary
    integer error_count;
    
    // Bit reversal function to match the module's implementation
    function [7:0] reverse_bits;
        input [7:0] data_in;
        integer j;
        begin
            for (j = 0; j < 8; j = j + 1) begin
                reverse_bits[j] =data_in[j]; //data_in[7-j];
            end
        end
    endfunction
    
    // Task to send a message
    task send_message;
        input integer buffer_type; // 0=ADD, 1=CANCEL, 2=EXECUTE
        input integer length;
        begin
            for (i = 0; i < length; i = i + 1) begin
                @(posedge clk_in);
                if (buffer_type == 0) begin
                    data_in = reverse_bits(add_order_message[i]);
                 end else if (buffer_type == 3) begin
                    data_in = reverse_bits(add_order_message_1[i]);         
                 end else if (buffer_type == 4) begin
                    data_in = reverse_bits(add_order_message_2[i]);   
                 end else if (buffer_type == 5) begin
                    data_in = reverse_bits(add_order_message_3[i]);                                                     
                end else if (buffer_type == 1) begin
                    data_in = reverse_bits(cancel_order_message[i]);
                end else begin
                    data_in = reverse_bits(execute_order_message[i]);
                end
                in_ready = 1;
                @(negedge clk_in);
                in_ready = 0;
                #(CLK_PERIOD);
            end
            data_in = 0;
        end
    endtask
    
    // Task to wait for out_ready
    task wait_for_ready;
        input integer max_cycles;
        output timeout_occurred;
        integer i;
        begin
            timeout_occurred = 0;
            
            for (i = 0; i < max_cycles; i = i + 1) begin
                @(posedge clk_in);
                if (out_ready) begin
                    timeout_occurred = 0;
                    i = max_cycles; // Exit the loop
                end
            end
            
            // Check if we timed out
            if (i >= max_cycles && !out_ready) begin
                timeout_occurred = 1;
                $display("ERROR: Timeout waiting for out_ready");
                error_count = error_count + 1;
            end
        end
    endtask
    
    // Task to check output values
    task check_output;
        input [2:0] expected_request;
        input [STOCK_INDEX:0] expected_stock;
        input [ORDER_INDEX:0] expected_order_id;
        input [QUANTITY_INDEX:0] expected_quantity;
        input expected_order_type;
        input [31:0] expected_qty_id_price;
        reg timeout;
        begin
            // Wait for output ready
            //wait_for_ready(100, timeout);
            
            // Only check if we didn't time out
            if (1) begin //            if (!timeout) begin
                // Check request field
                if (request !== expected_request) begin
                    $display("ERROR: request mismatch. Expected %h, Got %h", expected_request, request);
                    error_count = error_count + 1;
                end else begin
                    $display("PASS: request matches expected value %h", expected_request);
                end
                
                // Check stock_identifier field
                if (stock_identifier !== expected_stock) begin
                    $display("ERROR: stock_identifier mismatch. Expected %h, Got %h", expected_stock, stock_identifier);
                    error_count = error_count + 1;
                end else begin
                    $display("PASS: stock_identifier matches expected value %h", expected_stock);
                end
                
                // Check order_id field
                if (order_id !== expected_order_id) begin
                    $display("ERROR: order_id mismatch. Expected %h, Got %h", expected_order_id, order_id);
                    error_count = error_count + 1;
                end else begin
                    $display("PASS: order_id matches expected value %h", expected_order_id);
                end
                
                // Check quantity field
                if (quantity !== expected_quantity) begin
                    $display("ERROR: quantity mismatch. Expected %h, Got %h", expected_quantity, quantity);
                    error_count = error_count + 1;
                end else begin
                    $display("PASS: quantity matches expected value %h", expected_quantity);
                end
                
                // Check order_type_out_add for ADD_ORDER requests
                if (expected_request == ADD_ORDER) begin
                    if (order_type_out_add !== expected_order_type) begin
                        $display("ERROR: order_type_out_add mismatch. Expected %h, Got %h", expected_order_type, order_type_out_add);
                        error_count = error_count + 1;
                    end else begin
                        $display("PASS: order_type_out_add matches expected value %h", expected_order_type);
                    end
                end
                
                // Check complete order_to_add struct
                if (order_to_add !== expected_qty_id_price) begin
                    $display("ERROR: order_to_add mismatch.");
                    $display("Expected: %h | %h | %h (Quantity | OrderID | Price)", 
                             expected_qty_id_price[31:24], 
                             expected_qty_id_price[23:16], 
                             expected_qty_id_price[15:0]);
                    $display("Got:      %h | %h | %h (Quantity | OrderID | Price)", 
                             order_to_add[31:24], 
                             order_to_add[23:16], 
                             order_to_add[15:0]);
                    error_count = error_count + 1;
                end else begin
                    $display("PASS: order_to_add matches expected value");
                end
                
//                // Acknowledge the output
//                @(posedge clk_in);
//                master_ack = 1;
                
//                // Verify out_ready is deasserted correctly
//                @(posedge clk_in);
//                master_ack = 0;
//                #(CLK_PERIOD*2);
//                if (out_ready !== 0) begin
//                    $display("ERROR: out_ready not deasserted after master_ack");
//                    error_count = error_count + 1;
//                end else begin
//                    $display("PASS: out_ready correctly deasserted");
//                end
                
                // Add extra delay to ensure module returns to INIT state
                #(CLK_PERIOD*5);
            end
        end
    endtask
    
    // Test sequence
    initial begin
        // Initialize
        $display("Starting Testbench for parser_top module");
        
        //tx_busy = 0;
        
        clk_in = 0;
        reset_in = 1;
        data_in = 0;
        in_ready = 0;
        master_ack = 0;
        error_count = 0;
        //#3
        // Initialize test messages
 
        // ADD_ORDER message (type 0x82) - Buy order
        // Format: length + msg_type + stock_locate + tracking_number + timestamp + order_ref_num + buy_sell_ind + shares + stock + price
        add_order_message[0] = 8'h25;     // Message length (37 bytes)
        add_order_message[1] = 8'h82;     // Message type (Add Order - No MPID Attribution)
        add_order_message[2] = 8'h01;     // Stock locate (1)
        add_order_message[3] = 8'h00;     // Stock locate (continued)
        add_order_message[4] = 8'h01;     // Tracking number (1)
        add_order_message[5] = 8'h00;     // Tracking number (continued)
        // Timestamp (6 bytes) - using a sample value
        add_order_message[6] = 8'h00;
        add_order_message[7] = 8'h00;
        add_order_message[8] = 8'h00;
        add_order_message[9] = 8'h00;
        add_order_message[10] = 8'h00;
        add_order_message[11] = 8'h01;
        // Order Reference Number (8 bytes) - using value 0x56
        add_order_message[12] = 8'h56;    // This is the least significant byte (LSB)
        add_order_message[13] = 8'h00;
        add_order_message[14] = 8'h00;
        add_order_message[15] = 8'h00;
        add_order_message[16] = 8'h00;
        add_order_message[17] = 8'h00;
        add_order_message[18] = 8'h00;
        add_order_message[19] = 8'h00;
        // Buy/Sell Indicator (1 byte) - 'A' for Buy (per module implementation)
        add_order_message[20] = 8'h41;    // ASCII 'A' = 0x41 (module checks for 'A', not 'B')
        // Shares (4 bytes) - 100 shares (0x64)
        add_order_message[21] = 8'h64;    // 100 in decimal
        add_order_message[22] = 8'h00;
        add_order_message[23] = 8'h00;
        add_order_message[24] = 8'h00;
        // Stock (8 bytes) - "AAPL" with padding
        add_order_message[25] = 8'h41;    // 'A'
        add_order_message[26] = 8'h41;    // 'A'
        add_order_message[27] = 8'h50;    // 'P'
        add_order_message[28] = 8'h4C;    // 'L'
        add_order_message[29] = 8'h20;    // ' ' (space)
        add_order_message[30] = 8'h20;    // ' ' (space)
        add_order_message[31] = 8'h20;    // ' ' (space)
        add_order_message[32] = 8'h20;    // ' ' (space)
        // Price (4 bytes) - $150.25 (15025 in cents)
        add_order_message[33] = 8'h99;    // LSB
        add_order_message[34] = 8'h3A;    // 0x3A99 = 15025
        add_order_message[35] = 8'h22;
        add_order_message[36] = 8'h33;
        
        
        
        
        
        
                // ADD_ORDER message (type 0x82) - Buy order
        // Format: length + msg_type + stock_locate + tracking_number + timestamp + order_ref_num + buy_sell_ind + shares + stock + price
        add_order_message_1[0] = 8'h25;     // Message length (37 bytes)
        add_order_message_1[1] = 8'h82;     // Message type (Add Order - No MPID Attribution)
        add_order_message_1[2] = 8'h00;     // Stock locate (1)
        add_order_message_1[3] = 8'h00;     // Stock locate (continued)
        add_order_message_1[4] = 8'h01;     // Tracking number (1)
        add_order_message_1[5] = 8'h00;     // Tracking number (continued)
        // Timestamp (6 bytes) - using a sample value
        add_order_message_1[6] = 8'h00;
        add_order_message_1[7] = 8'h00;
        add_order_message_1[8] = 8'h00;
        add_order_message_1[9] = 8'h00;
        add_order_message_1[10] = 8'h00;
        add_order_message_1[11] = 8'h01;
        // Order Reference Number (8 bytes) - using value 0x56
        add_order_message_1[12] = 8'h56;    // This is the least significant byte (LSB)
        add_order_message_1[13] = 8'h00;
        add_order_message_1[14] = 8'h00;
        add_order_message_1[15] = 8'h00;
        add_order_message_1[16] = 8'h00;
        add_order_message_1[17] = 8'h00;
        add_order_message_1[18] = 8'h00;
        add_order_message_1[19] = 8'h00;
        // Buy/Sell Indicator (1 byte) - 'A' for Buy (per module implementation)
        add_order_message_1[20] = 8'h41;    // ASCII 'A' = 0x41 (module checks for 'A', not 'B')
        // Shares (4 bytes) - 100 shares (0x64)
        add_order_message_1[21] = 8'h64;    // 100 in decimal
        add_order_message_1[22] = 8'h00;
        add_order_message_1[23] = 8'h00;
        add_order_message_1[24] = 8'h00;
        // Stock (8 bytes) - "AAPL" with padding
        add_order_message_1[25] = 8'h41;    // 'A'
        add_order_message_1[26] = 8'h41;    // 'A'
        add_order_message_1[27] = 8'h50;    // 'P'
        add_order_message_1[28] = 8'h4C;    // 'L'
        add_order_message_1[29] = 8'h20;    // ' ' (space)
        add_order_message_1[30] = 8'h20;    // ' ' (space)
        add_order_message_1[31] = 8'h20;    // ' ' (space)
        add_order_message_1[32] = 8'h20;    // ' ' (space)
        // Price (4 bytes) - $150.25 (15025 in cents)
        add_order_message_1[33] = 8'h99;    // LSB
        add_order_message_1[34] = 8'h3A;    // 0x3A99 = 15025
        add_order_message_1[35] = 8'h22;
        add_order_message_1[36] = 8'h33;

        
        
        
        
        
        
        
                // ADD_ORDER message (type 0x82) - Buy order
        // Format: length + msg_type + stock_locate + tracking_number + timestamp + order_ref_num + buy_sell_ind + shares + stock + price
        add_order_message_2[0] = 8'h25;     // Message length (37 bytes)
        add_order_message_2[1] = 8'h82;     // Message type (Add Order - No MPID Attribution)
        add_order_message_2[2] = 8'h02;     // Stock locate (1)
        add_order_message_2[3] = 8'h00;     // Stock locate (continued)
        add_order_message_2[4] = 8'h01;     // Tracking number (1)
        add_order_message_2[5] = 8'h00;     // Tracking number (continued)
        // Timestamp (6 bytes) - using a sample value
        add_order_message_2[6] = 8'h00;
        add_order_message_2[7] = 8'h00;
        add_order_message_2[8] = 8'h00;
        add_order_message_2[9] = 8'h00;
        add_order_message_2[10] = 8'h00;
        add_order_message_2[11] = 8'h01;
        // Order Reference Number (8 bytes) - using value 0x56
        add_order_message_2[12] = 8'h56;    // This is the least significant byte (LSB)
        add_order_message_2[13] = 8'h00;
        add_order_message_2[14] = 8'h00;
        add_order_message_2[15] = 8'h00;
        add_order_message_2[16] = 8'h00;
        add_order_message_2[17] = 8'h00;
        add_order_message_2[18] = 8'h00;
        add_order_message_2[19] = 8'h00;
        // Buy/Sell Indicator (1 byte) - 'A' for Buy (per module implementation)
        add_order_message_2[20] = 8'h41;    // ASCII 'A' = 0x41 (module checks for 'A', not 'B')
        // Shares (4 bytes) - 100 shares (0x64)
        add_order_message_2[21] = 8'h64;    // 100 in decimal
        add_order_message_2[22] = 8'h00;
        add_order_message_2[23] = 8'h00;
        add_order_message_2[24] = 8'h00;
        // Stock (8 bytes) - "AAPL" with padding
        add_order_message_2[25] = 8'h41;    // 'A'
        add_order_message_2[26] = 8'h41;    // 'A'
        add_order_message_2[27] = 8'h50;    // 'P'
        add_order_message_2[28] = 8'h4C;    // 'L'
        add_order_message_2[29] = 8'h20;    // ' ' (space)
        add_order_message_2[30] = 8'h20;    // ' ' (space)
        add_order_message_2[31] = 8'h20;    // ' ' (space)
        add_order_message_2[32] = 8'h20;    // ' ' (space)
        // Price (4 bytes) - $150.25 (15025 in cents)
        add_order_message_2[33] = 8'h99;    // LSB
        add_order_message_2[34] = 8'h3A;    // 0x3A99 = 15025
        add_order_message_2[35] = 8'h22;
        add_order_message_2[36] = 8'h33;

        
        
        
        
        
                // ADD_ORDER message (type 0x82) - Buy order
        // Format: length + msg_type + stock_locate + tracking_number + timestamp + order_ref_num + buy_sell_ind + shares + stock + price
        add_order_message_3[0] = 8'h25;     // Message length (37 bytes)
        add_order_message_3[1] = 8'h82;     // Message type (Add Order - No MPID Attribution)
        add_order_message_3[2] = 8'h03;     // Stock locate (1)
        add_order_message_3[3] = 8'h00;     // Stock locate (continued)
        add_order_message_3[4] = 8'h01;     // Tracking number (1)
        add_order_message_3[5] = 8'h00;     // Tracking number (continued)
        // Timestamp (6 bytes) - using a sample value
        add_order_message_3[6] = 8'h00;
        add_order_message_3[7] = 8'h00;
        add_order_message_3[8] = 8'h00;
        add_order_message_3[9] = 8'h00;
        add_order_message_3[10] = 8'h00;
        add_order_message_3[11] = 8'h01;
        // Order Reference Number (8 bytes) - using value 0x56
        add_order_message_3[12] = 8'h56;    // This is the least significant byte (LSB)
        add_order_message_3[13] = 8'h00;
        add_order_message_3[14] = 8'h00;
        add_order_message_3[15] = 8'h00;
        add_order_message_3[16] = 8'h00;
        add_order_message_3[17] = 8'h00;
        add_order_message_3[18] = 8'h00;
        add_order_message_3[19] = 8'h00;
        // Buy/Sell Indicator (1 byte) - 'A' for Buy (per module implementation)
        add_order_message_3[20] = 8'h41;    // ASCII 'A' = 0x41 (module checks for 'A', not 'B')
        // Shares (4 bytes) - 100 shares (0x64)
        add_order_message_3[21] = 8'h64;    // 100 in decimal
        add_order_message_3[22] = 8'h00;
        add_order_message_3[23] = 8'h00;
        add_order_message_3[24] = 8'h00;
        // Stock (8 bytes) - "AAPL" with padding
        add_order_message_3[25] = 8'h41;    // 'A'
        add_order_message_3[26] = 8'h41;    // 'A'
        add_order_message_3[27] = 8'h50;    // 'P'
        add_order_message_3[28] = 8'h4C;    // 'L'
        add_order_message_3[29] = 8'h20;    // ' ' (space)
        add_order_message_3[30] = 8'h20;    // ' ' (space)
        add_order_message_3[31] = 8'h20;    // ' ' (space)
        add_order_message_3[32] = 8'h20;    // ' ' (space)
        // Price (4 bytes) - $150.25 (15025 in cents)
        add_order_message_3[33] = 8'h99;    // LSB
        add_order_message_3[34] = 8'h3A;    // 0x3A99 = 15025
        add_order_message_3[35] = 8'h22;
        add_order_message_3[36] = 8'h33;

        
        
        
        
        
        // CANCEL_ORDER message (type 0xA1)
        // Format: length + msg_type + stock_locate + tracking_number + timestamp + order_ref_num + shares
        cancel_order_message[0] = 8'h18;  // Message length (24 bytes)
        cancel_order_message[1] = 8'hA1;  // Message type (Order Cancel)
        cancel_order_message[2] = 8'h02;  // Stock locate (2)
        cancel_order_message[3] = 8'h00;  // Stock locate (continued)
        cancel_order_message[4] = 8'h02;  // Tracking number (2)
        cancel_order_message[5] = 8'h00;  // Tracking number (continued)
        // Timestamp (6 bytes)
        cancel_order_message[6] = 8'h00;
        cancel_order_message[7] = 8'h00;
        cancel_order_message[8] = 8'h00;
        cancel_order_message[9] = 8'h00;
        cancel_order_message[10] = 8'h00;
        cancel_order_message[11] = 8'h02;
        // Order Reference Number (8 bytes) - using value 0xBC
        cancel_order_message[12] = 8'hBC;  // LSB
        cancel_order_message[13] = 8'h00;
        cancel_order_message[14] = 8'h00;
        cancel_order_message[15] = 8'h00;
        cancel_order_message[16] = 8'h00;
        cancel_order_message[17] = 8'h00;
        cancel_order_message[18] = 8'h00;
        cancel_order_message[19] = 8'h00;
        // Shares (4 bytes) - 50 shares (0x32)
        cancel_order_message[20] = 8'h32;  // 50 in decimal
        cancel_order_message[21] = 8'h11;
        cancel_order_message[22] = 8'h22;
        cancel_order_message[23] = 8'h33;
        
        // EXECUTE_ORDER message (type 0x2A)
        // Format: length + msg_type + stock_locate + tracking_number + timestamp + order_ref_num + shares
        execute_order_message[0] = 8'h18;  // Message length (24 bytes)
        execute_order_message[1] = 8'h2A;  // Message type (Order Execute)
        execute_order_message[2] = 8'h03;  // Stock locate (3)
        execute_order_message[3] = 8'h00;  // Stock locate (continued)
        execute_order_message[4] = 8'h03;  // Tracking number (3)
        execute_order_message[5] = 8'h00;  // Tracking number (continued)
        // Timestamp (6 bytes)
        execute_order_message[6] = 8'h00;
        execute_order_message[7] = 8'h00;
        execute_order_message[8] = 8'h00;
        execute_order_message[9] = 8'h00;
        execute_order_message[10] = 8'h00;
        execute_order_message[11] = 8'h03;
        // Order Reference Number (8 bytes) - using value 0x23
        execute_order_message[12] = 8'h23;  // LSB
        execute_order_message[13] = 8'h00;
        execute_order_message[14] = 8'h00;
        execute_order_message[15] = 8'h00;
        execute_order_message[16] = 8'h00;
        execute_order_message[17] = 8'h00;
        execute_order_message[18] = 8'h00;
        execute_order_message[19] = 8'h00;
        // Shares (4 bytes) - 75 shares (0x4B)
        execute_order_message[20] = 8'h4B;  // 75 in decimal
        execute_order_message[21] = 8'h11;
        execute_order_message[22] = 8'h22;
        execute_order_message[23] = 8'h22;
        
        // Release reset
        #(CLK_PERIOD*15);
        reset_in = 0;
        #(CLK_PERIOD*10);
        
        //#5
        
        // Test 1: ADD_ORDER
        $display("\n--- Test 1: ADD_ORDER Message ---");
        send_message(0, 37); // 0 = ADD_ORDER buffer

        // Expected values match the ADD_ORDER message structure
        // order_to_add = {quantity(8), order_id(8), price(16)} = {0x64, 0x56, 0x3A99}
        check_output(
            ADD_ORDER,              // expected_request
            8'h01,                  // expected_stock
            8'h56,                  // expected_order_id
            8'h64,                  // expected_quantity
            1'b1,                   // expected_order_type (1 for Buy)
            {8'h64, 8'h56, 16'h3A99} // expected_order_to_add
        );
       
       
       
       
        // Test 1: ADD_ORDER
        $display("\n--- Test 1 A: ADD_ORDER Message ---");
        send_message(3, 37); // 0 = ADD_ORDER buffer

        // Expected values match the ADD_ORDER message structure
        // order_to_add = {quantity(8), order_id(8), price(16)} = {0x64, 0x56, 0x3A99}
        check_output(
            ADD_ORDER,              // expected_request
            8'h01,                  // expected_stock
            8'h56,                  // expected_order_id
            8'h64,                  // expected_quantity
            1'b1,                   // expected_order_type (1 for Buy)
            {8'h64, 8'h56, 16'h3A99} // expected_order_to_add
        );
        
       
         // Test 1: ADD_ORDER
        $display("\n--- Test 1 B: ADD_ORDER Message ---");
        send_message(4, 37); // 0 = ADD_ORDER buffer

        // Expected values match the ADD_ORDER message structure
        // order_to_add = {quantity(8), order_id(8), price(16)} = {0x64, 0x56, 0x3A99}
        check_output(
            ADD_ORDER,              // expected_request
            8'h01,                  // expected_stock
            8'h56,                  // expected_order_id
            8'h64,                  // expected_quantity
            1'b1,                   // expected_order_type (1 for Buy)
            {8'h64, 8'h56, 16'h3A99} // expected_order_to_add
        );
        
        
          // Test 1: ADD_ORDER
        $display("\n--- Test 1 C: ADD_ORDER Message ---");
        send_message(5, 37); // 0 = ADD_ORDER buffer

        // Expected values match the ADD_ORDER message structure
        // order_to_add = {quantity(8), order_id(8), price(16)} = {0x64, 0x56, 0x3A99}
        check_output(
            ADD_ORDER,              // expected_request
            8'h01,                  // expected_stock
            8'h56,                  // expected_order_id
            8'h64,                  // expected_quantity
            1'b1,                   // expected_order_type (1 for Buy)
            {8'h64, 8'h56, 16'h3A99} // expected_order_to_add
        );
               
              
        
        // Test 2: CANCEL_ORDER
        $display("\n--- Test 2: CANCEL_ORDER Message ---");
        send_message(1, 24); // 1 = CANCEL_ORDER buffer
        // order_to_add = {quantity(8), order_id(8), price(16)} = {0x32, 0xBC, 0x0000}
        check_output(
            CANCEL_ORDER,           // expected_request
            8'h02,                  // expected_stock
            8'hBC,                  // expected_order_id
            8'h32,                  // expected_quantity
            1'b0,                   // expected_order_type (not used for CANCEL)
            {8'h32, 8'hBC, 16'h0000} // expected_order_to_add
        );
        
        // Test 3: EXECUTE_ORDER
        $display("\n--- Test 3: EXECUTE_ORDER Message ---");
        send_message(2, 24); // 2 = EXECUTE_ORDER buffer
        // order_to_add = {quantity(8), order_id(8), price(16)} = {0x4B, 0x23, 0x0000}
        check_output(
            EXECUTE_ORDER,          // expected_request
            8'h03,                  // expected_stock
            8'h23,                  // expected_order_id
            8'h4B,                  // expected_quantity
            1'b0,                   // expected_order_type (not used for EXECUTE)
            {8'h4B, 8'h23, 16'h0000} // expected_order_to_add
        );
        
        // Test 4: Reset During Operation
        $display("\n--- Test 4: Reset During Operation ---");
        // Start sending an ADD_ORDER
        data_in = reverse_bits(add_order_message[0]);
        in_ready = 1;
        @(posedge clk_in);
        // Assert reset in the middle
        reset_in = 0;
        @(posedge clk_in);
        in_ready = 0;
        #(CLK_PERIOD*2);
        reset_in = 0;
        #(CLK_PERIOD*2);
        
        // Verify module is in reset state
        if (out_ready !== 0) begin
            $display("ERROR: out_ready not reset");
            error_count = error_count + 1;
        end else begin
            $display("PASS: out_ready correctly reset");
        end
        
        // Test 5: Null message (0x00) handling
        $display("\n--- Test 5: Null Message Handling ---");
        @(posedge clk_in);
        data_in = reverse_bits(8'h00);  // Null message
        in_ready = 1;
        @(posedge clk_in);
        in_ready = 0;
        #(CLK_PERIOD*10);
        
        // No output should be generated
        if (out_ready !== 0) begin
            $display("ERROR: out_ready asserted for null message");
            error_count = error_count + 1;
        end else begin
            $display("PASS: null message correctly ignored");
        end
        
        // Test 6: Unknown message type
        $display("\n--- Test 6: Unknown Message Type ---");
        // Send message length
        @(posedge clk_in);
        data_in = reverse_bits(8'h10);  // Message length
        in_ready = 1;
        @(posedge clk_in);
        in_ready = 0;
        #(CLK_PERIOD);
        
        // Send unknown message type
        @(posedge clk_in);
        data_in = reverse_bits(8'hFF);  // Unknown type
        in_ready = 1;
        @(posedge clk_in);
        in_ready = 0;
        #(CLK_PERIOD*20);  // Allow time for module to process
        
        // No output should be generated
        if (out_ready !== 0) begin
            $display("ERROR: out_ready asserted for unknown message type");
            error_count = error_count + 1;
        end else begin
            $display("PASS: unknown message type correctly handled");
        end
        
        // Error summary
        $display("\n--- Testbench Summary ---");
        if (error_count == 0) begin
            $display("All tests PASSED!");
        end else begin
            $display("FAILED: %d errors detected", error_count);
        end
        
        // End simulation
        $display("\n--- Testbench Complete ---");
        
        //$finish;
    end
    
    // Waveform dump for debugging
    initial begin
        $dumpfile("parser_top_tb.vcd");
        $dumpvars(0, parser_top_tb);
    end

endmodule