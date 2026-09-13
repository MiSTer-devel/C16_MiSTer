`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// NAE/CAE SID card (V2.0) for the Plus/4.
//
// - SID: $FD40-$FD5F, $FE80-$FE9F (cfg bit2), $D400-$D41F write only (cfg bit1)
// - DigiBlaster: 8-bit DAC at SID register $1E (cfg bit3)
// - Card registers at $FD80-$FD8F:
//     $FD80/$FD81  joystick (not implemented, reads $FF)
//     $FD88        data of last SID access
//     $FD89        {R/W, 0, 0, A4..A0} of last SID access
//     $FD8D        command register (write only, reads $00)
//     $FD8E        {NTSC, 000, cfg}
//     $FD8F        version $20, bit7 NTSC, bit0 left SID is 6581
//   Mouse ($A0-$A3) and Synergy compatibility ($E0/$E1) are not implemented.
//
//////////////////////////////////////////////////////////////////////////////////
module sid_card
(
	input             clk,
	input             reset,

	input             enabled,
	input             c64,
	input             split,        // 0: both SIDs at $FD40/$FE80, 1: left $FD40, right $FE80
	input             pal,
	input             sid_ver,

	input             mux,
	input      [15:0] addr,
	input             rnw,
	input       [7:0] data_in,
	input       [7:0] sid_dout,

	output      [1:0] sid_cs,       // {right, left}
	output            sid_we,
	output      [7:0] data_out,     // $FF when not selected

	output reg        ce_sid,
	output      [7:0] digi_l,       // unsigned, 0 when off
	output      [7:0] digi_r,
	output reg  [3:0] cfg
);

// -----------------------------------------------------------------------
// Address decode
// -----------------------------------------------------------------------

wire fd40_sel = (addr[15:5] == 11'b11111101010) & enabled;
wire fe80_sel = (addr[15:5] == 11'b11111110100) & enabled & cfg[2];
wire d400_sel = (addr[15:5] == 11'b11010100000) & enabled & cfg[1] & ~rnw;
wire card_sel = (addr[15:4] == 12'hFD8) & enabled;

wire left_sel = fd40_sel | d400_sel;
wire sid_sel  = left_sel | fe80_sel;

wire sid_sel_l = split ? left_sel : sid_sel;
wire sid_sel_r = split ? fe80_sel : sid_sel;

assign sid_cs = {sid_sel_r, sid_sel_l};
assign sid_we = ~rnw & sid_sel;

// -----------------------------------------------------------------------
// Registers
// -----------------------------------------------------------------------

reg  [7:0] last_data;
reg  [7:0] last_ctl;
reg  [7:0] digi_lr, digi_rr;
reg        mux_d;

// Bus is valid (address, data and R/W) when MUX falls
wire strobe = mux_d & ~mux;

always @(posedge clk) begin
	mux_d <= mux;

	if(reset) begin
		cfg       <= c64 ? 4'hF : 4'hC;
		last_data <= 8'h00;
		last_ctl  <= 8'h00;
		digi_lr   <= 8'h00;
		digi_rr   <= 8'h00;
	end
	else if(strobe) begin
		if(card_sel & ~rnw & (addr[3:0] == 4'hD)) begin
			case(data_in)
				8'hD0, 8'hD1, 8'hD2, 8'hD3: cfg[1:0] <= data_in[1:0];
				8'hF0: cfg[2] <= 1'b0;
				8'hF1: cfg[2] <= 1'b1;
				8'hDD: cfg[3] <= 1'b0;
				8'hDE: cfg[3] <= 1'b1;
				default: ;
			endcase
		end

		if(sid_sel) begin
			last_data <= rnw ? sid_dout : data_in;
			last_ctl  <= {rnw, 2'b00, addr[4:0]};

			if(~rnw & (addr[4:0] == 5'h1E)) begin
				if(sid_sel_l) digi_lr <= data_in;
				if(sid_sel_r) digi_rr <= data_in;
			end
		end
	end
end

assign digi_l = (enabled & cfg[3]) ? digi_lr : 8'h00;
assign digi_r = (enabled & cfg[3]) ? digi_rr : 8'h00;

reg [7:0] card_data;
always @(*) begin
	case(addr[3:0])
		4'h0, 4'h1: card_data = 8'hFF;
		4'h8:       card_data = last_data;
		4'h9:       card_data = last_ctl;
		4'hE:       card_data = {~pal, 3'b000, cfg};
		4'hF:       card_data = {~pal, 6'b010000, ~sid_ver};
		default:    card_data = 8'h00;
	endcase
end

assign data_out = (rnw & (fd40_sel | fe80_sel)) ? sid_dout  :
                  (rnw & card_sel)              ? card_data :
                                                  8'hFF;

// -----------------------------------------------------------------------
// SID clock enable
// -----------------------------------------------------------------------
// cfg[0]=0: CLK28/32
// cfg[0]=1: PAL CLK28/28.8 (29,29,29,29,28), NTSC CLK28/28

reg [4:0] div = 0;
reg [2:0] div_seq = 0;

always @(posedge clk) begin
	ce_sid <= 1'b0;

	if(|div) div <= div - 1'd1;
	else begin
		ce_sid  <= 1'b1;
		div_seq <= div_seq[2] ? 3'd0 : div_seq + 1'd1;
		div     <= ~cfg[0]             ? 5'd31 :
		           (pal & ~div_seq[2]) ? 5'd28 :
		                                 5'd27;
	end
end

endmodule
