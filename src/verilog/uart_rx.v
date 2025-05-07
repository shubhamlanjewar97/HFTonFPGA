//// UART Receiver module with fixed timing and additional timing optimizations
//// Baud rate: 115200
//// System clock: 100 MHz
//// Data format: 8 data bits, no parity, 1 stop bit
//// Modified with ACTIVE HIGH reset

module uart_rx #(
    parameter CLK_FREQ = 100000000,   // 100 MHz
    parameter BAUD_RATE = 115200      // 115200 baud
)(
    input wire clk,           // System clock
    input wire rst,           // Active high reset
    input wire rx,            // Serial input
    output reg rx_ready,      // Data ready signal
    output reg [7:0] rx_data  // Received data
);

    // Calculate the number of clock cycles per bit - use parameter for better synthesis
    localparam integer CYCLES_PER_BIT = ((CLK_FREQ + (BAUD_RATE/2)) / BAUD_RATE);
    // Half cycles per bit (for sampling in the middle of a bit)
    localparam integer HALF_CYCLES_PER_BIT = CYCLES_PER_BIT / 2;
    
    // State definitions - use one-hot encoding for better timing
    localparam [3:0] IDLE   = 4'b0001;
    localparam [3:0] START  = 4'b0010;
    localparam [3:0] DATA   = 4'b0100;
    localparam [3:0] STOP   = 4'b1000;
    
    // Internal registers using two-process state machine
    reg [3:0] state, next_state;
    reg [15:0] cycle_count, next_cycle_count;
    reg [2:0] bit_index, next_bit_index;
    reg [7:0] rx_shift_reg, next_rx_shift_reg;
    reg next_rx_ready;
    reg [7:0] next_rx_data;
    
    // Triple-register synchronizer for rx input to prevent metastability
    reg rx_sync1, rx_sync2, rx_sync3;
    wire rx_filtered;
    
    always @(posedge clk) begin
        if (rst) begin
            rx_sync1 <= 1'b1; // Default to idle level
            rx_sync2 <= 1'b1;
            rx_sync3 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
            rx_sync3 <= rx_sync2;
        end
    end
    
    // Simple majority filter for noise immunity
    assign rx_filtered = (rx_sync1 & rx_sync2) | (rx_sync2 & rx_sync3) | (rx_sync1 & rx_sync3);
    
    // Sequential process
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            cycle_count <= 0;
            bit_index <= 0;
            rx_ready <= 1'b0;
            rx_data <= 8'h00;
            rx_shift_reg <= 8'h00;
        end else begin
            state <= next_state;
            cycle_count <= next_cycle_count;
            bit_index <= next_bit_index;
            rx_ready <= next_rx_ready;
            rx_data <= next_rx_data;
            rx_shift_reg <= next_rx_shift_reg;
        end
    end
    
    // Combinational process
    always @(*) begin
        // Default values (hold current state)
        next_state = state;
        next_cycle_count = cycle_count;
        next_bit_index = bit_index;
        next_rx_ready = 1'b0;  // Default rx_ready to 0 (pulse for one cycle only)
        next_rx_data = rx_data;
        next_rx_shift_reg = rx_shift_reg;
        
        case (state)
            IDLE: begin
                next_cycle_count = 0;
                next_bit_index = 0;
                
                // Detect start bit (falling edge)
                if (rx_filtered == 1'b0) begin
                    next_state = START;
                end
            end
            
            START: begin
                // Sample in the middle of the start bit
                if (cycle_count < HALF_CYCLES_PER_BIT) begin
                    next_cycle_count = cycle_count + 1;
                end else begin
                    // Verify it's still low (valid start bit)
                    if (rx_filtered == 1'b0) begin
                        next_cycle_count = 0;
                        next_state = DATA;
                    end else begin
                        // False start, go back to IDLE
                        next_state = IDLE;
                    end
                end
            end
            
            DATA: begin
                if (cycle_count < CYCLES_PER_BIT - 1) begin
                    next_cycle_count = cycle_count + 1;
                end else begin
                    next_cycle_count = 0;
                    // Sample the data bit
                    next_rx_shift_reg = {rx_filtered, rx_shift_reg[7:1]};
                    
                    if (bit_index < 7) begin
                        next_bit_index = bit_index + 1;
                    end else begin
                        next_bit_index = 0;
                        next_state = STOP;
                    end
                end
            end
            
            STOP: begin
                if (cycle_count < CYCLES_PER_BIT - 1) begin
                    next_cycle_count = cycle_count + 1;
                end else begin
                    next_cycle_count = 0;
                    // Check for valid stop bit
                    if (rx_filtered == 1'b1) begin
                        next_rx_data = rx_shift_reg;
                        next_rx_ready = 1'b1;
                    end
                    next_state = IDLE;
                end
            end
            
            default: begin
                next_state = IDLE;
                next_cycle_count = 0;
                next_bit_index = 0;
                next_rx_ready = 1'b0;
            end
        endcase
    end

endmodule



