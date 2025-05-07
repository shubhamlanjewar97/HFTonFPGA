`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/06/2019 05:25:11 PM
// Design Name: 
// Module Name: constants
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
//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////
`ifndef CONSTANTS
`define CONSTANTS

// Define constants as `define macros instead of parameters
`define N 4 // number of rows/cols
`define LOGN 2
`define R 2 // number of rotators
`define NUM_STOCKS 4
`define NUM_STOCK_INDEX (`NUM_STOCKS - 1)
`define STOCK_INDEX 1
`define MAX_INDEX 255

`define PRICE_INDEX 15
`define ORDER_INDEX 7
`define QUANTITY_INDEX 7
`define TOTAL_BITS (`PRICE_INDEX + 1 + `ORDER_INDEX + 1 + `QUANTITY_INDEX + 1)
`define ADDRESS_INDEX 7
`define ENTRY_INDEX (`TOTAL_BITS - 1)
`define BRAM_LATENCY 2
`define SIZE_INDEX 7
`define CANCEL_UPDATE_INDEX 2
`define MAX 1
`define BUY_SIDE 1 //interested in max price
`define SELL_SIDE 0 // interested in min price
`define ADD_ORDER 3'b001
`define CANCEL_ORDER 3'b000
`define EXECUTE_ORDER 3'b010

`define STOCK_A 2'b00
`define STOCK_B 2'b01
`define STOCK_C 2'b10
`define STOCK_D 2'b11


//for parser use
`define PARSER_DATA_WIDTH 7
`define PARSER_STATE_INIT 3'd0
`define PARSER_STATE_DECIDE_MSG_TYPE  3'd1
`define PARSER_STATE_PARSE_ADD_ORDER  3'd2
`define PARSER_STATE_PARSE_CANCEL_EXCE_OREDER 3'd3
`define PARSER_STATE_PARSE_IGNORED_MSG  3'd4
`define PARSER_STATE_COMPLETE  3'd5


// Common parameters for all message types
`define PARSER_MESSAGE_TYPE  0 
`define PARSER_STOCK_LOCATE  2
`define PARSER_TRACKING_NUMBER  2
`define PARSER_TIMESTAMP  6
`define PARSER_ORDER_REF_NUM  8
`define PARSER_BUY_SELL_IND  1
`define PARSER_SHARES  4
`define PARSER_STOCK  8
`define PARSER_PRICE  4
`define PARSER_ATTRIBUTION  4
`define PARSER_MATCH_NUMBER  8
`define PARSER_PRINTABLE  8
    
`define PARSER_MAX_MESSAGE_SIZE  48
    
`define PARSER_OFFSET_FOR_ADD_ORDER  15
`define PARSER_OFFSET_FOR_CANCEL_ORDER  28
`define PARSER_OFFSET_FOR_EXCECUTE_ORDER  28


`endif