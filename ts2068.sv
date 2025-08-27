//============================================================================
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
//
//============================================================================

localparam NBDRIV=2;
localparam VD = NBDRIV-1;

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

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_S = 0;
assign AUDIO_L = 0;
assign AUDIO_R = 0;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[122:121];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v" 
/*
localparam CONF_STR = {
	"MyCore;;",
	"-;",
	"O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O[2],TV Mode,NTSC,PAL;",
	"O[4:3],Noise,White,Red,Green,Blue;",
	"-;",
	"P1,Test Page 1;",
	"P1-;",
	"P1-, -= Options in page 1 =-;",
	"P1-;",
	"P1O[5],Option 1-1,Off,On;",
	"d0P1F1,BIN;",
	"H0P1O[10],Option 1-2,Off,On;",
	"-;",
	"P2,Test Page 2;",
	"P2-;",
	"P2-, -= Options in page 2 =-;",
	"P2-;",
	"P2S0,DSK;",
	"P2O[7:6],Option 2,1,2,3,4;",
	"-;",
	"-;",
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	"v,0;", // [optional] config version 0-99. 
	        // If CONF_STR options are changed in incompatible way, then change version number too,
			  // so all options will get default values on first start.
	"V,v",`BUILD_DATE 
};
*/
localparam CONF_STR =
{
	"TS2068;;",
	"-;",
	"O[4:3],Noise,White,Red,Green,Blue;",
	"F1,ROM,Load ROM;",
	"F2,DCK,Load DCK;",
	"F3,TZX,Load TZX;",
	"S0,VHD,Mount SD;",
	"-;",
	"O5,Model,PAL,NTSC;",
	"O6,DivMMC,Off,On;",
	"-;",
	"T[0],Reset;",
   "R[0],Reset and close OSD;",
	"T2,NMI;",
	"V,V2.0,2025.08.10;",
};







//////////////////   HPS I/O   ///////////////////
wire [10:0] ps2_key;
wire [24:0] ps2_mouse;

wire [15:0] joy0;
wire [15:0] joy1;
wire   [1:0] buttons;
wire        forced_scandoubler;
wire [127:0] status;


//wire 			sd_rd_plus3;
//wire 			sd_wr_plus3;
//wire [31:0] sd_lba_plus3;
//wire [7:0]  sd_buff_din_plus3;
//
//wire 			sd_rd_wd;
//wire 			sd_wr_wd;
//wire [31:0] sd_lba_wd;
//wire [7:0]  sd_buff_din_wd;
//
//wire        sd_rd_mmc;
//wire        sd_wr_mmc;
//wire [31:0] sd_lba_mmc;
//wire [7:0]  sd_buff_din_mmc;

wire       sdRd;
wire       sdWr;
wire       sdAck;
wire [31:0] sd_lba[NBDRIV];
wire       sdBusy;
wire       sdConf;
wire       sdSdhc;
wire       sdAckCf;
wire[ 8:0] sdBuffA;
wire[ 7:0] sdBuffD;
wire[ 7:0] sdBuffQ;
wire       sdBuffW;
wire       imgMntd;
wire[63:0] imgSize;

//wire [31:0] sd_lba[2] = '{plus3_fdd_ready ? sd_lba_plus3 : sd_lba_wd, sd_lba_mmc};
//wire  [1:0] sd_rd = {sd_rd_mmc, plus3_fdd_ready ? sd_rd_plus3 : sd_rd_wd};
//wire  [1:0] sd_wr = {sd_wr_mmc, plus3_fdd_ready ? sd_wr_plus3 : sd_wr_wd};
wire  [1:0] sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
//wire  [7:0] sd_buff_din[2] = '{plus3_fdd_ready ? sd_buff_din_plus3 : sd_buff_din_wd, sd_buff_din_mmc};
wire        sd_buff_wr;
wire  [1:0] img_mounted;
wire [63:0] img_size;
wire        img_readonly;

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;
//wire        ioctl_wait;

wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR), .VDNUM(2)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(gamma_bus),
	
	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),

	.joystick_0(joy0),
	.joystick_1(joy1),
	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),
	.new_vmode(new_vmode),
	.status(status),
//	.status_menumask({|status[9:8],en1080p,|vcrop,~need_apply}),
//	.status_set(speed_set|arch_set|snap_hwset),
//	.status_in({status[63:25], speed_set ? speed_req : 3'b000, status[21:13], arch_set ? arch : snap_hwset ? snap_hw : status[12:8], status[7:0]}),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
//	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_size(img_size),
	.img_readonly(img_readonly),

	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index)
