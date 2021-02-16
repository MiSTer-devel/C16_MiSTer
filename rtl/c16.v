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
// 
// Create Date:    12:02:05 10/24/2014 
// Design Name: 	 Commodore 16 
// Module Name:    C16.v
// Project Name: 	 FPGATED
//
// Description: 	
//	This module provides the top level framework for FPGATED. It implements a Commodore 16 computer without expansion port.
// It is written for Papilio FPGATED wing 1.x but can be easily modified for any other platforms.
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module C16
(
	input         CLK28,
	input         RESET,
	input         WAIT,

	output        CE_PIX,
	output        HSYNC,
	output        VSYNC,
	output        CSYNC,
	output        HBLANK,
	output        VBLANK,
	output  [3:0] RED,
	output  [3:0] GREEN,
	output  [3:0] BLUE,
	input   [1:0] tvmode,
	input         wide,

	output        RnW,
	output [15:0] ADDR,
	input   [7:0] DIN,
	output  [7:0] DOUT,
	output        CS_RAM,
	output        CS0,
	output        CS1,
	output        CS_IO,

	output        cass_mtr,
	input         cass_in,
	input         cass_aud,

	input   [4:0] JOY0,
	input   [4:0] JOY1,

	input  [10:0] ps2_key,

	output        IEC_DATAOUT,
	input         IEC_DATAIN,
	output        IEC_CLKOUT,
	input         IEC_CLKIN,
	output        IEC_ATNOUT,
	output        IEC_RESET,

	output [15:0] sound,
	input   [1:0] sid_type,

	output        PAL
);

wire [15:0] c16_addr;
wire [15:0] ted_addr;
wire [15:0] cpu_addr;
wire [7:0] c16_data,ted_data,ram_data,cpu_data,port_in,port_out,keyport_data;
wire [7:0] keyboard_row,kbus,kbus_kbd;
wire [6:0] c16_color;
wire cpuenable;
wire aec,rdy;
wire keyboardio;
reg sreset=1'b0;
reg [23:0] resetcounter=24'b0;
wire irq1;
wire keyreset;

// wire joysticks 
wire [4:0] joy0_sel = (!c16_data[2])?{!JOY0[4],!JOY0[0],!JOY0[1],!JOY0[2],!JOY0[3]}:5'h1f;
wire [4:0] joy1_sel = (!c16_data[1])?{!JOY1[4],!JOY1[0],!JOY1[1],!JOY1[2],!JOY1[3]}:5'h1f;
assign kbus[3:0] = kbus_kbd[3:0] & joy0_sel[3:0] & joy1_sel[3:0];
assign kbus[5:4] = kbus_kbd[5:4]; // no joystick line connected here
assign kbus[6] = kbus_kbd[6] & joy0_sel[4];
assign kbus[7] = kbus_kbd[7] & joy1_sel[4];

wire irq_n;

// 8501 CPU
mos8501 cpu
(
	.clk(CLK28), 
	.reset(sreset), 
	.enable(cpuenable && !WAIT),  
	.irq_n(irq_n), 
	.data_in(c16_data), 
	.data_out(cpu_data), 
	.address(cpu_addr),
	.rw(RnW),								// rw=high read, rw=low write
	.port_in(port_in),
	.port_out(port_out),
	.rdy(rdy),
	.aec(aec)
);

// -----------------------------------------------------------------------
// internal SID Card enhancement
// -----------------------------------------------------------------------

// this process divides 28 MHz to ~986KHz (for the SID)
reg ce_sid;
always @(posedge CLK28)	begin
	reg [5:0] div = 0;
	
	div <= div  + 1'd1;
	if(div == 28) div <= 0;
	ce_sid <= !div;
end

// valid adresses for SID: FD40-FD5F and FE80-FE9F
wire cs_sid = (c16_addr[15:5] == 'b1111_1101_010) || (c16_addr[15:5] == 'b1111_1110_100);

wire  [7:0] sid8580_data;
wire [17:0] sid8580_audio;
sid8580 sid8580
(
	.reset(sreset),
	.clk(CLK28),
	.ce_1m(ce_sid),

	.we(~RnW & cs_sid),
	.addr(c16_addr[4:0]),
	.data_in(c16_data),
	.data_out(sid8580_data),

	.extfilter_en(1),
	.audio_data(sid8580_audio)
);

wire  [7:0] sid6581_data;
wire [17:0] sid6581_audio;
sid_top #(592) sid6581
(
	 .reset(sreset),
	 .clock(CLK28),
	 .start_iter(ce_sid),

	 .wren(~RnW & cs_sid),
	 .addr(c16_addr[4:0]),
	 .wdata(c16_data),
	 .rdata(sid6581_data),

	 .extfilter_en(1),
	 .sample_left(sid6581_audio)
);

