// Optimized UART TX Module with fixed timing for output path
// Baud rate: 115200
// System clock: 100 MHz
// Data format: 8 data bits, no parity, 1 stop bit
// Modified with ACTIVE HIGH reset

module uart_tx #(
    parameter CLK_FREQ = 100000000,   // 100 MHz
    parameter BAUD_RATE = 115200      // 115200 baud
)(
    input wire clk,           // System clock
    input wire rst,           // Active high reset
    input wire tx_start,      // Start transmission
    input wire [7:0] tx_data, // Data to transmit
    output reg tx_busy,       // Transmitter busy
    output wire tx            // Serial output
);

    // Calculate the number of clock cycles per bit
    localparam integer CYCLES_PER_BIT = ((CLK_FREQ + (BAUD_RATE/2)) / BAUD_RATE);
    
    // State definitions - use one-hot encoding for better timing
    localparam [3:0] IDLE  = 4'b0001;
    localparam [3:0] START = 4'b0010;
    localparam [3:0] DATA  = 4'b0100;
    localparam [3:0] STOP  = 4'b1000;
    
    // Internal registers
    reg [3:0] state, next_state;
    reg [15:0] cycle_count, next_cycle_count;
    reg [2:0] bit_index, next_bit_index;
    reg [7:0] tx_shift_reg, next_tx_shift_reg;
    reg tx_bit, next_tx_bit;  // Internal TX bit before output register
    reg next_tx_busy;
    
    // Synchronize tx_start to prevent metastability
    reg tx_start_sync1, tx_start_sync2;
    always @(posedge clk) begin
        if (rst) begin
            tx_start_sync1 <= 1'b0;
            tx_start_sync2 <= 1'b0;
        end else begin
            tx_start_sync1 <= tx_start;
            tx_start_sync2 <= tx_start_sync1;
        end
    end
    
    // Detect rising edge of tx_start
    wire tx_start_edge = tx_start_sync1 && !tx_start_sync2;
    
    // Two-process state machine
    // Sequential process
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            cycle_count <= 0;
            bit_index <= 0;
            tx_bit <= 1'b1;  // Idle line is high
            tx_busy <= 1'b0;
            tx_shift_reg <= 8'h00;
        end else begin
            state <= next_state;
            cycle_count <= next_cycle_count;
            bit_index <= next_bit_index;
            tx_bit <= next_tx_bit;
            tx_busy <= next_tx_busy;
            tx_shift_reg <= next_tx_shift_reg;
        end
    end
    
    // Combinational process
    always @(*) begin
        // Default values (hold current state)
        next_state = state;
        next_cycle_count = cycle_count;
        next_bit_index = bit_index;
        next_tx_bit = tx_bit;
        next_tx_busy = tx_busy;
        next_tx_shift_reg = tx_shift_reg;
        
        case (state)
            IDLE: begin
                next_tx_bit = 1'b1;  // Idle line is high
                next_tx_busy = 1'b0;
                next_cycle_count = 0;
                next_bit_index = 0;
                
                if (tx_start_edge) begin
                    next_tx_shift_reg = tx_data;
                    next_tx_busy = 1'b1;
                    next_state = START;
                end
            end
            
            START: begin
                next_tx_bit = 1'b0;  // Start bit is low
                
                if (cycle_count < CYCLES_PER_BIT - 1) begin //  if (cycle_count < CYCLES_PER_BIT - 1)
                    next_cycle_count = cycle_count + 1;
                end else begin
                    next_cycle_count = 0;
                    next_state = DATA;
                end
            end
            
            DATA: begin
                next_tx_bit = tx_shift_reg[0];  // LSB first
                
                if (cycle_count < CYCLES_PER_BIT - 1) begin
                    next_cycle_count = cycle_count + 1;
                end else begin
                    next_cycle_count = 0;
                    
                    // Shift the data register
                    next_tx_shift_reg = {1'b0, tx_shift_reg[7:1]};
                    
                    if (bit_index < 7) begin
                        next_bit_index = bit_index + 1;
                    end else begin
                        next_bit_index = 0;
                        next_state = STOP;
                    end
                end
            end
            
            STOP: begin
                next_tx_bit = 1'b1;  // Stop bit is high
                
                if (cycle_count < CYCLES_PER_BIT - 1) begin
                    next_cycle_count = cycle_count + 1;
                end else begin
                    next_cycle_count = 0;
                    next_state = IDLE;
                end
            end
            
            default: begin
                next_state = IDLE;
                next_tx_bit = 1'b1;
                next_tx_busy = 1'b0;
                next_cycle_count = 0;
                next_bit_index = 0;
            end
        endcase
    end

    // Add an output register specifically for the tx signal
    // This is crucial for timing closure on the tx output path
    (* IOB = "TRUE" *) reg tx_out_reg = 1'b1;
    
    // Drive the output register
    always @(posedge clk) begin
        if (rst) begin
            tx_out_reg <= 1'b1;  // Default to idle state
        end else begin
            tx_out_reg <= tx_bit;
        end
    end
    
    // Connect the output register to the tx pin
    assign tx = tx_out_reg;

endmodule