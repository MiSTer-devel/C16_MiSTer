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
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

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

	input         CLK_AUDIO, // 24.576 MHz
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

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

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

assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
 
assign LED_USER  = ioctl_download | |led_disk | tape_led;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign VGA_SCALER= 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

// Status Bit Map:
//              Upper                          Lower
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// X XXXXXXXXXX XX XXXXX  XXXX

`include "build_id.v" 
parameter CONF_STR = {
	"C16;;",
	"S0,D64G64,Mount #8;",
	"S1,D64G64,Mount #9;",
	"-;",
	"h4F1,PRGTAPBIN,Load;",
	"H4F1,PRGTAP,Load;",
	"-;",
	"h3RG,Tape Play/Pause;",
	"h3RI,Tape Unload;",
	"h3OH,Tape Sound,Off,On;",
	"h3OA,Tape Autoplay,Yes,No;",
	"h3-;",
	"O5,Joysticks swap,No,Yes;",
	"-;",
	"OJK,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O24,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"O78,TV Standard,from Kernal,Force PAL,Force NTSC;",
	"H2d1ON,Vertical Crop,No,Yes;",
	"h2d1ONO,Vertical Crop,No,270,216;",
	"OPQ,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"-;",
	"ODE,SID card,Disabled,6581,8580;",
	"OB,External IEC,Disabled,Enabled;",
	"-;",
	"O9,Model,C16,Plus/4;",
	"D0O6,Kernal,Loaded,Original;",
	"FC3,ROM,Load Kernal;",
	"-;",
	"R0,Reset & Apply;",
	"J,Fire;",
	"V,v",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire clk_sys;
wire locked;

pll pll
(
	.refclk(CLK_50M),
	.outclk_0(clk_sys),
	.outclk_1(CLK_VIDEO),
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

reg c16_pal;
always @(posedge clk_sys) c16_pal <= pal;

always @(posedge CLK_50M) begin
	reg pald = 0, pald2 = 0;
	reg [2:0] state = 0;

	pald  <= c16_pal;
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

wire [31:0] sd_lba[2];
wire  [5:0] sd_blk_cnt[2];
wire  [1:0] sd_rd;
wire  [1:0] sd_wr;
wire  [1:0] sd_ack;
wire [13:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din[2];
wire        sd_buff_wr;
wire  [1:0] img_mounted;
wire        img_readonly;
wire [31:0] img_size;
reg         ioctl_wait = 0;
wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR), .VDNUM(2), .BLKSZ(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.status_menumask({model,tap_loaded,en1080p,|vcrop,~rom_loaded}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),

	.ps2_key(ps2_key),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wait(ioctl_wait),

	.sd_lba(sd_lba),
	.sd_blk_cnt(sd_blk_cnt),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.joystick_0(joya),
	.joystick_1(joyb)
);

wire load_prg = (ioctl_index == 'h01);
wire load_tap = (ioctl_index == 'h41);
wire load_crt = (ioctl_index == 'h81);
wire load_rom = (ioctl_index == 'h03);

/////////////////  RESET  /////////////////////////

wire sys_reset = RESET | status[0] | buttons[1];
wire reset = sys_reset | cart_reset;

/////////////////   RAM   /////////////////////////

reg [15:0] dl_addr;
reg  [7:0] dl_data;
reg        dl_wr;
reg        model;
reg        romv;

always @(posedge clk_sys) begin
	reg        old_download = 0;
	reg  [3:0] state = 0;
	reg [15:0] addr;

	if(reset) begin
		model <= status[9];
		romv  <= status[6];
	end

	dl_wr <= 0;
	old_download <= ioctl_download;

	if(ioctl_download && load_prg) begin
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

	if(old_download && ~ioctl_download && load_prg) state <= 1;
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

	.clock_b(clk_sys),
	.address_b(c16_addr),
	.data_b(c16_dout),
	.wren_b(ram_we),
	.q_b(ram_dout),
	.cs_b(~cs_ram)
);

reg ram_we;
always @(posedge clk_sys) begin
	reg old_cs;
	ram_we <= 0;
	
	old_cs <= cs_ram;
	if(old_cs & ~cs_ram) ram_we <= ~c16_rnw;
end

/////////////////   ROM   /////////////////////////

reg rom_loaded =0;
always @(posedge clk_sys) if(ioctl_wr && (ioctl_addr[24:14]==1) && load_rom) rom_loaded <=1;

// Kernal rom
wire [7:0] kernal0_dout;
gen_rom #("rtl/roms/c16_kernal.mif") kernal0
(
	.wrclock(clk_sys),
	.wraddress(ioctl_addr[13:0]),
	.data(ioctl_dout),
	.wren(ioctl_wr && (ioctl_addr[24:14]==1) && load_rom),

	.rdclock(clk_sys),
	.rdaddress(c16_addr[13:0]),
	.q(kernal0_dout),
	.cs(~cs1 && (!romh || kern) && ~romv)
);

wire [7:0] kernal1_dout;
gen_rom #("rtl/roms/c16_kernal.mif") kernal1
(
	.wrclock(clk_sys),

	.rdclock(clk_sys),
	.rdaddress(c16_addr[13:0]),
	.q(kernal1_dout),
	.cs(~cs1 && (!romh || kern) && romv)
);

// Basic rom
wire [7:0] basic_dout;
gen_rom #("rtl/roms/c16_basic.mif") basic
(
	.wrclock(clk_sys),
	.wraddress(ioctl_addr[13:0]),
	.data(ioctl_dout),
	.wren(ioctl_wr && (ioctl_addr[24:14]==2) && load_rom),

	.rdclock(clk_sys),
	.rdaddress(c16_addr[13:0]),
	.q(basic_dout),
	.cs(~cs0 && !roml)
);

// Func low
wire [7:0] fl_dout;
gen_rom #("rtl/roms/3-plus-1_low.mif") funcl
(
	.wrclock(clk_sys),
	.wraddress(ioctl_addr[13:0]),
	.data(ioctl_dout),
	.wren(ioctl_wr && (ioctl_addr[24:14]==3) && load_rom),

	.rdclock(clk_sys),
	.rdaddress(c16_addr[13:0]),
	.q(fl_dout),
	.cs(~cs0 && roml==2)
);

// Func high
wire [7:0] fh_dout;
gen_rom #("rtl/roms/3-plus-1_high.mif") funch
(
	.wrclock(clk_sys),
	.wraddress(ioctl_addr[13:0]),
	.data(ioctl_dout),
	.wren(ioctl_wr && (ioctl_addr[24:14]==4) && load_rom),

	.rdclock(clk_sys),
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
	.wren(ioctl_wr && (ioctl_addr[24:14]==0) && load_crt),

	.rdclock(clk_sys),
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
	.wren(ioctl_wr && (ioctl_addr[24:14]==1) && load_crt),

	.rdclock(clk_sys),
	.rdaddress(c16_addr[13:0]),
	.q(carth_dout),
	.cs(~cs1 && carth && romh==1 && ~kern)
);

wire cart_reset = model & ioctl_download & load_crt;
reg cartl,carth;
always @(posedge clk_sys) begin
	if(sys_reset) {cartl,carth} <= 0;
	if(ioctl_wr && (ioctl_addr[24:14]==0) && load_crt) cartl <= 1;
	if(ioctl_wr && (ioctl_addr[24:14]==1) && load_crt) carth <= 1;
end

wire kern = (c16_addr[15:8]==8'hFC);

reg [1:0] roml, romh;
always @(posedge clk_sys) begin
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

wire  [7:0] c16_din = ram_dout & kernal0_dout & kernal1_dout & basic_dout & fh_dout & fl_dout & cartl_dout & carth_dout & cass_dout & openbus_data;

wire       openbus_sel  = c16_addr[15:5] == {8'hFD, 3'b111};
wire [7:0] openbus_data = openbus_sel ? c16_datalatch : 8'hff;

reg [7:0] c16_datalatch;
always @(posedge clk_sys) c16_datalatch<=c16_din;


wire        cs_ram,cs0,cs1,cs_io;
C16 c16
(
	.CLK28   ( clk_sys ), // NTSC 28.636299, PAL 28.384615
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
	.wide    ( wide ),

	.RnW     ( c16_rnw ),
	.ADDR    ( c16_addr ),
	.DOUT    ( c16_dout ),
	.DIN     ( c16_din ),
	.CS_RAM  ( cs_ram ),
	.CS0     ( cs0 ),
	.CS1     ( cs1 ),
	.CS_IO   ( cs_io ),

	.cass_mtr( cass_motor ),
	.cass_in ( tape_adc_act ? ~tape_adc : cass_read ),
	.cass_aud( cass_read & status[17] & ~cass_sense & ~cass_motor),
	.cass_out( cass_write ),

	.JOY0    ( status[5] ? joyb[4:0] : joya[4:0] ),
	.JOY1    ( status[5] ? joya[4:0] : joyb[4:0] ),

	.ps2_key ( ps2_key ),
	.key_play( key_play ),

	.sid_type( status[14:13] ),
	.sound   ( AUDIO_L ),

	.IEC_DATAIN  ( c1541_iec_data_o & ext_iec_data ),
	.IEC_CLKIN   ( c1541_iec_clk_o  & ext_iec_clk  ),
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

reg [9:0] vcrop;
reg wide;
always @(posedge CLK_VIDEO) begin
	vcrop <= 0;
	wide <= 0;
	if(HDMI_WIDTH >= (HDMI_HEIGHT + HDMI_HEIGHT[11:1]) && !forced_scandoubler && !scale) begin
		if(HDMI_HEIGHT == 480)  vcrop <= 240;
		if(HDMI_HEIGHT == 600)  begin vcrop <= 200; wide <= vcrop_en; end
		if(HDMI_HEIGHT == 720)  vcrop <= 240;
		if(HDMI_HEIGHT == 768)  vcrop <= 256; // NTSC mode has 245 visible lines only!
		if(HDMI_HEIGHT == 800)  begin vcrop <= 200; wide <= vcrop_en; end
		if(HDMI_HEIGHT == 1080) vcrop <= (~pal | status[24]) ? 10'd216 : 10'd270;
		if(HDMI_HEIGHT == 1200) vcrop <= 240;
	end
end

reg en1080p;
always @(posedge CLK_VIDEO) en1080p <= (HDMI_WIDTH == 1920) && (HDMI_HEIGHT == 1080);

wire [1:0] ar = status[20:19];
wire vcrop_en = en1080p ? |status[24:23] : status[23];
wire vga_de;
video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? (wide ? 12'd324 : 12'd400) : (ar - 1'd1)),
	.ARY((!ar) ? 12'd300 : 12'd0),
	.CROP_SIZE(vcrop_en ? vcrop : 10'd0),
	.CROP_OFF(0),
	.SCALE(status[26:25])
);

video_mixer #(456, 1, 1) mixer
(
	.CLK_VIDEO(CLK_VIDEO),
	
	.hq2x(scale == 1),
	.scandoubler(scale || forced_scandoubler),
	.gamma_bus(gamma_bus),

	.ce_pix(ce_vid),
	.R(rc),
	.G(gc),
	.B(bc),
	.HSync(hsc),
	.VSync(vsc),
	.HBlank(hblc),
	.VBlank(vblc),

	.CE_PIXEL(CE_PIXEL),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_VS(VGA_VS),
	.VGA_HS(VGA_HS),
	.VGA_DE(vga_de)
);

///////////////////////////////////////////////////

wire [1:0] led_disk;

wire c1541_iec_data_o;
wire c1541_iec_clk_o;

c1541_multi #(.PARPORT(0)) c1541
(
	.clk(clk_sys),
	.reset({c16_iec_reset_o | ~drive_mounted[1], c16_iec_reset_o | ~drive_mounted[0]}),
	.ce(ce_c1541),

	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.gcr_mode(2'b11),

	.led(led_disk),

	.iec_atn_i(c16_iec_atn_o),
	.iec_data_i(c16_iec_data_o & ext_iec_data),
	.iec_clk_i(c16_iec_clk_o & ext_iec_clk),
	.iec_data_o(c1541_iec_data_o),
	.iec_clk_o(c1541_iec_clk_o),

	.clk_sys(clk_sys),

	.sd_lba(sd_lba),
	.sd_blk_cnt(sd_blk_cnt),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	
	.rom_addr(ioctl_addr[13:0]),
	.rom_data(ioctl_dout),
	.rom_wr(ioctl_wr && (ioctl_addr[24:14] == 0) && load_rom),
	.rom_std(romv)
);

reg [1:0] drive_mounted = 0;
always @(posedge clk_sys) begin 
	if(img_mounted[0]) drive_mounted[0] <= |img_size;
	if(img_mounted[1]) drive_mounted[1] <= |img_size;
end

reg ce_c1541;
always @(negedge clk_sys) begin
	reg pald0, pald1;
	int sum = 0;
	int msum;
	
	pald0 <= c16_pal;
	pald1 <= pald0;

	msum <= pald1 ? 28375168 : 28636360;

	ce_c1541 <= 0;
	sum = sum + 16000000;
	if(sum >= msum) begin
		sum = sum - msum;
		ce_c1541 <= 1;
	end
end

wire ext_iec_en   = status[11];
wire ext_iec_clk  = USER_IN[2] | ~ext_iec_en;
wire ext_iec_data = USER_IN[4] | ~ext_iec_en;

assign USER_OUT[0] = 1;
assign USER_OUT[1] = 1;
assign USER_OUT[2] = (c16_iec_clk_o & c1541_iec_clk_o)  | ~ext_iec_en;
assign USER_OUT[3] = ~c16_iec_reset_o | ~ext_iec_en;
assign USER_OUT[4] = (c16_iec_data_o & c1541_iec_data_o) | ~ext_iec_en;
assign USER_OUT[5] = c16_iec_atn_o | ~ext_iec_en;
assign USER_OUT[6] = 1;


///////////////////////////////////////////////////

assign DDRAM_CLK = clk_sys;
ddram ddram
(
	.*,
	.addr((ioctl_download & load_tap) ? ioctl_addr : tap_play_addr),
	.dout(tap_data),
	.din(ioctl_dout),
	.we(tap_wr),
	.rd(tap_rd),
	.ready(tap_data_ready)
);

reg       tap_wr;
reg [1:0] tap_version;
always @(posedge clk_sys) begin
	reg old_reset;

	old_reset <= reset;
	if(~old_reset && reset) ioctl_wait <= 0;

	tap_wr <= 0;
	if(ioctl_wr & load_tap) begin
		ioctl_wait <= 1;
		tap_wr <= 1;
		if (ioctl_addr == 'h0C) tap_version <= ioctl_dout[1:0];
	end
	else if(~tap_wr & ioctl_wait & tap_data_ready) begin
		ioctl_wait <= 0;
	end
end

wire [7:0] cass_dout = {5'b11111, cs_io | (c16_addr[8:4] != 'h11) | (~tape_adc_act & cass_sense), 2'b11};

reg        tap_rd;
wire       tap_finish;
reg [24:0] tap_play_addr;
reg [24:0] tap_last_addr;
wire [7:0] tap_data;
wire       tap_data_ready;
wire       tap_reset = reset | (ioctl_download & load_tap) | status[18] | tap_finish | (cass_run & ((tap_last_addr - tap_play_addr) < 80));
reg        tap_wrreq;
wire       tap_wrfull;
wire       tap_loaded = (tap_play_addr < tap_last_addr);
wire       cass_sense;
wire       key_play;
reg        tap_autoplay = 0;

always @(posedge clk_sys) begin
	reg tap_cycle = 0;

	if(tap_reset) begin
		//C1530 module requires one more byte at the end due to fifo early check.
		tap_last_addr <= (ioctl_download & load_tap) ? ioctl_addr+2'd2 : 25'd0;
		tap_play_addr <= 0;
		tap_rd <= 0;
		tap_cycle <= 0;
		tap_autoplay <= ioctl_download & load_tap & ~status[10];
	end
	else begin
		tap_rd <= 0;
		tap_wrreq <= 0;
		tap_autoplay <= 0;

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
always @(posedge clk_sys) act_cnt <= act_cnt + (cass_sense ? 4'd1 : 4'd8);
wire tape_led = tap_loaded && (act_cnt[26] ? ((cass_sense | ~cass_motor) && act_cnt[25:18] > act_cnt[7:0]) : act_cnt[25:18] <= act_cnt[7:0]);

wire cass_motor;
wire cass_run;
wire cass_read;
wire cass_write;

c1530 c1530
(
	.clk32(clk_sys),
	.restart_tape(tap_reset),
	
	.wav_mode(0),
	.tap_version(tap_version),

	.host_tap_in(tap_data),
	.host_tap_wrreq(tap_wrreq),
	.tap_fifo_wrfull(tap_wrfull),
	.tap_fifo_error(tap_finish),

	.osd_play_stop_toggle(status[16]|key_play|tap_autoplay),
	.cass_motor(cass_motor),
	.cass_sense(cass_sense),
	.cass_read(cass_read),
	.cass_write(cass_write),
	.cass_run(cass_run),
	.ear_input(0)
);

wire tape_adc, tape_adc_act;
ltc2308_tape #(.CLK_RATE(28375168)) ltc2308_tape
(
  .clk(clk_sys),
  .ADC_BUS(ADC_BUS),
  .dout(tape_adc),
  .active(tape_adc_act)
);

endmodule
