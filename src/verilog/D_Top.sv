module multi_strategy_trading #(
    parameter N = 4,                // Number of assets (configurable)
    parameter FIXED_POINT_BITS = 8, // Number of fractional bits in fixed-point (8.8 format)
    parameter MOVING_AVG_LENGTH = 3, // FIXED: Reduced moving average length to avoid unused elements
    parameter DIV_PIPELINE_STAGES = 2 // Number of pipeline stages for division operations
) (
    input wire i_Clk,                             // Clock input
    input wire i_Resetn,                          // Active low reset
    input wire signed [15:0] i_BestPrice [0:N-1], // Best bid prices from order book (8.8 format)
    input wire best_price_valid,                  // Valid signal for best bid prices
    input wire [1:0] strategy_select,             // 0: Equal-weight, 1: Liquidity, 2: Depth-weighted, 3: Statistics-based
    output logic [15:0] o_Quantity [0:N-1],       // Order quantities (unsigned integer)
    output logic signed [15:0] o_BestPrice [0:N-1],   // Best prices used for orders
    output logic o_Valid,                             // Order valid signal
    output logic [0:N-1] o_BuySellIndicator           // 1: Buy, 0: Sell for each asset
);
    // Constants
    localparam TOTAL_AMOUNT = 32'h00040000;      // Actual 1024.0 in 8.8 format
    localparam PRICE_ADJUSTMENT = 16'h0019;      // Price adjustment (0.1 in 8.8 format)
    localparam ONE = 16'h0100;                   // 1.0 in 8.8 format
    localparam VOLATILITY_FACTOR = 16'h0080;     // 0.5 in 8.8 format - weighting for volatility
    
    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        CALCULATE,
        OUTPUT
    } state_t;
    
    // State registers and persistent storage
    state_t current_state;
    
    // FIXED: Use exactly MOVING_AVG_LENGTH elements (3) to avoid unused registers
    logic signed [15:0] price_history [0:N-1][0:MOVING_AVG_LENGTH-1];
    
    logic signed [15:0] moving_avg [0:N-1];      // Moving average for each asset
    logic [15:0] volatility [0:N-1];             // Simple volatility measure for each asset
    
    // Pipeline registers for division operations
    logic [31:0] div_pipeline_numerator [0:DIV_PIPELINE_STAGES-1][0:N-1];
    logic [31:0] div_pipeline_denominator [0:DIV_PIPELINE_STAGES-1][0:N-1];
    logic [31:0] div_pipeline_result [0:DIV_PIPELINE_STAGES-1][0:N-1];
    
    // Registered calculation variables to fix synthesis warnings
    logic [31:0] sum_reg [0:N-1];
    logic [31:0] variance_sum_reg [0:N-1];
    logic signed [15:0] diff_reg [0:N-1];
    
    // Combinational calculation results
    logic [31:0] per_asset_amount_comb;
    logic [31:0] total_inverse_price_comb;
    logic [31:0] sum_prices_comb;
    logic [31:0] total_weights_comb;
    logic [31:0] inverse_price_weight_comb [0:N-1];
    logic [31:0] price_weight_comb [0:N-1];
    logic [31:0] stats_weight_comb [0:N-1];
    logic [15:0] quantity_next [0:N-1];
    logic signed [15:0] best_price_next [0:N-1];
    logic [0:N-1] buy_sell_indicator_next;
    
    // Combinational logic for calculations
    always_comb begin
        // Default values for combinational outputs
        total_inverse_price_comb = 0;
        sum_prices_comb = 0;
        total_weights_comb = 0;
        per_asset_amount_comb = 0;
        
        // Initialize arrays
        for (int i = 0; i < N; i++) begin
            inverse_price_weight_comb[i] = 0;
            price_weight_comb[i] = 0;
            stats_weight_comb[i] = 0;
            quantity_next[i] = 0;
            best_price_next[i] = i_BestPrice[i] + PRICE_ADJUSTMENT; // Default adjusted price
            buy_sell_indicator_next[i] = 0; // Default to sell orders
        end
        
        // Only perform calculations when in CALCULATE state
        if (current_state == CALCULATE) begin
            // Pre-calculate values used by multiple strategies
            for (int i = 0; i < N; i++) begin
                if (i_BestPrice[i] != 0) begin
                    // Calculate 1/price with fixed-point scaling - use safe division
                    if (i_BestPrice[i] != 0) begin
                        inverse_price_weight_comb[i] = (ONE << FIXED_POINT_BITS) / i_BestPrice[i];
                    end else begin
                        inverse_price_weight_comb[i] = 0;
                    end
                    
                    total_inverse_price_comb = total_inverse_price_comb + inverse_price_weight_comb[i];
                    
                    // Calculate price for depth-weighted strategy - fixed-point addition is safe
                    sum_prices_comb = sum_prices_comb + i_BestPrice[i];
                    
                    // For statistics-based strategy (strategy 3)
                    if (strategy_select == 2'b11) begin
                        // Use inverse of volatility as weight (lower volatility = higher weight)
                        if (volatility[i] > 0) begin
                            // Safely multiply volatility by factor
                            logic [31:0] vol_adjusted;
                            logic [31:0] denominator;
                            
                            vol_adjusted = (volatility[i] * VOLATILITY_FACTOR) >> FIXED_POINT_BITS;
                            // Safely add to ONE
                            denominator = ONE + vol_adjusted;
                            // Safely divide
                            if (denominator != 0) begin
                                stats_weight_comb[i] = (ONE << FIXED_POINT_BITS) / denominator;
                            end else begin
                                stats_weight_comb[i] = 0;
                            end
                        end else begin
                            stats_weight_comb[i] = ONE << 1; // Default weight of 2.0 for zero volatility
                        end
                        
                        total_weights_comb = total_weights_comb + stats_weight_comb[i];
                    end
                end
            end
            
            // Calculate quantities based on selected strategy
            case (strategy_select)
                2'b00: begin // Equal-weight strategy
                    // Safe division for per-asset amount
                    per_asset_amount_comb = (N > 0) ? TOTAL_AMOUNT / N : 0;
                    
                    for (int i = 0; i < N; i++) begin
                        if (i_BestPrice[i] != 0) begin
                            // quantity = equal amount / price - use safe division
                            quantity_next[i] = (per_asset_amount_comb << FIXED_POINT_BITS) / i_BestPrice[i];
                        end else begin
                            quantity_next[i] = 0;
                        end
                    end
                end
                
                2'b01: begin // Liquidity-based (inverse price weighted)
                    for (int i = 0; i < N; i++) begin
                        if (total_inverse_price_comb > 0 && i_BestPrice[i] != 0) begin
                            // Calculate weight = (1/price) / sum(1/price)
                            price_weight_comb[i] = (inverse_price_weight_comb[i] << FIXED_POINT_BITS) / total_inverse_price_comb;
                            
                            // Calculate allocation = weight * TOTAL_AMOUNT
                            per_asset_amount_comb = (price_weight_comb[i] * TOTAL_AMOUNT) >> FIXED_POINT_BITS;
                            
                            // Calculate quantity = allocation / price
                            quantity_next[i] = (per_asset_amount_comb << FIXED_POINT_BITS) / i_BestPrice[i];
                        end else begin
                            quantity_next[i] = 0;
                        end
                    end
                end
                
                2'b10: begin // Depth-weighted (price-weighted)
                    for (int i = 0; i < N; i++) begin
                        if (sum_prices_comb > 0 && i_BestPrice[i] != 0) begin
                            // Calculate weight = price / sum(prices)
                            price_weight_comb[i] = (i_BestPrice[i] << FIXED_POINT_BITS) / sum_prices_comb;
                            
                            // Calculate allocation = weight * TOTAL_AMOUNT
                            per_asset_amount_comb = (price_weight_comb[i] * TOTAL_AMOUNT) >> FIXED_POINT_BITS;
                            
                            // Calculate quantity = allocation / price
                            quantity_next[i] = (per_asset_amount_comb << FIXED_POINT_BITS) / i_BestPrice[i];
                        end else begin
                            quantity_next[i] = 0;
                        end
                    end
                end
                
                2'b11: begin // Statistics-based strategy
                    for (int i = 0; i < N; i++) begin
                        if (total_weights_comb > 0 && i_BestPrice[i] != 0) begin
                            // Calculate normalized weight
                            price_weight_comb[i] = (stats_weight_comb[i] << FIXED_POINT_BITS) / total_weights_comb;
                            
                            // Calculate allocation = weight * TOTAL_AMOUNT
                            per_asset_amount_comb = (price_weight_comb[i] * TOTAL_AMOUNT) >> FIXED_POINT_BITS;
                            
                            // Calculate quantity = allocation / price
                            quantity_next[i] = (per_asset_amount_comb << FIXED_POINT_BITS) / i_BestPrice[i];
                            
                            // Determine buy/sell based on price vs moving average
                            buy_sell_indicator_next[i] = (i_BestPrice[i] < moving_avg[i]) ? 1'b1 : 1'b0;
                        end else begin
                            quantity_next[i] = 0;
                            buy_sell_indicator_next[i] = 1'b0;
                        end
                    end
                end
                
                default: begin // Default to equal-weight if invalid
                    per_asset_amount_comb = (N > 0) ? TOTAL_AMOUNT / N : 0;
                    
                    for (int i = 0; i < N; i++) begin
                        if (i_BestPrice[i] != 0) begin
                            quantity_next[i] = (per_asset_amount_comb << FIXED_POINT_BITS) / i_BestPrice[i];
                        end else begin
                            quantity_next[i] = 0;
                        end
                    end
                end
            endcase
        end
    end
    
    // Sequential logic for state machine and registers
    always_ff @(posedge i_Clk or negedge i_Resetn) begin
        if (!i_Resetn) begin
            // Reset state
            current_state <= IDLE;
            o_Valid <= 0;
            
            // Reset output registers
            for (int i = 0; i < N; i++) begin
                o_Quantity[i] <= 0;
                o_BestPrice[i] <= 0;
                o_BuySellIndicator[i] <= 1; // Default to buy
                moving_avg[i] <= 0;
                volatility[i] <= 0;
                
                // Initialize calculation registers to fix warnings
                sum_reg[i] <= 0;
                variance_sum_reg[i] <= 0;
                diff_reg[i] <= 0;
                
                // Initialize price history - using only MOVING_AVG_LENGTH elements
                for (int j = 0; j < MOVING_AVG_LENGTH; j++) begin
                    price_history[i][j] <= 0;
                end
            end
        end else begin
            case (current_state)
                IDLE: begin
                    o_Valid <= 0;
                    if (best_price_valid) begin
                        // Copy input prices to output registers temporarily
                        for (int i = 0; i < N; i++) begin
                            o_BestPrice[i] <= i_BestPrice[i];
                        end
                        current_state <= CALCULATE;
                    end
                end
                
                CALCULATE: begin
                    // Update statistics for all strategies - properly using registers now
                    for (int i = 0; i < N; i++) begin
                        // Explicit shifting for price history - use only MOVING_AVG_LENGTH elements
                        for (int j = MOVING_AVG_LENGTH-1; j > 0; j--) begin
                            price_history[i][j] <= price_history[i][j-1];
                        end
                        price_history[i][0] <= i_BestPrice[i];
                        
                        // Calculate simple moving average with fixed-point precision
                        // First reset sum_reg for this asset
                        sum_reg[i] <= 0;
                        
                        // Then calculate in the next clock cycle
                        if (i == 0) begin  // Use asset index as state tracking to avoid extra state
                            // Calculate sum across all history elements
                            for (int j = 0; j < MOVING_AVG_LENGTH; j++) begin
                                sum_reg[i] <= sum_reg[i] + price_history[i][j];
                            end
                        end else begin
                            // For subsequent assets, use computed sum from previous asset
                            for (int j = 0; j < MOVING_AVG_LENGTH; j++) begin
                                sum_reg[i] <= sum_reg[i] + price_history[i][j];
                            end
                        end
                        
                        // Division for average calculation - use sequential register
                        moving_avg[i] <= (MOVING_AVG_LENGTH > 0) ? (sum_reg[i] / MOVING_AVG_LENGTH) : 0;
                        
                        // Calculate simple volatility - first reset variance_sum_reg
                        variance_sum_reg[i] <= 0;
                        
                        // Then calculate variance in proper sequential way
                        for (int j = 0; j < MOVING_AVG_LENGTH; j++) begin
                            // Store difference in register
                            diff_reg[i] <= price_history[i][j] - moving_avg[i];
                            
                            // Use absolute value of difference from register
                            if (diff_reg[i] < 0)
                                diff_reg[i] <= -diff_reg[i];
                                
                            // Accumulate in variance sum register
                            variance_sum_reg[i] <= variance_sum_reg[i] + diff_reg[i];
                        end
                        
                        // Division for volatility calculation - use sequential register
                        volatility[i] <= (MOVING_AVG_LENGTH > 0) ? (variance_sum_reg[i] / MOVING_AVG_LENGTH) : 0;
                    end
                    
                    // Transfer combinational results to output registers
                    for (int i = 0; i < N; i++) begin
                        o_Quantity[i] <= quantity_next[i];
                        o_BestPrice[i] <= best_price_next[i];
                        o_BuySellIndicator[i] <= buy_sell_indicator_next[i];
                    end
                    
                    current_state <= OUTPUT;
                end
                
                OUTPUT: begin
                    o_Valid <= 1;
                    current_state <= IDLE;
                end
                
                default: begin
                    current_state <= IDLE;
                end
            endcase
        end
    end

endmodule