//	.ioctl_wait(ioctl_wait),
	

);

// Reset logic
reg rom_loaded = 0;
always @(posedge clk_sys) begin
    reg ioctl_downlD;
    ioctl_downlD <= ioctl_download;
    if (ioctl_downlD & ~ioctl_download) rom_loaded <= 1;
    reset <= ~(RESET |rom_loaded | status[0] | buttons[1]);
end

//hps_io #(.CONF_STR(CONF_STR)) hps_io
//(
//	.clk_sys(clk_sys),
//	.HPS_BUS(HPS_BUS),
//	.EXT_BUS(),
//	.gamma_bus(),
//
//	.forced_scandoubler(forced_scandoubler),
//
//	.buttons(buttons),
//	.status(status),
//	.status_menumask({status[5]}),
//	
//	.ps2_key(ps2_key)
//);

///////////////////////   CLOCKS   ///////////////////////////////
//--- clock ---------------------------------------------------------------------------------------

wire clock0, clock1, lock0, lock1;
wire clk_sys = clock0;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clock0),   // 56.000 MHz
   .locked(lock0)
);

pll1 pll1
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clock1),   // 56.488 MHz
   .locked(lock1)
);


wire clock = model ? clock1 : clock0;
wire power = lock0 & lock1;

reg[3:0] ce;
always @(negedge clock) if(!power) ce <= 1'd0; else ce <= ce+1'd1;

wire ne28M = ce[0:0] == 1;
wire ne14M = ce[1:0] == 3;
wire ne7M0 = ce[2:0] == 7;
wire pe7M0 = ce[2:0] == 3;
wire ne3M5 = ce[3:0] == 15;
wire pe3M5 = ce[3:0] == 7;
	




wire [1:0] col = status[4:3];

wire HBlank;

wire VBlank;

wire ce_pix;
wire [7:0] video;


//--- video ---------------------------------------------------------------------------------------
	wire HSync;
	wire VSync;
	wire r;
	wire g;
	wire b;
	wire i;

//--- memory --------------------------------------------------------------------------------------

wire[13:0] va;
wire[ 7:0] vd;

wire[15:0] memA;
wire[ 7:0] memD;
wire[ 7:0] memQ;
wire       memB;
wire[ 7:0] memM;
wire       memW;

wire       mapped;
wire       ramcs;
wire[ 3:0] page;

// Home ROM with $readmemh
reg [7:0] home_rom [0:16383]; // 16KB ROM (14-bit address)
wire [7:0] homeQ;

initial begin
    $readmemh("rtl/rom/tc2068-0.hex", home_rom);
end

always @(posedge clock) begin
    homeQ <= home_rom[romE ? dioA[13:0] : memA[13:0]];
end

// Extended ROM with $readmemh
reg [7:0] extd_rom [0:8191]; // 8KB ROM (13-bit address)
wire [7:0] extdQ;

initial begin
    $readmemh("rtl/rom/tc2068-1.hex", extd_rom);
end

always @(posedge clock) begin
    extdQ <= extd_rom[memA[12:0]];
end

// Dock RAM - converted to block RAM
reg [7:0] dock_ram [0:65535]; // 64KB RAM
wire [7:0] dockQ;

always @(posedge clock) begin
    if (dioW && dckE) begin
        dock_ram[dioA[15:0]] <= dioD;
    end
    dockQ <= dock_ram[dckE ? dioA[15:0] : memA[15:0]];
end

// ESXDOS ROM with $readmemh
reg [7:0] drom_rom [0:8191]; // 8KB ROM (13-bit address)
wire [7:0] dromQ;

initial begin
    $readmemh("rtl/rom/esxdos.hex", drom_rom);
end

always @(posedge clock) begin
    dromQ <= drom_rom[memA[12:0]];
end

// DRAM - converted to block RAM
reg [7:0] dram_ram [0:131071]; // 128KB RAM (17-bit address)
wire [7:0] dramQ;

always @(posedge clock) begin
    if (memW && memA[15:13] == 1 && mapped) begin
        dram_ram[{page, memA[12:0]}] <= memD;
    end
    dramQ <= dram_ram[{page, memA[12:0]}];
end

reg[7:0] dckS = 0;
always @(posedge clock) if(dckE) dckS <= dioA[15:13];

wire[7:0] memB0 = memA[15:13] <= dckS ? dockQ : 8'hFF;
wire[7:0] memB1 = memA[15:13] <= 0 ? extdQ : 8'hFF;

assign memQ 
    = memA[15:14] == 0 && mapped ? (ramcs ? dramQ : dromQ)
    : memM[memA[15:13]] ? (memB ? memB1 : memB0)
    : homeQ;
	 
