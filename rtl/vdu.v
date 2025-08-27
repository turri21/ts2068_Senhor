//-------------------------------------------------------------------------------------------------
module vdu
//-------------------------------------------------------------------------------------------------
(
	input  wire       model, // 0: PAL, 1: NTSC

	input  wire       clock,
	input  wire       ce14,
	input  wire       ce07,

	input  wire[ 2:0] border,
	input  wire[ 5:0] mode,
	output wire       irq,
	output wire[13:0] va,
	output wire       vc,
	input  wire[ 7:0] vd,

	output wire       hsync,
	output wire       vsync,
	output wire       r,
	output wire       g,
	output wire       b,
	output wire       i
);
//-------------------------------------------------------------------------------------------------

wire[9:0] hCountEnd = 10'd896;
wire[8:0] vCountEnd = model ? 9'd262 : 9'd312;

wire[8:0] vBlankBeg = model ? 9'd216 : 9'd248;
wire[8:0] vBlankEnd = model ? 9'd224 : 9'd256;

wire[8:0] vSyncBeg = model ? 9'd216 : 9'd248;
wire[8:0] vSyncEnd = model ? 9'd220 : 9'd252;

wire[8:0] irqBeg = 9'd0;
wire[8:0] irqEnd = 9'd64;

//-------------------------------------------------------------------------------------------------

reg[9:0] hCountHr;
wire hCountReset = hCountHr >= (hCountEnd-1);
always @(posedge clock) if(ce14) if(hCountReset) hCountHr <= 1'd0; else hCountHr <= hCountHr+1'd1;

reg[8:0] vCount;
wire vCountReset = vCount >= (vCountEnd-1);
always @(posedge clock) if(ce14) if(hCountReset) if(vCountReset) vCount <= 1'd0; else vCount <= vCount+1'd1;

reg[4:0] fCount;
always @(posedge clock) if(ce14) if(hCountReset) if(vCountReset) fCount <= fCount+1'd1;

//-------------------------------------------------------------------------------------------------

wire[8:0] hCount = hCountHr[9:1];
wire dataEnable = hCount < 256 && vCount < 192;

reg videoEnable;
wire videoEnableLoad = hCount[3];
always @(posedge clock) if(ce14) if(videoEnableLoad) videoEnable <= dataEnable;

//-------------------------------------------------------------------------------------------------

reg[7:0] dataInput;
wire dataInputLoad = (hCount[3:0] ==  9 || hCount[3:0] == 13) && dataEnable;
always @(posedge clock) if(ce14) if(dataInputLoad) dataInput <= vd;

reg[7:0] attrInput;
wire attrInputLoad = (hCount[3:0] == 11 || hCount[3:0] == 15) && dataEnable;
always @(posedge clock) if(ce14) if(attrInputLoad) attrInput <= vd;

//-------------------------------------------------------------------------------------------------

