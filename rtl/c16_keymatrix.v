`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//  Copyright 2013-2016 Istvan Hegedus
//
//  FPGATED is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  FPGATED is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//
// Create Date:    19:38:44 12/16/2015 
// Module Name:    c16_keymatrix.v
// Project Name: 	 FPGATED
//
// Description: 	C16/Plus4 keyboard matrix emulation for PS2 keyboards.
//
// Revisions:
// 1.0	first release
//
//////////////////////////////////////////////////////////////////////////////////
module c16_keymatrix
(
	input         clk,
	input  [10:0] ps2_key,
	input   [7:0] row,
	output reg    key_play = 0,
	output  [7:0] kbus
);

reg [7:0] colsel=0;
reg key_A=0,key_B=0,key_C=0,key_D=0,key_E=0,key_F=0,key_G=0,key_H=0,key_I=0,key_J=0,key_K=0,key_L=0,key_M=0,key_N=0,key_O=0,key_P=0,key_Q=0,key_R=0,key_S=0,key_T=0,key_U=0,key_V=0,key_W=0,key_X=0,key_Y=0,key_Z=0;
reg key_1=0,key_2=0,key_3=0,key_4=0,key_5=0,key_6=0,key_7=0,key_8=0,key_9=0,key_0=0,key_del=0,key_return=0,key_help=0,key_F1=0,key_F2=0,key_F3=0,key_AT=0,key_shift=0,key_comma=0,key_dot=0;
reg key_minus=0,key_colon=0,key_star=0,key_semicolon=0,key_esc=0,key_equal=0,key_plus=0,key_slash=0,key_control=0,key_space=0,key_runstop=0;
reg key_pound=0,key_down=0,key_up=0,key_left=0,key_right=0,key_home=0,key_commodore=0;
wire [7:0] rowsel;

assign rowsel=~row;

wire       pressed  = ps2_key[9];
wire [8:0] scancode = ps2_key[8:0];

always @(posedge clk) begin
	reg flg1,flg2;

	flg1 <= ps2_key[10];
	flg2 <= flg1;
	
	if(flg2 != flg1) begin
		case(scancode)

			// base code keys
			9'h01C: key_A<=pressed;
			9'h032: key_B<=pressed;
			9'h021: key_C<=pressed;
			9'h023: key_D<=pressed;
			9'h024: key_E<=pressed;
			9'h02B: key_F<=pressed;
			9'h034: key_G<=pressed;
			9'h033: key_H<=pressed;
			9'h043: key_I<=pressed;
			9'h03B: key_J<=pressed;
			9'h042: key_K<=pressed;
			9'h04B: key_L<=pressed;
			9'h03A: key_M<=pressed;
			9'h031: key_N<=pressed;
			9'h044: key_O<=pressed;
			9'h04D: key_P<=pressed;
			9'h015: key_Q<=pressed;
			9'h02D: key_R<=pressed;
			9'h01B: key_S<=pressed;
			9'h02C: key_T<=pressed;
			9'h03C: key_U<=pressed;
			9'h02A: key_V<=pressed;
			9'h01D: key_W<=pressed;
			9'h022: key_X<=pressed;
			9'h035: key_Y<=pressed;
			9'h01A: key_Z<=pressed;
			9'h069, 
			9'h016: key_1<=pressed;
			9'h072, 
			9'h01E: key_2<=pressed;
			9'h07A, 
			9'h026: key_3<=pressed;
			9'h06B, 
			9'h025: key_4<=pressed;
			9'h073, 
			9'h02E: key_5<=pressed;
			9'h074, 
			9'h036: key_6<=pressed;
			9'h06C, 
			9'h03D: key_7<=pressed;
			9'h075, 
			9'h03E: key_8<=pressed;
			9'h07D, 
			9'h046: key_9<=pressed;
			9'h070, 
			9'h045: key_0<=pressed;
			9'h066: key_del<=pressed;
			9'h05A: key_return<=pressed;
			9'h00C: key_help<=pressed;
			9'h005: key_F1<=pressed;
			9'h006: key_F2<=pressed;
			9'h004: key_F3<=pressed;
			9'h054: key_AT<=pressed;
			9'h012, 
			9'h059: key_shift<=pressed;
			9'h041: key_comma<=pressed;
			9'h049: key_dot<=pressed;
			9'h07B, 
			9'h04E: key_minus<=pressed;
			9'h04C: key_colon<=pressed;
			9'h07C, 
			9'h05B: key_star<=pressed;
			9'h052: key_semicolon<=pressed;
			9'h076: key_esc<=pressed;
			9'h05D: key_equal<=pressed;
			9'h079, 
			9'h055: key_plus<=pressed;
			9'h04A: key_slash<=pressed;
			9'h014: key_control<=pressed;
			9'h029: key_space<=pressed;
			9'h00D: key_runstop<=pressed;
			9'h011: key_commodore<=pressed;

			// extended code keys
			9'h12F: key_pound<=pressed;
			9'h172: key_down<=pressed;
			9'h175: key_up<=pressed;
			9'h16B: key_left<=pressed;
			9'h174: key_right<=pressed;
			9'h16C: key_home<=pressed;
			9'h114: key_control<=pressed;
			9'h111: key_commodore<=pressed;
			9'h14A: key_slash<=pressed;
			9'h15A: key_return<=pressed;
			9'h171: key_del<=pressed;
			9'h17D: key_play<=pressed;
		endcase
	end
end

always @(posedge clk) begin
	colsel[0]<=(key_del & rowsel[0]) | (key_3 & rowsel[1]) | (key_5 & rowsel[2]) | (key_7 & rowsel[3]) | (key_9 & rowsel[4]) | (key_down & rowsel[5]) | (key_left & rowsel[6]) | (key_1 & rowsel[7]);
	colsel[1]<=(key_return & rowsel[0]) | (key_W & rowsel[1]) | (key_R & rowsel[2]) | (key_Y & rowsel[3]) | (key_I & rowsel[4]) | (key_P & rowsel[5]) | (key_star & rowsel[6]) | (key_home & rowsel[7]);
	colsel[2]<=(key_pound & rowsel[0]) | (key_A & rowsel[1]) | (key_D & rowsel[2]) | (key_G & rowsel[3]) | (key_J & rowsel[4]) | (key_L & rowsel[5]) | (key_semicolon & rowsel[6]) | (key_control & rowsel[7]);
	colsel[3]<=(key_help & rowsel[0]) | (key_4 & rowsel[1]) | (key_6 & rowsel[2]) | (key_8 & rowsel[3]) | (key_0 & rowsel[4]) | (key_up & rowsel[5]) | (key_right & rowsel[6]) | (key_2 & rowsel[7]);
	colsel[4]<=(key_F1 & rowsel[0]) | (key_Z & rowsel[1]) | (key_C & rowsel[2]) | (key_B & rowsel[3]) | (key_M & rowsel[4]) | (key_dot & rowsel[5]) | (key_esc & rowsel[6]) | (key_space & rowsel[7]);
	colsel[5]<=(key_F2 & rowsel[0]) | (key_S & rowsel[1]) | (key_F & rowsel[2]) | (key_H & rowsel[3]) | (key_K & rowsel[4]) | (key_colon & rowsel[5]) | (key_equal & rowsel[6]) | (key_commodore & rowsel[7]);
	colsel[6]<=(key_F3 & rowsel[0]) | (key_E & rowsel[1]) | (key_T & rowsel[2]) | (key_U & rowsel[3]) | (key_O & rowsel[4]) | (key_minus & rowsel[5]) | (key_plus & rowsel[6]) | (key_Q & rowsel[7]);
	colsel[7]<=(key_AT & rowsel[0]) | (key_shift & rowsel[1]) | (key_X & rowsel[2]) | (key_V & rowsel[3]) | (key_N & rowsel[4]) | (key_comma & rowsel[5]) | (key_slash & rowsel[6]) | (key_runstop & rowsel[7]);
end

assign kbus=~colsel;

endmodule
