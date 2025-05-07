`timescale 1ns / 1ps
 
module HFT_top(
    input clk,
    input rst,
    input rx,
    output tx
//    output   [7:0] x,
//    output [2:0] y,
//    output [10:0] z
);

    wire rx_ready;
    wire [7:0] rx_data;
    wire [7:0] data_in;
    wire in_ready;
 
    uart_rx uart (
        //inputs
        .clk(clk),
        .rst(rst),
        .rx(rx),
		
        //outputs
        .rx_ready(rx_ready),
        .rx_data(rx_data)
    );
	
    wire [1:0] stock_identifier;
    wire [31:0] order_to_add;
    wire [7:0] quantity;
    wire [2:0] request;
    wire [7:0] order_id;
    wire order_type_out_add;
    wire out_ready;
    wire [7:0] message_monitor;
    wire [2:0] current_state_monitor;
    wire [10:0] count_monitor;
    
	
	
    parser_top parser (
        //inputs
        .clk_in(clk),
        .reset_in(rst),
        .data_in(rx_data),
        .in_ready(rx_ready),
		
        //outputs
        .stock_identifier(stock_identifier),
        .order_to_add(order_to_add),
        .quantity(quantity),
        .request(request),
        .order_id(order_id),
        .order_type_out_add(order_type_out_add),
        .out_ready(out_ready)
//        .message_monitor(message_monitor),
//        .current_state_monitor(current_state_monitor),
//        .count_monitor(count_monitor)        
    );
    
//    wire [7:0] x;
//    wire [2:0] y;
//    wire [10:0] z;
    
//    assign x = message_monitor;
//    assign y = current_state_monitor;
//    assign z = count_monitor;
    
    

	wire is_busy;
	wire best_price_valid;
	wire [63:0] best_price_stocks;
	wire [3:0] best_prices_valid;
	wire [31:0] size_of_stocks;
 
    order_book_wrapper order_book_top (
        //inputs
        .clk_in(clk),
        .rst_in(rst),
        .stock_to_add(stock_identifier),
        .order_to_add(order_to_add),
        .start(out_ready),
        .quantity(quantity),
        .request(request),
        .order_id(order_id),
		
        //outputs
        .is_busy(is_busy),
        .best_price_valid(best_price_valid),
        .best_price_stocks(best_price_stocks),
        .best_prices_valid(best_prices_valid),
        .size_of_stocks(size_of_stocks)
    );
    
    wire signed [15:0] i_BestPrice3, i_BestPrice2, i_BestPrice1, i_BestPrice0;
	
	assign i_BestPrice0 = $signed(best_price_stocks[15:0]);
	assign i_BestPrice1 = $signed(best_price_stocks[31:16]);
	assign i_BestPrice2 = $signed(best_price_stocks[47:32]);
	assign i_BestPrice3 = $signed(best_price_stocks[63:48]);
	
	
	wire [15:0] o_Quantity0, o_Quantity1, o_Quantity2, o_Quantity3;
	wire [15:0] o_BestPrice0, o_BestPrice1, o_BestPrice2, o_BestPrice3;
	wire o_Valid, o_BuySellIndicator0, o_BuySellIndicator1, o_BuySellIndicator2, o_BuySellIndicator3;
	
 
    Top_Trading trading_instance (
        //inputs
        .i_Clk(clk),                          // Clock input
        .i_Resetn(!rst),                    // Active low reset
        .i_BestPrice0(i_BestPrice0),            // Best bid price for asset 0
        .i_BestPrice1(i_BestPrice1),            // Best bid price for asset 1
        .i_BestPrice2(i_BestPrice2),            // Best bid price for asset 2
        .i_BestPrice3(i_BestPrice3),            // Best bid price for asset 3
        .best_price_valid(best_price_valid),    // Valid signal for best bid prices
        .strategy_select(2'b00),      // Strategy selection: 0-Equal, 1-Liquidity, 2-Depth, 3-Statistics
		
        //outputs
        .o_Quantity0(o_Quantity0),              // Order quantity for asset 0
        .o_Quantity1(o_Quantity1),              // Order quantity for asset 1
        .o_Quantity2(o_Quantity2),              // Order quantity for asset 2
        .o_Quantity3(o_Quantity3),              // Order quantity for asset 3
        .o_BestPrice0(o_BestPrice0),            // Best price used for asset 0
        .o_BestPrice1(o_BestPrice1),            // Best price used for asset 1
        .o_BestPrice2(o_BestPrice2),            // Best price used for asset 2
        .o_BestPrice3(o_BestPrice3),            // Best price used for asset 3
        .o_Valid(o_Valid),                      // Order valid signal
        .o_BuySellIndicator0(o_BuySellIndicator0), // Buy/Sell indicator for asset 0
        .o_BuySellIndicator1(o_BuySellIndicator1), // Buy/Sell indicator for asset 1
        .o_BuySellIndicator2(o_BuySellIndicator2), // Buy/Sell indicator for asset 2
        .o_BuySellIndicator3(o_BuySellIndicator3)  // Buy/Sell indicator for asset 3
    );
	
	
    wire tx_start;
    wire [7:0] tx_data;

    custom_msg_generator msg_gen_instance (
        //inputs
        .clk_in(clk),
        .reset_in(rst),
        .tx_busy(tx_busy),
        .o_Quantity0(o_Quantity0),
        .o_Quantity1(o_Quantity1),
        .o_Quantity2(o_Quantity2),
        .o_Quantity3(o_Quantity3),
        .o_BestPrice0(o_BestPrice0),
        .o_BestPrice1(o_BestPrice1),
        .o_BestPrice2(o_BestPrice2),
        .o_BestPrice3(o_BestPrice3),
        .o_Valid(o_Valid),
        .o_BuySellIndicator0(o_BuySellIndicator0),
        .o_BuySellIndicator1(o_BuySellIndicator1),
        .o_BuySellIndicator2(o_BuySellIndicator2),
        .o_BuySellIndicator3(o_BuySellIndicator3),
		
        //outputs
        .tx_start(tx_start),
        .tx_data(tx_data)
    );

 
    uart_tx uarttx (
        //inputs
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .tx_data(tx_data),
		
        //outputs
        .tx_busy(tx_busy),
        .tx(tx)
    );
	

    ila_0 your_instance_name (
	   .clk(clk), // input wire clk


	   .probe0(rx_ready), // input wire [0:0]  probe0  
	   .probe1(rx), // input wire [0:0]  probe1 
	   
	   .probe2(is_busy), // input wire [0:0]  probe2 
	   
	   .probe3(best_price_valid), // input wire [0:0]  probe3 
	   .probe4(o_Valid), // input wire [0:0]  probe4 
	   
	   .probe5(tx_start), // input wire [0:0]  probe5 
	   .probe6(tx_busy), // input wire [0:0]  probe6 
	   
	   .probe7(request[0]), // input wire [0:0]  probe7 
	   .probe8(request[1]), // input wire [0:0]  probe8 
	   
	   .probe9(out_ready), // input wire [0:0]  probe9
	   .probe10(rx_data) // input wire [7:0]  probe10
    );
    
    
endmodule