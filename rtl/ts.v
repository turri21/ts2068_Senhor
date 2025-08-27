//-------------------------------------------------------------------------------------------------
module ts
//-------------------------------------------------------------------------------------------------
(
	input  wire       model,
	input  wire       divmmc,

	input  wire       clock,
	input  wire       ne14M,
	input  wire       ne7M0,
	input  wire       pe7M0,
	input  wire       ne3M5,
	input  wire       pe3M5,

	input  wire       reset,
	input  wire       nmi,

	output wire[13:0] va,
	input  wire[ 7:0] vd,

	output wire[15:0] memA,
	output wire[ 7:0] memD,
	input  wire[ 7:0] memQ,
	output wire       memB,
	output wire[ 7:0] memM,
	output wire       memW,

	output wire       mapped,
	output wire       ramcs,
	output wire[ 3:0] page,

	output wire       hsync,
	output wire       vsync,
	output wire       r,
	output wire       g,
	output wire       b,
	output wire       i,

	input  wire       ear,
	output wire[14:0] left,
	output wire[14:0] right,

	input  wire[ 4:0] col,
	output wire[ 7:0] row,

	input  wire[ 7:0] joy1,
	input  wire[ 7:0] joy2,

	output wire       sdcCs,
	output wire       sdcCk,
	output wire       sdcMosi,
	input  wire       sdcMiso
);
//--- io ------------------------------------------------------------------------------------------

	wire iorqEB = !iorq && a[7:0] == 8'hEB;
	wire iorqF4 = !iorq && a[7:0] == 8'hF4;
	wire iorqF5 = !iorq && a[7:0] == 8'hF5;
	wire iorqF6 = !iorq && a[7:0] == 8'hF6;
	wire iorqFE = !iorq && a[7:0] == 8'hFE;
	wire iorqFF = !iorq && a[7:0] == 8'hFF;

	reg[7:0] dataF4;
	always @(posedge clock) if(pe7M0) if(iorqF4 && !wr) dataF4 <= q;

	reg[4:0] dataFE;
	always @(posedge clock) if(pe7M0) if(iorqFE && !wr) dataFE <= q[4:0];

	reg[7:0] dataFF;
	always @(posedge clock) if(pe7M0) if(iorqFF && !wr) dataFF <= q;

//--- video ---------------------------------------------------------------------------------------

	wire vc;

	vdu vdu
	(
		model,
		clock,
		ne14M,
		ne7M0,
		dataFE[2:0],
		dataFF[5:0],
		irq,
		va,
		vc,
		vd,
		hsync,
		vsync,
		r,
		g,
		b,
		i
	);

//--- psg -----------------------------------------------------------------------------------------

	wire bdir = (iorqF5 && !wr) || (iorqF6 && !wr);
	wire bc1 = (iorqF5 && !wr) || (iorqF6 && !rd);

	wire[7:0] joy =
		(a[8] ? ~{ joy1[4], 3'b000, joy1[0], joy1[1], joy1[2], joy1[3] } : 8'hFF)&
		(a[9] ? ~{ joy2[4], 3'b000, joy2[0], joy2[1], joy2[2], joy2[3] } : 8'hFF);
	wire[7:0] psgQ;

	wire[11:0] psgA;
	wire[11:0] psgB;
	wire[11:0] psgC;

	psg psg
	(
		.clock  (clock  ),
		.sel    (1'b0   ),
		.ce     (pe3M5  ),
		.reset  (reset  ),
		.bdir   (bdir   ),
		.bc1    (bc1    ),
		.d      (q      ),
		.q      (psgQ   ),
		.a      (psgA   ),
		.b      (psgB   ),
		.c      (psgC   ),
		.io     (joy    )
	);

//--- contention ----------------------------------------------------------------------------------

	reg mreqt23iorqtw3;
	always @(posedge clock) if(pc3M5) mreqt23iorqtw3 <= mreq && !iorqFE;

	reg clk35;
	always @(posedge clock) if(ne7M0) clk35 <= !(clk35 && !contend);

	wire contend = clk35 && vc && mreqt23iorqtw3 && ((!a[15] && a[14]) || iorqFE);

//--- divmmc --------------------------------------------------------------------------------------

	mapper mapper
	(
		.enable (divmmc ),
		.clock  (clock  ),
		.ce     (pc3M5  ),
		.mapped (mapped ),
		.ramcs  (ramcs  ),
		.page   (page   ),
		.reset  (reset  ),
		.iorq   (iorq   ),
		.mreq   (mreq   ),
		.m1     (m1     ),
		.wr     (wr     ),
		.a      (a      ),
		.d      (q      )
	);

	wire[7:0] sdcQ;

	sdc sdc
	(
		.enable (divmmc ),
		.clock  (clock  ),
		.ce     (pe3M5  ),
		.cen    (ne7M0  ),
		.cep    (pe7M0  ),
		.reset  (reset  ),
		.iorq   (iorq   ),
		.rd     (rd     ),
		.wr     (wr     ),
		.a      (a[7:0] ),
		.d      (q      ),
		.q      (sdcQ   ),
		.cs     (sdcCs  ),
		.ck     (sdcCk  ),
		.mosi   (sdcMosi),
		.miso   (sdcMiso)
	);

//--- memory --------------------------------------------------------------------------------------

	assign memA = a;
	assign memD = q;
	assign memB = dataFF[7];
	assign memM = dataF4;
	assign memW = !mreq && !wr;

//--- cpu -----------------------------------------------------------------------------------------

	wire nc3M5 = ne3M5 && !contend;
	wire pc3M5 = pe3M5 && !contend;

	wire iorq;
	wire mreq;
	wire rfsh;
	wire irq;
	wire m1;
	wire rd;
	wire wr;

	wire[15:0] a;
	wire[ 7:0] d
		= !mreq ? memQ
		: !iorq && !a[5] ? joy1
		: iorqEB ? sdcQ
		: iorqF4 ? dataF4
		: iorqF6 ? psgQ
		: iorqFE ? { 1'b1, ear, 1'b1, col }
		: iorqFF ? dataFF
		: 8'hFF;
	wire[ 7:0] q;

	cpu cpu
	(
		.clock  (clock  ),
		.ne     (nc3M5  ),
		.pe     (pc3M5  ),
		.reset  (reset  ),
		.iorq   (iorq   ),
		.mreq   (mreq   ),
		.rfsh   (rfsh   ),
		.irq    (irq    ),
		.nmi    (nmi    ),
		.m1     (m1     ),
		.rd     (rd     ),
		.wr     (wr     ),
		.a      (a      ),
		.d      (d      ),
		.q      (q      )
	);

//-------------------------------------------------------------------------------------------------

	wire[11:0] sound = dataFE[4:3] == 3 ? 12'd4095 : dataFE[4:3] == 2 ? 12'd3874 : dataFE[4:3] == 1 ? 12'd775 : 12'd0;

	assign left  = { 3'd0, sound }+{ 2'd0, psgA, 1'd0 }+{ 3'd0, psgB };
	assign right = { 3'd0, sound }+{ 2'd0, psgC, 1'd0 }+{ 3'd0, psgB };

	assign row = a[15:8];

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
