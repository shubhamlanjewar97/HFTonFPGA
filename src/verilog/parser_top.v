`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.04.2025 17:31:15
// Design Name: 
// Module Name: parser_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`include "../../../new/constants.v"

module parser_top
   (
    input                  clk_in,
    input                  reset_in, 
    input [`PARSER_DATA_WIDTH:0]   data_in,
	input                  in_ready, // from uart module telling if data_in is ready
	
	output reg [`STOCK_INDEX:0] stock_identifier,	//(2 bits) which stock to add (STOCK_A/ STOCK_B / STOCK_C/ STOCK_D)
	output reg [`TOTAL_BITS-1:0] order_to_add, // (32 bits) structure > | quantity(8 bits) | orderid (8 bits) | price (16 bits) |
	output reg [`QUANTITY_INDEX:0] quantity,	// (8 bits) | quantity to decrease order by , when request is EXECUTE_ORDER
	output reg [2:0] request,		// (3 bits) (ADD_ORDER, CANCEL_ORDER, EXECUTE_ORDER)
	output reg [`ORDER_INDEX:0] order_id, // (8 bits) | should be supplied for a CANCEL_ORDER / EXECUTE_ORDER
	output reg                 order_type_out_add, 
	output reg             out_ready,
	
	// Debugging outputs
    output reg [7:0]           message_monitor,
    output reg [2:0]           current_state_monitor,
    output reg [10:0]          count_monitor
    );                
    
    
    
    // State definitions - use one-hot encoding for better timing
//    localparam [3:0] PARSER_STATE_INIT   = 3'd0;
//    localparam [3:0] PARSER_STATE_POST_INIT  = 3'd1;
//    localparam [3:0] PARSER_STATE_DECIDE_MSG_TYPE   = 3'd2;
//    localparam [3:0] PARSER_STATE_PARSE_ADD_ORDER   = 3'd3;
//    localparam [3:0] PARSER_STATE_PARSE_CANCEL_EXCE_OREDER   = 3'd4;
//    localparam [3:0] PARSER_STATE_PARSE_IGNORED_MSG  = 3'd5;
//    localparam [3:0] PARSER_STATE_COMPLETE   = 3'd6;
    
    localparam [3:0] PARSER_STATE_INIT   = 3'd0;
    localparam [3:0] PARSER_STATE_POST_INIT  = 3'd1;
    localparam [3:0] PARSER_STATE_DECIDE_MSG_TYPE   = 3'd2;
    localparam [3:0] PARSER_STATE_PARSE_ADD_ORDER   = 3'd3;
    localparam [3:0] PARSER_STATE_PARSE_CANCEL_EXCE_OREDER   = 3'd4;
    localparam [3:0] PARSER_STATE_PARSE_IGNORED_MSG  = 3'd5;
    localparam [3:0] PARSER_STATE_COMPLETE   = 3'd6;    
    
          
    reg [2:0] current_state;
    
    // Signals and registers
    reg [7:0]                     message;
    reg                           data_valid;
    reg [`PARSER_DATA_WIDTH:0]    data_message_size;
    reg [`PARSER_MAX_MESSAGE_SIZE*8-1:0] parsed_data;
    reg [10:0]                    count;
    reg [2:0]                     mess_type;
    
    reg reset_message;
    
    // Improved input data handling with reduced latency
    reg in_ready_prev;
    wire input_data_valid;
    
    // Track rising edge of in_ready for data capture
    always @(posedge clk_in) begin
        if (reset_in) begin
            in_ready_prev <= 1'b0;
        end else begin
            in_ready_prev <= in_ready;
        end
    end
    
    // Detect valid input data on rising edge of in_ready
    assign input_data_valid = in_ready && !in_ready_prev;
    
    // Process input data directly
    always @(posedge clk_in) begin
        if (reset_in) begin
            message <= 8'h00;
            data_valid <= 1'b0;
        end else begin
            if (reset_message)begin // current_state == `PARSER_STATE_COMPLETE) begin
                // Reset message when processing is complete
                message <= 8'h00;
                data_valid <= 1'b0;
            end else if (input_data_valid) begin
                // Capture new data directly
                message <= data_in;
                data_valid <= 1'b1;//(data_in != 8'h00); // Mark as valid if not a null byte
            end
        end
    end
    
    // Monitor outputs for debugging
    always@(*) begin
        message_monitor <= message;
        current_state_monitor <= current_state;
        count_monitor <= count;
    end
    
    // State machine and parsing logic
    always @(posedge clk_in) begin
        if (reset_in) begin
            current_state <= `PARSER_STATE_INIT;
            count <= 0;
            mess_type <= 0;
            out_ready <= 0;
            
            // Reset outputs
            request <= 0;
            stock_identifier <= 0;
            order_id <= 0;
            quantity <= 0;
            order_type_out_add <= 0;
            
            parsed_data <= 0;
            data_message_size <= 0;
            
            order_to_add <= 0;
        end
        else begin
            case (current_state)
                PARSER_STATE_INIT: begin
                    reset_message <= 1'b0;
                    out_ready <= 0;
                    count <= 0;
                    order_type_out_add <= 0;
                    
                    if (data_valid) begin
                        // Skip 0x00 messages
                        if (message == 8'h00) begin
                            current_state <= PARSER_STATE_INIT;
                        end
                        else begin
                            // Get the length of the message
                            data_message_size <= message;
                            current_state <= PARSER_STATE_POST_INIT;
                        end
                    end
                end
                
                PARSER_STATE_POST_INIT: begin
                    out_ready <= 0;
                     if (input_data_valid) begin
                        current_state <= PARSER_STATE_DECIDE_MSG_TYPE;
                     end
                     else begin
                        current_state <= PARSER_STATE_POST_INIT;
                     end
                end
                
                PARSER_STATE_DECIDE_MSG_TYPE: begin
                    out_ready <= 0;
                    if (input_data_valid) begin
                        // Determine message type and transition to appropriate parse state
                        case (message)
                            8'h82, 8'h86: begin
                                current_state <= PARSER_STATE_PARSE_ADD_ORDER;
                                mess_type <= (message == 8'h82) ? 0 : 1;
                            end
                            
                            8'h2A, 8'hC2, 8'hA1, 8'h22, 8'hAA: begin
                                current_state <= PARSER_STATE_PARSE_CANCEL_EXCE_OREDER;
                                
                                // Set message type based on opcode
                                if (message == 8'h2A) mess_type <= 0;      // exec
                                else if (message == 8'hC2) mess_type <= 1; // exec_`PARSER_PRICE
                                else if (message == 8'hA1) mess_type <= 2; // cancel
                                else if (message == 8'h22) mess_type <= 3; // delete
                                else mess_type <= 4;                       // replace
                            end
                            
                            default: begin
                                current_state <= PARSER_STATE_PARSE_IGNORED_MSG;
                            end
                        endcase
                    end
                end
                
                PARSER_STATE_PARSE_ADD_ORDER: begin
                    if ((input_data_valid && !out_ready) || count == 11'd34) begin
                        count <= count + 1;
                        // Shift register to accumulate data
                        if(count == 11'd33)begin
                            parsed_data <= parsed_data;
                        end
                        else begin
                            parsed_data <= {message, parsed_data[`PARSER_MAX_MESSAGE_SIZE*8-1:8]};
                        end
                        
                        // `PARSER_STATE_COMPLETE parsing when we have all the needed fields
                        if (count == `PARSER_MESSAGE_TYPE + `PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + 
                            `PARSER_ORDER_REF_NUM + `PARSER_BUY_SELL_IND + `PARSER_SHARES + `PARSER_STOCK + `PARSER_PRICE - 1) begin
                            
                            // Set outputs for ADD message
                            request <= `ADD_ORDER; // ADD_ORDER, CANCEL_ORDER, EXECUTE_ORDER
                            
                            order_id <= parsed_data[8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_OFFSET_FOR_ADD_ORDER + 1)-1:8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_OFFSET_FOR_ADD_ORDER)];										  
                            
                            order_type_out_add <= (parsed_data[8*( `PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_ORDER_REF_NUM + `PARSER_OFFSET_FOR_ADD_ORDER + 1) -1:8*( `PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_ORDER_REF_NUM + `PARSER_OFFSET_FOR_ADD_ORDER)] == 8'h41) ? 1'b1 : 1'b0; // 1 for buy
                            
                            // Extract other fields from parsed_data
                            stock_identifier <= parsed_data[8*(`PARSER_OFFSET_FOR_ADD_ORDER) + 1:8*`PARSER_OFFSET_FOR_ADD_ORDER];
                            
                            quantity <= parsed_data[8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_ORDER_REF_NUM+`PARSER_BUY_SELL_IND + `PARSER_OFFSET_FOR_ADD_ORDER + 1 )-1:8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_ORDER_REF_NUM+`PARSER_BUY_SELL_IND + `PARSER_OFFSET_FOR_ADD_ORDER )];
                            
                            order_to_add <= { //| quantity(8 bits) | orderid (8 bits) | `PARSER_PRICE (16 bits) |
                                             parsed_data[8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_ORDER_REF_NUM+`PARSER_BUY_SELL_IND + `PARSER_OFFSET_FOR_ADD_ORDER + 1 )-1:8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_ORDER_REF_NUM+`PARSER_BUY_SELL_IND + `PARSER_OFFSET_FOR_ADD_ORDER )],
                                             parsed_data[8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_OFFSET_FOR_ADD_ORDER + 1)-1:8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_OFFSET_FOR_ADD_ORDER)],
                                             parsed_data[8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_ORDER_REF_NUM+`PARSER_BUY_SELL_IND + `PARSER_SHARES + `PARSER_STOCK + `PARSER_OFFSET_FOR_ADD_ORDER + 2 )-1:
                                             8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_ORDER_REF_NUM + `PARSER_BUY_SELL_IND + `PARSER_SHARES + `PARSER_STOCK + `PARSER_OFFSET_FOR_ADD_ORDER)]
                                             };
                            
                            out_ready <= 1;
                            current_state <= PARSER_STATE_COMPLETE;
                            reset_message = 1'b1;
                        end
                        else begin
                            out_ready <= 0;
                        end  
                    end
                end
                
                PARSER_STATE_PARSE_CANCEL_EXCE_OREDER: begin
                    if ((input_data_valid && !out_ready) || count == 11'd21) begin
                        count <= count + 1;
                        // Shift register to accumulate data
                        //parsed_data <= {message, parsed_data[`PARSER_MAX_MESSAGE_SIZE*8-1:8]};
                        if(count == 11'd20)begin
                            parsed_data <= parsed_data;
                        end
                        else begin
                            parsed_data <= {message, parsed_data[`PARSER_MAX_MESSAGE_SIZE*8-1:8]};
                        end                       
                        
                        
                        // Different message types have different field layouts
                        if (mess_type == 2) begin  // Cancel order message
                            if (count == `PARSER_MESSAGE_TYPE + `PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + 
                                `PARSER_ORDER_REF_NUM + `PARSER_SHARES - 1) begin
                                
                                // Set outputs for CANCEL message
                                request <= `CANCEL_ORDER; // ADD_ORDER, CANCEL_ORDER, EXECUTE_ORDER
                                
                                // Extract fields from parsed_data
                                order_id <= parsed_data[8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_ORDER_REF_NUM + `PARSER_OFFSET_FOR_CANCEL_ORDER)-1:8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_OFFSET_FOR_CANCEL_ORDER)];
                                stock_identifier <= parsed_data[8*(`PARSER_STOCK_LOCATE + `PARSER_OFFSET_FOR_CANCEL_ORDER)-1:8*`PARSER_OFFSET_FOR_CANCEL_ORDER];
                                quantity <= parsed_data[8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_ORDER_REF_NUM + 1 + `PARSER_OFFSET_FOR_CANCEL_ORDER)-1:8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_ORDER_REF_NUM + `PARSER_OFFSET_FOR_CANCEL_ORDER)];
                                
                                order_to_add <= { //| quantity(8 bits) | orderid (8 bits) | `PARSER_PRICE (16 bits) zero since not received in CANCEL_ORDER |
                                                 parsed_data[8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_ORDER_REF_NUM + 1 + `PARSER_OFFSET_FOR_CANCEL_ORDER)-1:8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_ORDER_REF_NUM + `PARSER_OFFSET_FOR_CANCEL_ORDER)],
                                                 parsed_data[8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + 1 + `PARSER_OFFSET_FOR_CANCEL_ORDER)-1:8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_OFFSET_FOR_CANCEL_ORDER)],
                                                 16'b0 };
                                
                                out_ready <= 1;
                                current_state <= PARSER_STATE_COMPLETE;
                                reset_message = 1'b1;
                            end
                            else begin
                                out_ready <= 0;
                            end
                        end
                        else if (mess_type == 0) begin  // Execute order message
                            if (count == `PARSER_MESSAGE_TYPE + `PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + 
                                `PARSER_ORDER_REF_NUM + `PARSER_SHARES - 1) begin
                                
                                // Set outputs for EXECUTE message
                                request <= `EXECUTE_ORDER;
                                
                                // Extract fields from parsed_data
                                order_id <= parsed_data[8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_ORDER_REF_NUM + `PARSER_OFFSET_FOR_EXCECUTE_ORDER)-1:8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_OFFSET_FOR_EXCECUTE_ORDER)];
                                stock_identifier <= parsed_data[8*(`PARSER_STOCK_LOCATE + `PARSER_OFFSET_FOR_EXCECUTE_ORDER)-1:8*`PARSER_OFFSET_FOR_EXCECUTE_ORDER];
                                quantity <= parsed_data[8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_ORDER_REF_NUM + 1  + `PARSER_OFFSET_FOR_EXCECUTE_ORDER)-1:8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_ORDER_REF_NUM + `PARSER_OFFSET_FOR_EXCECUTE_ORDER)];
                                
                                order_to_add <= { //| quantity(8 bits) | orderid (8 bits) | `PARSER_PRICE (16 bits) zero since not received in CANCEL_ORDER |
                                                 parsed_data[8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_ORDER_REF_NUM + 1 + `PARSER_OFFSET_FOR_EXCECUTE_ORDER)-1:8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_ORDER_REF_NUM + `PARSER_OFFSET_FOR_EXCECUTE_ORDER)],
                                                 parsed_data[8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + 1 + `PARSER_OFFSET_FOR_EXCECUTE_ORDER)-1:8*(`PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + `PARSER_OFFSET_FOR_EXCECUTE_ORDER)],
                                                 16'b0 };
                                
                                out_ready <= 1;
                                current_state <= PARSER_STATE_COMPLETE;
                                reset_message = 1'b1;
                            end
                            else begin
                                out_ready <= 0;
                            end                            
                        end
                        else if (mess_type == 3) begin  // Delete message // We dont supoport yet
                            if (count == `PARSER_MESSAGE_TYPE + `PARSER_STOCK_LOCATE + `PARSER_TRACKING_NUMBER + `PARSER_TIMESTAMP + 
                                `PARSER_ORDER_REF_NUM - 2) begin
                                
                                // Set outputs for DELETE message
                                request <= 3'b000;
                                
                                // Extract fields from parsed_data
                                order_id <= parsed_data[8*`PARSER_ORDER_REF_NUM-1:0];
                                stock_identifier <= parsed_data[8*`PARSER_STOCK_LOCATE-1:0];
                                
                                out_ready <= 1;
                                current_state <= PARSER_STATE_COMPLETE;
                            end
                            else begin
                                out_ready <= 0;
                            end                            
                        end
                        else begin  // Other cancel-related message types // NEVER tested yet
                            if (count >= 32) begin  // Arbitrary large value to handle other types
                                request <= {1'b0, ~mess_type[0], 1'b0};
                                
                                // Set some default values for other cancel types
                                quantity <= 980;
                                order_id <= 2894;
                                stock_identifier <= 2983;
                                
                                out_ready <= 1;
                                current_state <= `PARSER_STATE_COMPLETE;
                            end
                            else begin
                                out_ready <= 0;
                            end
                        end
                    end
                    else begin
                        out_ready <= 0;
                    end                    
                end
                
                PARSER_STATE_PARSE_IGNORED_MSG: begin
                    // Simple counter-based dummy message handling
                    if (data_message_size <= 3) begin
                        current_state <= PARSER_STATE_COMPLETE;
                    end
                    else if (input_data_valid) begin
                        data_message_size <= data_message_size - 1;
                    end
                    
                    out_ready <= 0;
                end
                
                PARSER_STATE_COMPLETE: begin
                    out_ready <= 1;
                    //reset_message = 1'b1;
                    current_state <= PARSER_STATE_INIT;
                end
                
                default: begin
                    current_state <= PARSER_STATE_INIT;
                    out_ready <= 0;
                end
            endcase
        end
    end
endmodule