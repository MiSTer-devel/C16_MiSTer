//============================================================================
//  C16,Plus/4
//
//  Port to MiSTer
//  Copyright (C) 2017-2019 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
 
assign LED_USER  = ioctl_download | led_disk | tape_led;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;

assign VIDEO_ARX = status[1] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[1] ? 8'd9  : 8'd3; 

`include "build_id.v" 
parameter CONF_STR = {
	"C16;;",
	"-;",
	"F,PRG,Load Program;",
	"F,BIN,Load Cart(Plus/4);",
	"-;",
	"S,D64,Mount Disk;",
	"-;",
	"F,TAP,Tape Load;",
	"RG,Tape Play/Pause;",
	"RI,Tape Unload;",
	"OH,Tape Sound,Off,On;",
	"-;",
	"O1,Aspect ratio,4:3,16:9;",
	"O24,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"O78,TV Standard,from Kernal,Force PAL,Force NTSC;",
	"-;",
	"ODE,SID card,Disabled,6581,8580;",
	"-;",
	"O5,Joysticks swap,No,Yes;",
	"-;",
	"O9,Model,C16,Plus/4;",
	"D0O6,Kernal,from boot.rom,Original;",
	"R0,Reset;",
	"J,Fire;",
	"V,v",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire clk_sys;
wire clk_c16 = clk_sys & clk_en;
wire locked;

pll pll
(
	.refclk(CLK_50M),
	.outclk_0(clk_sys),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll),
	.locked(locked)
);

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;
wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

pll_cfg pll_cfg
(
	.mgmt_clk(CLK_50M),
	.mgmt_reset(0),
	.mgmt_waitrequest(cfg_waitrequest),
	.mgmt_read(0),
	.mgmt_readdata(),
	.mgmt_write(cfg_write),
	.mgmt_address(cfg_address),
	.mgmt_writedata(cfg_data),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

always @(posedge CLK_50M) begin
	reg pald = 0, pald2 = 0;
	reg [2:0] state = 0;

	pald  <= pal;
	pald2 <= pald;

	cfg_write <= 0;
	if(pald2 != pald) state <= 1;

	if(!cfg_waitrequest) begin
		if(state) state<=state+1'd1;
		case(state)
			1: begin
					cfg_address <= 0;
					cfg_data <= 0;
					cfg_write <= 1;
				end
			3: begin
					cfg_address <= 7;
					cfg_data <= pald2 ? 343828281 : 702807832;
					cfg_write <= 1;
				end
			5: begin
					cfg_address <= 2;
					cfg_data <= 0;
					cfg_write <= 1;
				end
		endcase
	end
end

reg clk_en = 0;
always @(negedge clk_sys) begin
	reg lockedd;

	lockedd <= locked;
	clk_en <= ~clk_en;
	if(~lockedd) clk_en <= 0;
end


/////////////////  HPS  ///////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire [15:0] joya, joyb;
wire [10:0] ps2_key;

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        forced_scandoubler;

wire [31:0] sd_lba;
wire        sd_rd;
wire        sd_wr;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
reg         ioctl_wait = 0;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.status_menumask({~rom_loaded}),
	.forced_scandoubler(forced_scandoubler),

	.ps2_key(ps2_key),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wait(ioctl_wait),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),

	.joystick_0(joya),
	.joystick_1(joyb)
);

/////////////////  RESET  /////////////////////////

wire sys_reset = RESET | status[0] | buttons[1];
wire reset = sys_reset | cart_reset;

/////////////////   RAM   /////////////////////////

reg [15:0] dl_addr;
reg  [7:0] dl_data;
reg        dl_wr;
reg        model;

always @(posedge clk_sys) begin
	reg        old_download = 0;
	reg  [3:0] state = 0;
	reg [15:0] addr;

	if(reset) model <= status[9];

	dl_wr <= 0;
	old_download <= ioctl_download;

	if(ioctl_download && (ioctl_index == 1)) begin
		state <= 0;
		if(ioctl_wr) begin
			     if(ioctl_addr == 0) addr[7:0]  <= ioctl_dout;
			else if(ioctl_addr == 1) addr[15:8] <= ioctl_dout;
			else begin
				dl_addr <= addr;
				dl_data <= ioctl_dout;
				dl_wr   <= 1;
				addr    <= addr + 1'd1;
			end
		end
	end

	if(old_download && ~ioctl_download && (ioctl_index == 1)) state <= 1;
	if(state) state <= state + 1'd1;

	case(state)
		 1: begin dl_addr <= 16'h2d; dl_data <= addr[7:0];  dl_wr <= 1; end
		 3: begin dl_addr <= 16'h2e; dl_data <= addr[15:8]; dl_wr <= 1; end
		 5: begin dl_addr <= 16'h2f; dl_data <= addr[7:0];  dl_wr <= 1; end
		 7: begin dl_addr <= 16'h30; dl_data <= addr[15:8]; dl_wr <= 1; end
		 9: begin dl_addr <= 16'h31; dl_data <= addr[7:0];  dl_wr <= 1; end
		11: begin dl_addr <= 16'h32; dl_data <= addr[15:8]; dl_wr <= 1; end
		13: begin dl_addr <= 16'h9d; dl_data <= addr[7:0];  dl_wr <= 1; end
		15: begin dl_addr <= 16'h9e; dl_data <= addr[15:8]; dl_wr <= 1; end
	endcase
end

wire [7:0] ram_dout;
gen_dpram #(16) main_ram
(
	.clock_a(clk_sys),
	.address_a(dl_addr),
	.data_a(dl_data),
	.wren_a(dl_wr),

	.clock_b(clk_c16),
	.address_b(c16_addr),
	.data_b(c16_dout),
	.wren_b(ram_we),
	.q_b(ram_dout),
	.cs_b(~cs_ram)
);

reg ram_we;
always @(posedge clk_c16) begin
	reg old_cs;
	ram_we <= 0;
	
	old_cs <= cs_ram;
	if(old_cs & ~cs_ram) ram_we <= ~c16_rnw;
end

/////////////////   ROM   /////////////////////////

reg rom_loaded =0;
always @(posedge clk_sys) if(ioctl_wr && (ioctl_addr[24:14]==1) && !ioctl_index) rom_loaded <=1;

// Kernal rom
wire [7:0] kernal0_dout;
gen_rom #("roms/c16_kernal.mif") kernal0
(
	.wrclock(clk_sys),
	.wraddress(ioctl_addr[13:0]),
	.data(ioctl_dout),
	.wren(ioctl_wr && (ioctl_addr[24:14]==1) && !ioctl_index),

	.rdclock(clk_c16),
	.rdaddress(c16_addr[13:0]),
	.q(kernal0_dout),
	.cs(~cs1 && (!romh || kern) && ~status[6])
);

wire [7:0] kernal1_dout;
gen_rom #("roms/c16_kernal.mif") kernal1
(
	.wrclock(clk_sys),

	.rdclock(clk_c16),
	.rdaddress(c16_addr[13:0]),
	.q(kernal1_dout),
	.cs(~cs1 && (!romh || kern) && status[6])
);

// Basic rom
wire [7:0] basic_dout;
gen_rom #("roms/c16_basic.mif") basic
(
	.wrclock(clk_sys),
	.wraddress(ioctl_addr[13:0]),
	.data(ioctl_dout),
	.wren(ioctl_wr && (ioctl_addr[24:14]==2) && !ioctl_index),

	.rdclock(clk_c16),
	.rdaddress(c16_addr[13:0]),
	.q(basic_dout),
	.cs(~cs0 && !roml)
);

// Func low
wire [7:0] fl_dout;
gen_rom #("roms/3-plus-1_low.mif") funcl
(
	.wrclock(clk_sys),
	.wraddress(ioctl_addr[13:0]),
	.data(ioctl_dout),
	.wren(ioctl_wr && (ioctl_addr[24:14]==3) && !ioctl_index),

	.rdclock(clk_c16),
	.rdaddress(c16_addr[13:0]),
	.q(fl_dout),
	.cs(~cs0 && roml==2)
);

// Func high
wire [7:0] fh_dout;
gen_rom #("roms/3-plus-1_high.mif") funch
(
	.wrclock(clk_sys),
	.wraddress(ioctl_addr[13:0]),
	.data(ioctl_dout),
	.wren(ioctl_wr && (ioctl_addr[24:14]==4) && !ioctl_index),

	.rdclock(clk_c16),
	.rdaddress(c16_addr[13:0]),
	.q(fh_dout),
	.cs(~cs1 && romh==2 && ~kern)
);

// Cart low
wire [7:0] cartl_dout;
gen_rom cart_l
(
	.wrclock(clk_sys),
	.wraddress(ioctl_addr[13:0]),
	.data(ioctl_dout),
	.wren(ioctl_wr && (ioctl_addr[24:14]==0) && (ioctl_index==2)),

	.rdclock(clk_c16),
	.rdaddress(c16_addr[13:0]),
	.q(cartl_dout),
	.cs(~cs0 && cartl && roml==1)
);

// Cart high
wire [7:0] carth_dout;
gen_rom cart_h
(
	.wrclock(clk_sys),
	.wraddress(ioctl_addr[13:0]),
	.data(ioctl_dout),
	.wren(ioctl_wr && (ioctl_addr[24:14]==1) && (ioctl_index==2)),

	.rdclock(clk_c16),
	.rdaddress(c16_addr[13:0]),
	.q(carth_dout),
	.cs(~cs1 && carth && romh==1 && ~kern)
);

wire cart_reset = model & ioctl_download & (ioctl_index==2);
reg cartl,carth;
always @(posedge clk_sys) begin
	if(sys_reset) {cartl,carth} <= 0;
	if(ioctl_wr && (ioctl_addr[24:14]==0) && (ioctl_index==2)) cartl <= 1;
	if(ioctl_wr && (ioctl_addr[24:14]==1) && (ioctl_index==2)) carth <= 1;
end

wire kern = (c16_addr[15:8]==8'hFC);

reg [1:0] roml, romh;
always @(posedge clk_c16) begin
	reg old_cs;

	old_cs <= cs_io;

	if(reset) {romh,roml} <= 0;
	else if(model && old_cs && ~cs_io && ~c16_rnw && c16_addr[15:4] == 12'hFDD) {romh,roml} <= c16_addr[3:0];
end

///////////////////////////////////////////////////

wire  [7:0] c16_dout;
wire [15:0] c16_addr;
wire        c16_rnw;
wire        pal;

wire  [7:0] c16_din = ram_dout & kernal0_dout & kernal1_dout & basic_dout & fh_dout & fl_dout & cartl_dout & carth_dout & cass_dout;

wire        cs_ram,cs0,cs1,cs_io;
C16 c16
(
	.CLK28   ( clk_c16 ), // NTSC 28.636299, PAL 28.384615
	.RESET   ( reset ),
	.WAIT    ( 0 ),
	.PAL     ( pal ),

	.CE_PIX  ( ce_pix ),
	.HSYNC   ( hs ),
	.VSYNC   ( vs ),
	.HBLANK  ( hblank ),
	.VBLANK  ( vblank ),
	.RED     ( r ),
	.GREEN   ( g ),
	.BLUE    ( b ),
	.tvmode  ( status[8:7] ),

	.RnW     ( c16_rnw ),
	.ADDR    ( c16_addr ),
	.DOUT    ( c16_dout ),
	.DIN     ( c16_din ),
	.CS_RAM  ( cs_ram ),
	.CS0     ( cs0 ),
	.CS1     ( cs1 ),
	.CS_IO   ( cs_io ),

	.cass_mtr( cass_motor ),
	.cass_in ( cass_do ),
	.cass_aud( cass_do & status[17] & tap_play & ~cass_motor),

	.JOY0    ( status[5] ? joyb[4:0] : joya[4:0] ),
	.JOY1    ( status[5] ? joya[4:0] : joyb[4:0] ),

	.ps2_key ( ps2_key ),

	.sid_type( status[14:13] ),
	.sound   ( AUDIO_L ),

	.IEC_DATAIN  ( c1541_iec_data_o ),
	.IEC_CLKIN   ( c1541_iec_clk_o  ),
	.IEC_ATNOUT  ( c16_iec_atn_o    ),
	.IEC_DATAOUT ( c16_iec_data_o   ),
	.IEC_CLKOUT  ( c16_iec_clk_o    ),
	.IEC_RESET   ( c16_iec_reset_o  )
);

wire c16_iec_atn_o;
wire c16_iec_data_o;
wire c16_iec_clk_o;
wire c16_iec_reset_o;

assign AUDIO_R = AUDIO_L;
assign AUDIO_MIX = 0;
assign AUDIO_S = 1;

wire hs, vs, hblank, vblank, ce_pix;
wire [3:0] r,g,b,rc,gc,bc;

wire [2:0] scale = status[4:2];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;

assign VGA_F1 = 0;
assign VGA_SL = sl[1:0];

assign CLK_VIDEO = clk_sys;

reg ce_vid;
always @(posedge CLK_VIDEO) begin
	reg old_ce;
	
	old_ce <= ce_pix;
	ce_vid <= ~old_ce & ce_pix;
end

wire vsc,hsc,hblc,vblc;
video_cleaner video_cleaner
(
	.clk_vid(CLK_VIDEO),
	.ce_pix(ce_vid),

	.R(r),
	.G(g),
	.B(b),
	.HSync(hs),
	.VSync(vs),
	.HBlank(hblank),
	.VBlank(vblank),

	.VGA_R(rc),
	.VGA_G(gc),
	.VGA_B(bc),
	.VGA_VS(vsc),
	.VGA_HS(hsc),
	.HBlank_out(hblc),
	.VBlank_out(vblc)
);

video_mixer #(456, 1) mixer
(
	.clk_sys(CLK_VIDEO),
	
	.ce_pix(ce_vid),
	.ce_pix_out(CE_PIXEL),

	.hq2x(scale == 1),
	.scanlines(0),
	.scandoubler(scale || forced_scandoubler),

	.R(rc),
	.G(gc),
	.B(bc),

	.mono(0),

	.HSync(hsc),
	.VSync(vsc),
	.HBlank(hblc),
	.VBlank(vblc),

	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_VS(VGA_VS),
	.VGA_HS(VGA_HS),
	.VGA_DE(VGA_DE)
);

///////////////////////////////////////////////////

wire led_disk;

wire c1541_iec_data_o;
wire c1541_iec_clk_o;

c1541_sd c1541_sd
(
	.clk_c1541(clk_sys & ce_c1541),
	.clk_sys(clk_sys),

	.rom_addr(ioctl_addr[13:0]),
	.rom_data(ioctl_dout),
	.rom_wr(ioctl_wr && (ioctl_addr[24:14] == 0) && !ioctl_index),
	.rom_std(status[6]),

   .disk_change(img_mounted ),
	.disk_readonly(img_readonly ),
   .led(led_disk),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),

	.iec_reset_i(c16_iec_reset_o),
	.iec_atn_i(c16_iec_atn_o),
	.iec_data_i(c16_iec_data_o),
	.iec_clk_i(c16_iec_clk_o),
	.iec_data_o(c1541_iec_data_o),
	.iec_clk_o(c1541_iec_clk_o)
);

reg ce_c1541;
always @(negedge clk_sys) begin
	int sum = 0;
	int msum;
	
	msum <= pal ? 56750336 : 57272720;

	ce_c1541 <= 0;
	sum = sum + 32000000;
	if(sum >= msum) begin
		sum = sum - msum;
		ce_c1541 <= 1;
	end
end


///////////////////////////////////////////////////

assign DDRAM_CLK = clk_sys;
ddram ddram
(
	.*,
	.addr((ioctl_download & tap_load) ? ioctl_addr : tap_play_addr),
	.dout(tap_data),
	.din(ioctl_dout),
	.we(tap_wr),
	.rd(tap_rd),
	.ready(tap_data_ready)
);

reg tap_wr;
always @(posedge clk_sys) begin
	reg old_reset;

	old_reset <= reset;
	if(~old_reset && reset) ioctl_wait <= 0;

	tap_wr <= 0;
	if(ioctl_wr & tap_load) begin
		ioctl_wait <= 1;
		tap_wr <= 1;
	end
	else if(~tap_wr & ioctl_wait & tap_data_ready) begin
		ioctl_wait <= 0;
	end
end


wire [7:0] cass_dout = {5'b11111, cs_io | (c16_addr[8:4] != 'h11) | ~tap_play, 2'b11};

reg        tap_rd;
wire       tap_finish;
reg [24:0] tap_play_addr;
reg [24:0] tap_last_addr;
wire [7:0] tap_data;
wire       tap_data_ready;
wire       tap_reset = reset | (ioctl_download & tap_load) | status[18] | (cass_motor & ((tap_last_addr - tap_play_addr) < 80));
reg        tap_wrreq;
wire       tap_wrfull;
wire       tap_loaded = (tap_play_addr < tap_last_addr);
reg        tap_play;
wire       tap_play_btn = status[16];
wire       tap_load = (ioctl_index == 4);

always @(posedge clk_sys) begin
	reg tap_play_btnD, tap_finishD;
	reg tap_cycle = 0;

	tap_play_btnD <= tap_play_btn;
	tap_finishD <= tap_finish;

	if(tap_reset) begin
		//C1530 module requires one more byte at the end due to fifo early check.
		tap_last_addr <= ioctl_download ? ioctl_addr+2'd2 : 25'd0;
		tap_play_addr <= 0;
		tap_play <= ioctl_download;
		tap_rd <= 0;
		tap_cycle <= 0;
	end
	else begin
		if (~tap_play_btnD & tap_play_btn) tap_play <= ~tap_play;
		if (~tap_finishD & tap_finish) tap_play <= 0;

		tap_rd <= 0;
		tap_wrreq <= 0;

		if(~tap_rd & ~tap_wrreq) begin
			if(tap_cycle) begin
				if(tap_data_ready) begin
					tap_play_addr <= tap_play_addr + 1'd1;
					tap_cycle <= 0;
					tap_wrreq <= 1;
				end
			end
			else begin
				if(~tap_wrfull & tap_loaded) begin
					tap_rd <= 1;
					tap_cycle <= 1;
				end
			end
		end
	end
end

reg [26:0] act_cnt;
always @(posedge clk_sys) act_cnt <= act_cnt + (tap_play ? 4'd8 : 4'd1);
wire tape_led = tap_loaded && (act_cnt[26] ? (~(tap_play & cass_motor) && act_cnt[25:18] > act_cnt[7:0]) : act_cnt[25:18] <= act_cnt[7:0]);

wire cass_motor;
wire cass_do;

c1530 c1530
(
	.clk(clk_sys),
	.restart(tap_reset),

	.clk_freq(56750336),
	.cpu_freq(886724),

	.din(tap_data),
	.wr(tap_wrreq),
	.full(tap_wrfull),
	.empty(tap_finish),

	.play(~cass_motor & tap_play),
	.dout(cass_do)
);

endmodule
