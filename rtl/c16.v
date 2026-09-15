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
	output        MUX,
	output        RAS,
	output        CAS,
	output        CS0,
	output        CS1,

	output        cass_mtr,
	input         cass_in,
	input         cass_aud,
	output        cass_out,

	input   [4:0] JOY0,
	input   [4:0] JOY1,

	input  [10:0] ps2_key,
	output        key_play,

	output        IEC_DATAOUT,
	input         IEC_DATAIN,
	output        IEC_CLKOUT,
	input         IEC_CLKIN,
	output        IEC_ATNOUT,
	output        IEC_RESET,

	output [15:0] audio_l,
	output [15:0] audio_r,
	input         sid_enabled,
	input   [1:0] sid_ver,
	input   [3:0] sid_cfg,
	input   [1:0] sid_filter,
	input  [12:0] sid_fc_off_l,
	input  [12:0] sid_fc_off_r,
	input         sid_digifix,
	input         sid_mode,
	input         sid_c64,

	input  [11:0] sid_ld_addr,
	input  [15:0] sid_ld_data,
	input         sid_ld_wr,

	output        PAL
);

wire [15:0] c16_addr;
wire [15:0] ted_addr;
wire [15:0] cpu_addr;
wire [7:0] c16_data,ted_data,cpu_data,port_in,port_out,keyport_data;
wire [7:0] keyboard_row,kbus,kbus_kbd;
wire [6:0] c16_color;
wire cpuenable;
wire mux,ras,cas,aec,rdy;
reg [7:0] c16_datalatch;
reg [15:0] c16_addrlatch;
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
	.gate_in(mux),
	.port_in(port_in),
	.port_out(port_out),
	.rdy(rdy),
	.aec(aec)
);

// -----------------------------------------------------------------------
// internal SID Card enhancement
// -----------------------------------------------------------------------

wire        ce_sid;
wire  [1:0] sid_cs;
wire        sid_we;
wire  [7:0] sid_data;
wire  [7:0] sid_dout;
wire  [7:0] digi_l, digi_r;
wire  [3:0] sid_card_cfg;

sid_card sid_card
(
	.clk(CLK28),
	.reset(sreset),

	.enabled(sid_enabled),
	.c64(sid_c64),
	.split(sid_mode),
	.pal(PAL),
	.sid_ver(sid_ver[0]),

	.mux(mux),
	.addr(c16_addr),
	.rnw(RnW),
	.data_in(cpu_data),
	.sid_dout(sid_dout),

	.sid_cs(sid_cs),
	.sid_we(sid_we),
	.data_out(sid_data),

	.ce_sid(ce_sid),
	.digi_l(digi_l),
	.digi_r(digi_r),
	.cfg(sid_card_cfg)
);

wire [17:0] sid_audio_l;
wire [17:0] sid_audio_r;

sid_top sid
(
	.reset(sreset),
	.clk(CLK28),
	.ce_1m(ce_sid),
	
	.cs(sid_cs),
	.we(sid_we),
	.addr(c16_addr[4:0]),
	.data_in(cpu_data),
	.data_out(sid_dout),

	.audio_l(sid_audio_l),
	.audio_r(sid_audio_r),

	.ext_in_l({sid_ver[0] & sid_digifix, 17'd0}),
	.ext_in_r({sid_ver[1] & sid_digifix, 17'd0}),

	.filter_en(sid_filter),
	.mode(sid_ver),
	.cfg(sid_cfg),

	.fc_offset_l(sid_fc_off_l),
	.fc_offset_r(sid_fc_off_r),

	.ld_clk(CLK28),
	.ld_data(sid_ld_data),
	.ld_addr(sid_ld_addr),
	.ld_wr(sid_ld_wr)
);

// -----------------------------------------------------------------------

reg [15:0] alo, aro;
always @(posedge CLK28) begin
	reg [17:0] alm, arm;

	alm <= {{2{ted_digi[15]}}, ted_digi}
	     + (sid_enabled ? {{2{sid_audio_l[17]}}, sid_audio_l[17:2]} : 18'd0)
	     + {3'b000, digi_l, 7'd0}
	     + {cass_aud, 10'd0};

	arm <= {{2{ted_digi[15]}}, ted_digi}
	     + (sid_enabled ? {{2{sid_audio_r[17]}}, sid_audio_r[17:2]} : 18'd0)
	     + {3'b000, digi_r, 7'd0}
	     + {cass_aud, 10'd0};

	alo <= (&alm[17:15] | ~|alm[17:15]) ? alm[15:0] : {alm[17], {15{~alm[17]}}};
	aro <= (&arm[17:15] | ~|arm[17:15]) ? arm[15:0] : {arm[17], {15{~arm[17]}}};
end

assign audio_l = alo;
assign audio_r = aro;

// -----------------------------------------------------------------------

wire signed [15:0] ted_digi;
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
	.mux(mux),
	.ras(ras),
	.cas(cas),
	.cs0(CS0),
	.cs1(CS1),
	.aec(aec),
	.k(kbus),
	.digi_sound(ted_digi),
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
	.key_play(key_play),
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

// address and data bus latching
assign c16_addr=(~mux)?c16_addrlatch:cpu_addr&ted_addr;			// C16 address bus
assign c16_data=(mux)?c16_datalatch:cpu_data&ted_data&DIN&keyport_data&sid_data&openbus_data; // C16 data bus

always @(posedge CLK28) begin
	c16_datalatch<=c16_data;
	c16_addrlatch<=c16_addr;
end

// open bus reads for unmapped I/O space ($FDE0-$FDFF)
wire       openbus_sel = cpu_addr[15:5] == {8'hFD, 3'b111};
wire [7:0] openbus_data = openbus_sel ? c16_datalatch : 8'hff;

assign ADDR=c16_addr;
assign DOUT=cpu_data;
assign MUX=mux;
assign RAS=ras;
assign CAS=cas;

assign {port_in[5],port_in[3:0]} = {port_out[5],port_out[3:0]};

// connect IEC bus
wire iec_data, iec_clk;
iecdrv_sync dat_sync(CLK28, IEC_DATAIN, iec_data);
iecdrv_sync clk_sync(CLK28, IEC_CLKIN,  iec_clk);

assign IEC_DATAOUT = ~port_out[0];
assign IEC_CLKOUT  = ~port_out[1];
assign IEC_ATNOUT  = ~port_out[2];
assign port_in[6]  = ~port_out[1] & iec_clk;
assign port_in[7]  = ~port_out[0] & iec_data;
assign IEC_RESET   = sreset;

assign port_in[4]  = cass_in;
assign cass_mtr    = port_out[3];
assign cass_out    = port_out[6];

endmodule
