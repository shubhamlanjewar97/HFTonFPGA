module Top_Trading (
    input wire i_Clk,                      // Clock input
    input wire i_Resetn,                   // Active low reset
    input wire signed [15:0] i_BestPrice0, // Best bid price for asset 0
    input wire signed [15:0] i_BestPrice1, // Best bid price for asset 1
    input wire signed [15:0] i_BestPrice2, // Best bid price for asset 2
    input wire signed [15:0] i_BestPrice3, // Best bid price for asset 3
    input wire best_price_valid,           // Valid signal for best bid prices
    input wire [1:0] strategy_select,      // Strategy selection: 0-Equal, 1-Liquidity, 2-Depth, 3-Statistics
    output wire [15:0] o_Quantity0,        // Order quantity for asset 0
    output wire [15:0] o_Quantity1,        // Order quantity for asset 1
    output wire [15:0] o_Quantity2,        // Order quantity for asset 2
    output wire [15:0] o_Quantity3,        // Order quantity for asset 3
    output wire signed [15:0] o_BestPrice0, // Best price used for asset 0
    output wire signed [15:0] o_BestPrice1, // Best price used for asset 1
    output wire signed [15:0] o_BestPrice2, // Best price used for asset 2
    output wire signed [15:0] o_BestPrice3, // Best price used for asset 3
    output wire o_Valid,                   // Order valid signal
    output wire o_BuySellIndicator0,       // Buy/Sell indicator for asset 0
    output wire o_BuySellIndicator1,       // Buy/Sell indicator for asset 1
    output wire o_BuySellIndicator2,       // Buy/Sell indicator for asset 2
    output wire o_BuySellIndicator3        // Buy/Sell indicator for asset 3
);
    // Constants
    localparam N = 4;                    // Number of assets
    localparam FIXED_POINT_BITS = 8;     // Number of fractional bits in fixed-point (8.8 format)
    localparam MOVING_AVG_LENGTH = 4;    // Length of price history for statistics strategy
    localparam VOLATILITY_FACTOR = 16'h0080; // Weight for volatility (0.5 in 8.8 format)
    localparam DIV_PIPELINE_STAGES = 2;  // Pipeline stages for division operations
    
    // Wire signals for array-based interface to SystemVerilog module
    wire signed [15:0] best_price_array [0:N-1];
    wire [15:0] quantity_array [0:N-1];
    wire signed [15:0] best_price_out_array [0:N-1];
    wire [0:N-1] buy_sell_indicator_array;
    
    // Connect flattened inputs to array format
    assign best_price_array[0] = i_BestPrice0;
    assign best_price_array[1] = i_BestPrice1;
    assign best_price_array[2] = i_BestPrice2;
    assign best_price_array[3] = i_BestPrice3;
    
    // Connect array outputs to flattened outputs
    assign o_Quantity0 = quantity_array[0];
    assign o_Quantity1 = quantity_array[1];
    assign o_Quantity2 = quantity_array[2];
    assign o_Quantity3 = quantity_array[3];
    
    assign o_BestPrice0 = best_price_out_array[0];
    assign o_BestPrice1 = best_price_out_array[1];
    assign o_BestPrice2 = best_price_out_array[2];
    assign o_BestPrice3 = best_price_out_array[3];
    
    assign o_BuySellIndicator0 = buy_sell_indicator_array[0];
    assign o_BuySellIndicator1 = buy_sell_indicator_array[1];
    assign o_BuySellIndicator2 = buy_sell_indicator_array[2];
    assign o_BuySellIndicator3 = buy_sell_indicator_array[3];
    
    // Instantiate the multi_strategy_trading module using SystemVerilog
    multi_strategy_trading #(
        .N(N),
        .FIXED_POINT_BITS(FIXED_POINT_BITS),
        .MOVING_AVG_LENGTH(MOVING_AVG_LENGTH),
        .DIV_PIPELINE_STAGES(DIV_PIPELINE_STAGES)
    ) trading_core (
        .i_Clk(i_Clk),
        .i_Resetn(i_Resetn),
        .i_BestPrice(best_price_array),
        .best_price_valid(best_price_valid),
        .strategy_select(strategy_select),
        .o_Quantity(quantity_array),
        .o_BestPrice(best_price_out_array),
        .o_Valid(o_Valid),
        .o_BuySellIndicator(buy_sell_indicator_array)
    );
endmodule