//--- mist ----------------------------------------------------------------------------------------

//	wire[7:0] joy1;
//	wire[7:0] joy2;

	wire ps2kCk;
	wire ps2kD;

	wire sdcCs;
	wire sdcCk;
	wire sdcMosi;
	wire sdcMiso;

	wire       romE;
	wire       dckE;
	wire       tzxE;
	wire[26:0] dioA;
	wire[ 7:0] dioD;
	wire[31:0] dioS;
	wire       dioW;

//	wire[63:0] status;

	
//--- tzx -----------------------------------------------------------------------------------------

	reg[15:0] tzxSize;
	always @(posedge clock) if(tzxE) tzxSize <= dioS[15:0];

	wire[ 7:0] ramQ;
	ram #(256) ram(clock, tzxE ? dioA[17:0] : tzxA, dioD, ramQ, tzxE && dioW);

	wire[17:0] tzxA;
	wire tzxBusy;
	wire tzxTape;

	// MS parameter should be 56000 for PAL and 56488 for NTSC
	tzx #(56000) tzx
	(
		.clock  (clock  ),
		.ce     (1'b1   ),
		.a      (tzxA   ),
		.d      (ramQ   ),
		.play   (!play  ),
		.stop   (!stop  ),
		.busy   (tzxBusy),
		.size   (tzxSize),
		.tape   (tzxTape)
	);

//--- ts ------------------------------------------------------------------------------------------

	wire model = status[5];
	wire divmmc = status[6];

//wire reset = RESET | status[0] | buttons[1];
//wire reset = ~(RESET | power | !romE | !dckE | !status[0]);

//	wire reset = power && F9 && !romE && !dckE && !status[1];

//	wire nmi = (F5 && !status[2]) || mapped;

//	wire ear = tzxBusy ? tzxTape : ~tape;

	ts ts
	(
		.model  (model  ),
		.divmmc (divmmc ),
		.clock  (clock  ),
		.ne14M  (ne14M  ),
		.ne7M0  (ne7M0  ),
		.pe7M0  (pe7M0  ),
		.ne3M5  (ne3M5  ),
		.pe3M5  (pe3M5  ),
		.reset  (reset  ),
		.nmi    (nmi    ),
		.va     (va     ),
		.vd     (vd     ),
		.memA   (memA   ),
		.memD   (memD   ),
		.memQ   (memQ   ),
		.memB   (memB   ),
		.memM   (memM   ),
		.memW   (memW   ),
		.mapped (mapped ),
		.ramcs  (ramcs  ),
		.page   (page   ),
		.hsync  (HSync  ),
		.vsync  (VSync  ),
		.r      (r      ),
		.g      (g      ),
		.b      (b      ),
		.i      (i      ),
		.ear    (ear    ),
		.left   (left   ),
		.right  (right  ),
		.col    (col    ),
		.row    (row    ),
		.joy1   (joy1   ),
		.joy2   (joy2   ),
		.sdcCs  (sdcCs  ),
		.sdcCk  (sdcCk  ),
		.sdcMosi(sdcMosi),
		.sdcMiso(sdcMiso)
	);

//-------------------------------------------------------------------------------------------------

assign SDRAM_CLK = 1'b0;
assign SDRAM_CKE = 1'b0;
assign SDRAM_nCS = 1'b1;
assign SDRAM_nWE = 1'b1;
assign SDRAM_nRAS = 1'b1;
assign SDRAM_nCAS = 1'b1;

assign led = { sdcCs, ~ear, 1'b1};

assign CLK_VIDEO = clk_sys;
assign CE_PIXEL = ce_pix;

assign VGA_DE = ~(HBlank | VBlank);
assign VGA_HS = HSync;
assign VGA_VS = VSync;
//assign VGA_G  = (!col || col == 2) ? video : 8'd0;
//assign VGA_R  = (!col || col == 1) ? video : 8'd0;
//assign VGA_B  = (!col || col == 3) ? video : 8'd0;
// VGA = White if "video" is 1, else black
assign VGA_R = video ? 6'h3F : 6'h00; 
assign VGA_G = video ? 6'h3F : 6'h00; 
assign VGA_B = video ? 6'h3F : 6'h00; 




reg  [26:0] act_cnt;
always @(posedge clk_sys) act_cnt <= act_cnt + 1'd1; 
assign LED_USER    = act_cnt[26]  ? act_cnt[25:18]  > act_cnt[7:0]  : act_cnt[25:18]  <= act_cnt[7:0];

endmodule