wire [16:0] sid_audio = sid_type[0] ? {sid6581_audio[17], sid6581_audio[17:2]} : sid_type[1] ? {sid8580_audio[17], sid8580_audio[17:2]} : 17'd0;
wire  [7:0] sid_data  = (sid_type[0] & RnW & cs_sid) ? sid6581_data : (sid_type[1] & RnW & cs_sid) ? sid8580_data : 8'hFF;

// -----------------------------------------------------------------------

wire [16:0] mix_audio = sid_audio + {ted_audio,ted_audio,ted_audio} + {cass_aud, 10'd0};
assign sound = ($signed(mix_audio) > $signed(17'd32767)) ? 16'd32767 : ($signed(mix_audio) < $signed(-17'd32768)) ? $signed(-16'd32768) : mix_audio[15:0];

// -----------------------------------------------------------------------

wire [4:0] ted_audio;
// TED 8360 instance	
ted mos8360
(
	.clk(CLK28),
	.reset(sreset),
	.addr_in(c16_addr),
	.addr_out(ted_addr),
	.data_in(c16_data),
	.data_out(ted_data),
	.rw(RnW),
	.color(c16_color),
	.csync(CSYNC),
	.hsync(HSYNC),
	.vsync(VSYNC),
	.wide(wide),
	.hblank(HBLANK),
	.vblank_out(VBLANK),
	.ce_pix(CE_PIX),
	.irq(irq_n),
	.ba(rdy),
	.cs_ram(CS_RAM),
	.cs0(CS0),
	.cs1(CS1),
	.cs_io(CS_IO),
	.aec(aec),
	.k(kbus),
	.snd(ted_audio),
	.pal(PAL),
	.tvmode(tvmode),
	.cpuenable(cpuenable)
);

// Color decoder to 12bit RGB	
colors_to_rgb colordecode
(
	.clk(CLK28),
	.color(c16_color),
	.red(RED),
	.green(GREEN),
	.blue(BLUE)
);

// keyboard part
c16_keymatrix keyboard
(
	.clk(CLK28),
	.ps2_key(ps2_key),
	.row(keyboard_row),
	.kbus(kbus_kbd)
);

mos6529 keyport
(
	.clk(CLK28),
	.data_in(c16_data),
	.data_out(keyport_data),
	.port_in(keyboard_row),	// keyport 6529 in C16 is unidirectional however if we read it the last written data is read back so we feed back its output.
	.port_out(keyboard_row),
	.rw(RnW),
	.cs(keyboardio)
);

assign keyboardio=(c16_addr[15:4]==12'hfd3);		// as we don't have PLA, keyport is identified here

// C16 additional motherboard functions
always @(posedge CLK28)	begin	// reset tries to emulate the length of a real reset
	if(RESET) begin		// reset can be triggered by reset button or CTRL+ALT+DEL from keyboard
		resetcounter<=0;
		sreset<=1;
	end else begin
		if(resetcounter==24'd1000000) sreset<=0;
		else begin
			resetcounter<=resetcounter+1'd1;
			sreset<=1;
		end
	end
end

// assign VSYNC=1'b1; // set scart mode to RGB for TV
assign c16_addr=cpu_addr&ted_addr;									 // C16 address bus
assign c16_data=cpu_data&ted_data&DIN&keyport_data&sid_data; // C16 data bus

assign ADDR=c16_addr;
assign DOUT=cpu_data;

reg iec_data;
reg iec_clk;
always @(posedge CLK28) begin
	reg iec_data_d1,iec_data_d2; 
	reg iec_clk_d1,iec_clk_d2;

	iec_data_d1<=IEC_DATAIN;
	iec_data_d2<=iec_data_d1;
	iec_data   <=iec_data_d2; 

	iec_clk_d1 <=IEC_CLKIN;
	iec_clk_d2 <=iec_clk_d1;
	iec_clk    <=iec_clk_d2;
end

// connect IEC bus
assign {port_in[5],port_in[3:0]}=0;
assign IEC_DATAOUT=~port_out[0];
assign port_in[7]=iec_data & ~port_out[0];
assign IEC_CLKOUT=~port_out[1];
assign port_in[6]=iec_clk & ~port_out[1];
assign IEC_ATNOUT=~port_out[2];
assign IEC_RESET=sreset;

assign cass_mtr = port_out[3];
assign port_in[4]= cass_in;

endmodule
