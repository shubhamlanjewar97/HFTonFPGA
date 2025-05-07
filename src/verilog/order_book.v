`timescale 1ns / 1ps
`include "../../../new/constants.v"

module order_book #(parameter IS_MAX = `MAX) (
	input clk_in,
	input rst_in,
	input [`TOTAL_BITS-1:0] order_to_add,
	input start_book,
	//input delete,
	input [2:0] request,	//ADD_ORDER, CANCEL_ORDER, EXECUTE_ORDER
	input [`ORDER_INDEX:0] order_id, //should be supplied for a cancel / trade
	input [`QUANTITY_INDEX:0] quantity, // should be supplied for a trade
	output is_busy_o,
	output [`CANCEL_UPDATE_INDEX:0] cancel_update,		//(3 bits)
	output [`PRICE_INDEX:0] best_price_o,
	output best_price_valid,
	output [`SIZE_INDEX:0] size_book
);

//	parameter MAX_INDEX = 0;
	parameter START = 0;
	parameter PROGRESS = 1;
	
	reg start;
	reg [`ADDRESS_INDEX:0] addr;
	wire [`ADDRESS_INDEX:0] add_addr;
	reg [`PRICE_INDEX:0] best_price;
	
	assign best_price_o = best_price;
	
	wire [`PRICE_INDEX:0] add_best_price;
	reg [`PRICE_INDEX:0] decrease_best_price;
	
	reg [`TOTAL_BITS-1:0] data_i;
	wire [`TOTAL_BITS-1:0] data_o;
	wire [`TOTAL_BITS-1:0] add_data_w;
	wire [`TOTAL_BITS-1:0] decrease_w;
	
	wire [`PRICE_INDEX:0] del_best_price;
	
	reg mem_start;
	reg valid;
	reg is_write;
	wire is_write_add;
	reg add_start;
	reg decrease_start;
	wire add_ready;
	wire decrease_ready;
	wire add_mem_start;
	reg units_busy;
	reg [`QUANTITY_INDEX:0] price_distr [0:`MAX_INDEX];
	
	wire valid_mem;
	
	parameter WAITING_STATE= 2'b00;
	parameter PROGRESS_STATE = 2'b01;
	
	reg [2:0] request_latched;
	
    //contains the FSM for managing the BRAM
	memory_manager book_mem (
		.clk_in(clk_in),
		.rst(rst_in),
		.start(mem_start),
		.is_write(is_write),
		.addr(addr),
		.data_i(data_i),
		.data_o(data_o),
		.valid(valid_mem)
	);
	
	reg is_busy;
	
	assign is_busy_o = is_busy;
	
	reg [`SIZE_INDEX:0] current_size = 0;
	wire [`SIZE_INDEX:0] add_size;
	wire [`SIZE_INDEX:0] decrease_size;
	
	assign size_book = current_size;
	assign best_price_valid = current_size > 0;
	
	//adding order to the BRAM logic
	add_order order_adder(
		//inputs
		.clk_in(clk_in),
		.rst(rst_in),
		.order(order_to_add),
		.start(add_start),
		.valid(valid_mem),
		.price_valid(best_price_valid),
		.best_price(best_price),
		.size(current_size),
		
		//outputs
		.addr(add_addr),
		.mem_start(add_mem_start),
		.is_write(is_write_add),
		.ready(add_ready),
		.size_update_o(add_size),
		.data_w(add_data_w),
		.add_best_price(add_best_price)
	);
	
	wire [`TOTAL_BITS-1:0] read_output;
	wire [`ADDRESS_INDEX+2:0] mem_control;
	
	assign read_output = data_o;
	
	reg delete_actual;
	
	//decreading the order from the BRAM
	decrease_order order_decreaser(
		//inputs
		.clk_in(clk_in),
		.rst(rst_in),
		.id(order_id),
		.quantity(quantity),
		.delete(delete_actual),
		.in_best_price(best_price),
		.mem_valid(valid_mem),
		.size(current_size),
		.start(decrease_start),
		.data_r(read_output),
		
		//outputs
		.mem_control(mem_control),
		.data_w(decrease_w),
		.ready(decrease_ready),
		.size_update_o(decrease_size),
		.update(cancel_update),
		.best_price(del_best_price)
	);
	
	always @(*) begin
		if(is_busy ) begin
			case(request_latched)
				`ADD_ORDER: begin
								addr = add_addr;
								is_write = is_write_add;
								mem_start = add_mem_start;
								data_i = add_data_w;
								units_busy = !add_ready;
							end
				//R, EXECUTE_ORDER:
				`CANCEL_ORDER, `EXECUTE_ORDER: begin
								addr = mem_control[`ADDRESS_INDEX:0];
								is_write = mem_control[`ADDRESS_INDEX+1];
								mem_start = mem_control[`ADDRESS_INDEX+2];
								data_i = decrease_w;
								units_busy = !decrease_ready;
							end
				default: begin
								addr = 0;
								units_busy = 0;
								is_write = 0;
								mem_start = 0;
								data_i = 0;
							end
			endcase
		end
		else begin
			addr = 0;
			units_busy = 0;
			is_write = 0;
			mem_start = 0;
			data_i = 0;
		end
	end
	
	reg [3:0] add_state;
	reg [1:0] add_mem_state;
	reg [1:0] current_state;
	
	//ila_0 book_ila(.clk(clk_in), .probe0(start_book), .probe1(best_price_o), .probe2(current_size));
	
	integer i;
	always @(posedge clk_in) begin
		if(rst_in) begin
			current_size <= 0;
			//add_size <= 0;
			is_busy <= 0;
			for(i = 0; i < `MAX_INDEX; i=i+1) begin
				price_distr[i] <= 0;
			end
			// decrease_size <= 0;
			
			request_latched <= 0;
			decrease_start <= 0;
			add_mem_state <= 0;
			add_state <= 0;
			current_state <= 0;
			decrease_best_price <= 0;
			start <= 0;
			best_price <= 0;
			valid <= 0;
		end
		else if(is_busy) begin
			add_start <= 0;
			decrease_start <= 0;
			if(!units_busy) begin
				is_busy <= 0;
				case(request_latched)
					`ADD_ORDER: begin
						current_size <= add_size;
						best_price <= add_best_price;
					end
					`CANCEL_ORDER, `EXECUTE_ORDER: begin
						current_size <= decrease_size;
						best_price <= del_best_price;
					end
				endcase
			end
		end
		else if(start_book) begin
			request_latched <= request;
			is_busy <= 1;
			case(request)
				`ADD_ORDER: begin
					add_start <= 1;
					price_distr[order_to_add[`PRICE_INDEX:0]] <= price_distr[order_to_add[`PRICE_INDEX:0]] + order_to_add[`TOTAL_BITS-1:`TOTAL_BITS-`QUANTITY_INDEX-1];
				end
				`CANCEL_ORDER: begin
					decrease_start <= 1;
					delete_actual <= 1;
				end
				`EXECUTE_ORDER: begin
					decrease_start <= 1;
					delete_actual <= 0;
				end
			endcase
		end
	end
endmodule