reg[7:0] dataOutput;
wire dataOutputLoad = hCount[2:0] == 4 && videoEnable;
always @(posedge clock) if(ce07) if(dataOutputLoad) dataOutput <= dataInput; else dataOutput <= { dataOutput[6:0], 1'b0 };

reg[7:0] attrOutput;
wire attrOutputLoad = hCount[2:0] == 4;
always @(posedge clock) if(ce07) if(attrOutputLoad) attrOutput <= { videoEnable ? attrInput[7:3] : { 2'b00, border }, attrInput[2:0] };

wire dataSelect = dataOutput[7] ^ (fCount[4] & attrOutput[7]);

//-------------------------------------------------------------------------------------------------

reg[15:0] dataOutputHr;
wire dataOutputHrLoad = hCount[2:0] == 4 && videoEnable;
always @(posedge clock) if(ce14) if(dataOutputHrLoad) dataOutputHr <= { dataInput, attrInput }; else dataOutputHr <= { dataOutputHr[14:0], 1'b0 };

wire dataSelectHr = dataOutputHr[15];

//-------------------------------------------------------------------------------------------------

wire hblank = hCount >= 320 && hCount < 416;
wire vblank = vCount >= vBlankBeg && vCount < vBlankEnd;

assign irq = !(vCount == 248 && hCount >= irqBeg && hCount < irqEnd);
assign va = {
	mode[1] ? hCount[1] : mode[0],
	!hCount[1] || mode[1] ? { vCount[7:6], vCount[2:0] } : { 3'b110, vCount[7:6] },
	vCount[5:3], hCount[7:4], hCount[2] };
assign vc = dataEnable && (hCount[3] || hCount[2]);

assign hsync = hCount >= 335 && hCount < 368;
assign vsync = vCount >= vSyncBeg && vCount < vSyncEnd;

assign r = hblank|vblank ? 1'b0 : mode[2] ? (dataSelectHr ~^ mode[4]) : dataSelect ? attrOutput[1] : attrOutput[4];
assign g = hblank|vblank ? 1'b0 : mode[2] ? (dataSelectHr ~^ mode[5]) : dataSelect ? attrOutput[2] : attrOutput[5];
assign b = hblank|vblank ? 1'b0 : mode[2] ? (dataSelectHr ~^ mode[3]) : dataSelect ? attrOutput[0] : attrOutput[3];
assign i = mode[2] | attrOutput[6];

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------



//-------------------------------------------------------------------------------------------------
module vduold
//-------------------------------------------------------------------------------------------------
(
	input  wire       model, // 0: PAL, 1: NTSC

	input  wire       clock,
	input  wire       ce,

	input  wire[ 2:0] border,
	input  wire[ 2:0] mode,
	output wire       irq,
	output wire[13:0] va,
	output wire       vc,
	input  wire[ 7:0] vd,

	output wire       hsync,
	output wire       vsync,
	output wire       r,
	output wire       g,
	output wire       b,
	output wire       i
);
//-------------------------------------------------------------------------------------------------

wire[8:0] hCountEnd = 9'd448;
wire[8:0] vCountEnd = model ? 9'd262 : 9'd312;

wire[8:0] vBlankBeg = model ? 9'd216 : 9'd248;
wire[8:0] vBlankEnd = model ? 9'd224 : 9'd256;

wire[8:0] vSyncBeg = model ? 9'd216 : 9'd248;
wire[8:0] vSyncEnd = model ? 9'd220 : 9'd252;

wire[8:0] irqBeg = 9'd0;
wire[8:0] irqEnd = 9'd64;

//-------------------------------------------------------------------------------------------------

reg[8:0] hCount;
wire hCountReset = hCount >= (hCountEnd-1);
always @(posedge clock) if(ce) if(hCountReset) hCount <= 1'd0; else hCount <= hCount+1'd1;

reg[8:0] vCount;
wire vCountReset = vCount >= (vCountEnd-1);
always @(posedge clock) if(ce) if(hCountReset) if(vCountReset) vCount <= 1'd0; else vCount <= vCount+1'd1;

reg[4:0] fCount;
always @(posedge clock) if(ce) if(hCountReset) if(vCountReset) fCount <= fCount+1'd1;

//-------------------------------------------------------------------------------------------------

wire dataEnable = hCount <= 255 && vCount <= 191;

reg videoEnable;
wire videoEnableLoad = hCount[3];
always @(posedge clock) if(ce) if(videoEnableLoad) videoEnable <= dataEnable;

//-------------------------------------------------------------------------------------------------

reg[7:0] dataInput;
wire dataInputLoad = (hCount[3:0] ==  9 || hCount[3:0] == 13) && dataEnable;
always @(posedge clock) if(ce) if(dataInputLoad) dataInput <= vd;

reg[7:0] attrInput;
wire attrInputLoad = (hCount[3:0] == 11 || hCount[3:0] == 15) && dataEnable;
always @(posedge clock) if(ce) if(attrInputLoad) attrInput <= vd;

reg[7:0] dataOutput;
wire dataOutputLoad = hCount[2:0] == 4 && videoEnable;
always @(posedge clock) if(ce) if(dataOutputLoad) dataOutput <= dataInput; else dataOutput <= { dataOutput[6:0], 1'b0 };

reg[7:0] attrOutput;
wire attrOutputLoad = hCount[2:0] == 4;
always @(posedge clock) if(ce) if(attrOutputLoad) attrOutput <= { videoEnable ? attrInput[7:3] : { 2'b00, border }, attrInput[2:0] };

wire dataSelect = dataOutput[7] ^ (fCount[4] & attrOutput[7]);

wire hblank = hCount >= 320 && hCount < 416;
wire vblank = vCount >= vBlankBeg && vCount < vBlankEnd;

//-------------------------------------------------------------------------------------------------

assign irq = !(vCount == 248 && hCount >= irqBeg && hCount < irqEnd);
assign va = {
	mode[1] ? hCount[1] : mode[0],
	!hCount[1] || mode[1] ? { vCount[7:6], vCount[2:0] } : { 3'b110, vCount[7:6] },
	vCount[5:3], hCount[7:4], hCount[2] };
assign vc = dataEnable && (hCount[3] || hCount[2]);

assign hsync = hCount >= 344 && hCount < 376; // 335...367
assign vsync = vCount >= vSyncBeg && vCount < vSyncEnd;

assign r = hblank|vblank ? 1'b0 : dataSelect ? attrOutput[1] : attrOutput[4];
assign g = hblank|vblank ? 1'b0 : dataSelect ? attrOutput[2] : attrOutput[5];
assign b = hblank|vblank ? 1'b0 : dataSelect ? attrOutput[0] : attrOutput[3];
assign i = attrOutput[6];

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
