`timescale 1ns / 1ps

`include "../../../new/constants.v"

module memory_manager(
    input clk_in,
	input rst,
    input start,
    input is_write,
    input [`ADDRESS_INDEX:0] addr,
    input [`TOTAL_BITS-1:0] data_i,
    output [`TOTAL_BITS-1:0] data_o,
    output reg valid
);

    reg [10:0] counter;
    reg write;
	
    parameter WAITING = 0;
    parameter STARTED = 1;
	
    reg [2:0] state;
    reg enable;
    
    blk_mem_gen_0 mem (
        .clka(clk_in),
        .addra(addr),	//8 bits
        .douta(data_o),	//32 bits
        .dina(data_i),	//32 bits
        .ena(enable),
        .wea(write)
    );
    //ila_0 my_ila(.clk(clk_in), .probe0(start_book), .probe1(best_price_o), .probe2(current_size));
    
    always @(posedge clk_in) begin
		if(rst) begin
			state <= WAITING;
			valid <= 0;
			counter <= 0;
			write <= 0;
			enable <= 0;
		end
		else begin
			case(state)
				WAITING: begin
					valid <= 0;
					if(start) begin
						write <= is_write;
						state <= STARTED;
						counter <= 1;
						enable <= 1;
					end
				end
				STARTED: begin
					if(counter < `BRAM_LATENCY) begin
						counter <= counter + 1;
					end
					else begin
						state <= WAITING;
						counter <= 0;
						valid <= 1;
						enable <= 0;
						write <= 0;
					end
				end
			endcase
		end
    end
endmodule