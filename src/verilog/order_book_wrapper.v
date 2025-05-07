`timescale 1ns / 1ps

`include "../../../new/constants.v"

module order_book_wrapper(
	input clk_in,
	input rst_in,
	input [`STOCK_INDEX:0] stock_to_add,	//which stock to add (2 bits)
	input [`TOTAL_BITS-1:0] order_to_add,		//what order to add
	input start,	//start signal
	input [`QUANTITY_INDEX:0] quantity,	//quantity to decrease order by (8 bits), when request is EXECUTE_ORDER
	input [2:0] request,		//ADD_ORDER, CANCEL_ORDER, EXECUTE_ORDER
	input [`ORDER_INDEX:0] order_id, //should be supplied for a CANCEL_ORDER / EXECUTE_ORDER
	output is_busy,	//high if the book is busy
	output best_price_valid,	//high if the best price is valid in all the stocks
	output reg [`CANCEL_UPDATE_INDEX:0] cancel_update,		//not used
	output [(`NUM_STOCK_INDEX+1)*(`PRICE_INDEX+1)-1:0] best_price_stocks,
	output [`NUM_STOCK_INDEX:0] best_prices_valid,
	output [(`NUM_STOCK_INDEX+1)*(`SIZE_INDEX+1)-1:0] size_of_stocks
);
 
	//wire [(NUM_STOCK_INDEX+1)*(PRICE_INDEX+1)-1:0] best_price_stocks;
	//wire [(NUM_STOCK_INDEX+1)*(SIZE_INDEX+1)-1:0] size_of_stocks;
 
	reg [`NUM_STOCK_INDEX:0] order_book_start;
	wire [`NUM_STOCK_INDEX:0] book_busy;
	// Internal arrays for storing values from order book instances
	wire [`PRICE_INDEX:0] best_price_internal [0:`NUM_STOCK_INDEX];
	wire [`SIZE_INDEX:0] size_internal [0:`NUM_STOCK_INDEX];
	reg [`STOCK_INDEX:0] stock_latched;
	parameter WAITING = 2'b00;
	parameter INITATE = 2'b01;
	parameter PROGRESS = 2'b10;
	reg best_price_valid;
	reg [2:0] state;
	assign is_busy = (state != WAITING);
	// Connect the flattened outputs to the internal arrays
	genvar j;
	generate
		for(j = 0; j <= `NUM_STOCK_INDEX; j = j+1) begin
			// Map the internal arrays to the flattened output ports
			assign best_price_stocks[(j+1)*(`PRICE_INDEX+1)-1:j*(`PRICE_INDEX+1)] = best_price_internal[j];
			assign size_of_stocks[(j+1)*(`SIZE_INDEX+1)-1:j*(`SIZE_INDEX+1)] = size_internal[j];
		end
	endgenerate
	genvar i;
	generate
		for(i = 0; i < `N; i = i+1) begin
			order_book #(.IS_MAX(`MAX)) book(
				//inputs
				.clk_in(clk_in),
				.rst_in(rst_in),
				.order_to_add(order_to_add),
				.request(request),
				.start_book(order_book_start[i]),
				.order_id(order_id),
				.quantity(quantity),
				//outputs
				.is_busy_o(book_busy[i]),
				.best_price_o(best_price_internal[i]),  // Connect to internal array
				.best_price_valid(best_prices_valid[i]),
				.size_book(size_internal[i])            // Connect to internal array
			);
		end
	endgenerate
	// ila_0 wrapper_ila(.clk(clk_in), .probe0(stock_to_add), .probe1(start), .probe2(state));
	always @(posedge clk_in) begin
		if(rst_in) begin
			order_book_start <= 0;
			stock_latched <= 0;
			state <= 0;
			best_price_valid <= 0;
		end
		case(state)
			WAITING: begin
						best_price_valid <= 0;
						if(start) begin
							if(stock_to_add < `NUM_STOCKS) begin
								state <= INITATE;
								stock_latched <= stock_to_add;
								//stock to add from 0 to 1
								order_book_start[stock_to_add] <= 1;
							end
							else begin
							end
						end
					end
			INITATE: begin
						state <= PROGRESS;
						order_book_start[stock_to_add] <= 0;
					end
			PROGRESS: begin
						if(!book_busy[stock_latched]) begin
							state <= WAITING;
							best_price_valid <= &best_prices_valid;
						end
					end
		endcase
	end
endmodule