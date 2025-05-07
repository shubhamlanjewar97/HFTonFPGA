`timescale 1ns / 1ps

`include "../../../new/constants.v"

module decrease_order #(parameter SIDE=`BUY_SIDE,
						parameter IS_MAX=`MAX)(
	input clk_in,
	input rst,
	input [`ORDER_INDEX:0] id,
	input [`QUANTITY_INDEX:0] quantity,
	input [`PRICE_INDEX:0] in_best_price,
	input delete,
	input mem_valid,
	input [`SIZE_INDEX:0] size,
	input start,
	input [`TOTAL_BITS-1:0] data_r,
	
	output reg [`ADDRESS_INDEX+2:0] mem_control,
	output reg [`TOTAL_BITS-1:0] data_w,
	output reg ready,
	output [`SIZE_INDEX:0] size_update_o,
	output reg [`CANCEL_UPDATE_INDEX:0] update,
	output reg [`PRICE_INDEX:0] best_price
);

//    reg [`ADDRESS_INDEX+2:0] mem_control;
//    reg [`TOTAL_BITS-1:0] data_w;
//    reg ready;
//    wire [`SIZE_INDEX-1:0] size_update_o;
//    reg [`CANCEL_UPDATE_INDEX:0] update;

	reg [`SIZE_INDEX:0] index;
	reg [`SIZE_INDEX:0] size_latched;
	
	parameter WAITING = 3'b000;
	parameter FIND = 3'b001;
	parameter DELETE = 3'b010;
	parameter UPDATE = 3'b110;
	//parameter DONE = 3'b011;	//not using
	parameter BEST_PRICE = 3'b011;
	parameter NOT_FOUND = 3'b111;
	
	parameter COPY = 2'b00;
	parameter MOVE = 2'b01;
	
	parameter MEM_IDLE = 0 ;
	parameter MEM_PROGRESS = 1;
	
	reg [2:0] mem_state;
	reg [2:0] state;
	reg [`SIZE_INDEX:0] update_index;
	reg [2:0] delete_state;
	reg [`QUANTITY_INDEX:0] quantity_latched;
	reg delete_latched;
	
	reg [`TOTAL_BITS-1:0] copy_entry;
	
	assign size_update_o = size_latched;
	
	reg check;
	reg [`ORDER_INDEX:0] loc;
	
	//need start signal, entry in order book, addr, delete
	// ila_1 my_ila(.clk(clk_in), .probe0(0), .probe1(data_r), .probe2(mem_valid), .probe3(start), .probe4(mem_control.addr));
	
	always @(posedge clk_in) begin
		if(rst) begin
			mem_control <= 0;
			data_w <= 0;
			ready <= 0;
			update <= 0;
			
			index <= 0;
			size_latched<= 0;
			
			mem_state <= MEM_IDLE;
			state <= WAITING;
			update_index <= 0;
			delete_state <= 0;
			quantity_latched <= 0;
			delete_latched <= 0;
			copy_entry <= 0;
			
			best_price <= 0;
			check <= 0;
			loc <= 0;
		end
		
		else begin
			case (state)
				WAITING: begin
					data_w <= 0;
					update <= WAITING;
					best_price <= in_best_price;
					loc <= 0;
					if(start) begin
						index <= 0;
						state <= FIND;
						mem_state <= MEM_IDLE;
						size_latched <= size;
						quantity_latched <= quantity;
						delete_latched <= delete;
						ready <= 0;
					end
					else begin
						ready <= 0;
					end
				end
				
				UPDATE: begin
					case(mem_state)
						MEM_IDLE: begin
							mem_control[`ADDRESS_INDEX:0] <= id;
							mem_control[`ADDRESS_INDEX+1] <= 1;
							mem_control[`ADDRESS_INDEX+2] <= 1;
							data_w <= {copy_entry[31:24] - quantity_latched, copy_entry[23:0]};
							mem_state <= MEM_PROGRESS;
						end
						MEM_PROGRESS: begin
							mem_control[`ADDRESS_INDEX+2] <= 0;
							if(mem_valid) begin
								mem_state <= MEM_IDLE;
								state <= WAITING;
								update <= UPDATE;
								ready <= 1;
							end
						end
					endcase
				end
				
				//old one
				//FIND: begin
				//	case(mem_state)
				//		MEM_IDLE: begin
				//			if(index < size_latched) begin
				//				mem_control <= {1'b1, 1'b0, index};
				//				mem_state <= MEM_PROGRESS;
				//			end
				//			else begin
				//				state <= WAITING;
				//				update <= NOT_FOUND;
				//				ready <= 1;
				//			end
				//		end
				//		MEM_PROGRESS: begin
				//			mem_control[`ADDRESS_INDEX+2] <= 0;
				//			if(mem_valid) begin
				//				mem_state <= MEM_IDLE;
				//				if(data_r[23:16] == id) begin
				//					update_index <= index;
				//					if(data_r[31:24] <= quantity || delete_latched) begin
				//						state <= DELETE;
				//						delete_state <= COPY;
				//					end
				//					else begin
				//						state <= UPDATE;
				//						copy_entry <= data_r;
				//					end
				//				end
				//				else begin
				//					index <= index + 1;
				//				end
				//			end
				//		end
				//	endcase
				//end
				
				//new one
				FIND: begin
					case(mem_state)
						MEM_IDLE: begin
							mem_control <= {1'b1, 1'b0, id};
							mem_state <= MEM_PROGRESS;
						end
						MEM_PROGRESS: begin
							mem_control[`ADDRESS_INDEX+2] <= 0;
							if(mem_valid) begin
								mem_state <= MEM_IDLE;
								if(data_r[`PRICE_INDEX:0] != 0) begin
									if(data_r[`TOTAL_BITS-1:`TOTAL_BITS-`QUANTITY_INDEX-1] <= quantity || delete_latched) begin
										state <= DELETE;
										delete_state <= COPY;
										if(data_r[`PRICE_INDEX:0] == in_best_price) check <= 1;
									end
									else begin
										state <= UPDATE;
										copy_entry <= data_r;
									end
								end
								else begin
									state <= WAITING;
									update <= NOT_FOUND;
								end
							end
						end
					endcase
				end
				
				BEST_PRICE: begin
					case(mem_state)
						MEM_IDLE: begin
							if(index < size_latched) begin
								mem_control <= {1'b1, 1'b0, loc};
								mem_state <= MEM_PROGRESS;
							end
							else begin
								state <= WAITING;
								update <= BEST_PRICE;
								ready <= 1;
							end
						end
						MEM_PROGRESS: begin
							mem_control[`ADDRESS_INDEX+2] <= 0;
							if(mem_valid) begin
								mem_state <= MEM_IDLE;
								loc <= loc + 1;
								if(data_r[`PRICE_INDEX:0] != 0) begin
									index <= index+1;
									if((data_r[`PRICE_INDEX:0]>best_price) == IS_MAX) begin
										best_price <= data_r[`PRICE_INDEX:0];
									end
								end
							end
						end
					endcase
				end
				
				//old one
				//DELETE: begin
				//	case(delete_state)
				//		COPY: begin
				//			case(mem_state)
				//				MEM_IDLE: begin
				//					if(update_index + 1 < size_latched) begin
				//						mem_control[`ADDRESS_INDEX:0] <= update_index + 1;
				//						mem_control[`ADDRESS_INDEX+1] <= 0;
				//						mem_control[`ADDRESS_INDEX+2] <= 1;
				//						mem_state <= MEM_PROGRESS;
				//					end
				//					else begin
				//						size_latched <= size_latched - 1;
				//						state <= BEST_PRICE;
				//						best_price <= 0;
				//						index <= 0;
				//						update <= DELETE;
				//					end
				//				end
				//				MEM_PROGRESS: begin
				//					mem_control[`ADDRESS_INDEX+2] <= 0;
				//					if(mem_valid) begin
				//						copy_entry <= data_r;
				//						delete_state <= MOVE;
				//						mem_state <= MEM_IDLE;
				//					end
				//				end
				//			endcase
				//		end
				//		MOVE: begin
				//			case(mem_state)
				//				MEM_IDLE: begin
				//					mem_control[`ADDRESS_INDEX:0] <= update_index;
				//					mem_control[`ADDRESS_INDEX+1] <= 1;
				//					mem_control[`ADDRESS_INDEX+2] <= 1;
				//					data_w <= copy_entry;
				//					mem_state <= MEM_PROGRESS;
				//				end
				//				MEM_PROGRESS: begin
				//					mem_control[`ADDRESS_INDEX+2] <= 0;
				//					if(mem_valid) begin
				//						mem_state <= MEM_IDLE;
				//						delete_state <= COPY;
				//						update_index <= update_index + 1;
				//					end
				//				end
				//			endcase
				//		end
				//	endcase
				//end
				
				//new one
				DELETE: begin
					case(mem_state)
						MEM_IDLE: begin
							mem_control[`ADDRESS_INDEX:0] <= id;
							mem_control[`ADDRESS_INDEX+1] <= 1;
							mem_control[`ADDRESS_INDEX+2] <= 1;
							data_w <= 0;
							mem_state <= MEM_PROGRESS;
						end
						MEM_PROGRESS: begin
							mem_control[`ADDRESS_INDEX+2] <= 0;
							if(mem_valid) begin
								mem_state <= MEM_IDLE;
								size_latched <= size_latched - 1;
								if(check) begin
									state <= BEST_PRICE;
									best_price <= 0;
									index <= 0;
								end
								else begin
									state <= WAITING;
									ready <= 1;
								end
							end
						end
					endcase
				end
			endcase
		end
	end
endmodule
