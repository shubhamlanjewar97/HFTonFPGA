`timescale 1ns / 1ps

`include "../../../new/constants.v"

module add_order #(parameter IS_MAX=`MAX)(
	input clk_in,
	input rst,
	input [`TOTAL_BITS-1:0] order,
	input start,
	input valid,
	input [`SIZE_INDEX:0] size,
	input [`PRICE_INDEX:0] best_price,
	input price_valid,
	output reg [`ADDRESS_INDEX:0] addr,
	output reg mem_start,
	output reg [`TOTAL_BITS-1:0] data_w,
	output reg is_write,
	output reg ready,
	output [`SIZE_INDEX:0] size_update_o,
	output reg [`PRICE_INDEX:0] add_best_price
);


	reg [1:0] add_mem_state;
	
	parameter START = 0;
	parameter PROGRESS = 1;
	
	reg [`SIZE_INDEX:0] size_update;
	
	assign size_update_o = size_update;
	
	always @(posedge clk_in) begin
		if(rst) begin
			addr <= 0;
			mem_start <= 0;
			data_w <= 0;
			ready <= 0;
			add_best_price <= 0;
			add_mem_state <= START;
			size_update <= 0;
			is_write <= 0;
		end
		else begin
			case(add_mem_state)
				START: begin
					ready <= 0;
					if(start) begin
						if(size < `MAX_INDEX) begin
							addr <= order[`PRICE_INDEX+`ORDER_INDEX+1:`PRICE_INDEX+1];
							is_write <= 1;
							size_update <= size + 1;
							add_mem_state <= PROGRESS;
							data_w <= order;
							mem_start <= 1;
							if(!price_valid || (order[`PRICE_INDEX:0] > best_price) == IS_MAX) begin
								add_best_price <= order[`PRICE_INDEX:0];
							end
							else begin
								add_best_price <= best_price;
							end
						end
					end
				end
				PROGRESS: begin
					mem_start <= 0;
					if(valid) begin
						ready <= 1;
						add_mem_state <= START;
					end
				end
			endcase
		end
	end
endmodule