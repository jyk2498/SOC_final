// Copyright (c) 2022 Sungkyunkwan University

module CC_SERIALIZER
(
	input	wire				clk,
	input	wire				rst_n,

	input	wire				fifo_empty_i,
	input	wire				fifo_aempty_i,
	input	wire	[517:0]		fifo_rdata_i,
	output	wire				fifo_rden_o,

    output  wire    [63:0]		rdata_o,
    output  wire            	rlast_o,
    output  wire            	rvalid_o,
    input   wire            	rready_i
);

	reg [63 : 0]	rdata;
	reg				rlast;

	reg [2 : 0]		cnt, cnt_n;
	// Fill the code here
	always_ff@(posedge clk) begin
		if(!rst_n) begin
			cnt <= 3'b000;
		end else begin
			cnt <= cnt_n;
		end
	end

	wire [2 : 0] cntaddCoffset;
	assign cntaddCoffset = cnt + fifo_rdata_i[517 : 515];
	always_comb begin
		cnt_n	= 3'b000;
		rdata   = 64'd0;
		rlast	= 1'b0;

		if(rready_i & rvalid_o) begin
			cnt_n = cnt + 1;	
		end

        case(cntaddCoffset)
			3'b000 : begin
				rdata = fifo_rdata_i[511 : 448];
			end
			3'b001 : begin
				rdata = fifo_rdata_i[447 : 384];
			end
			3'b010 : begin
				rdata = fifo_rdata_i[383 : 320];
			end
			3'b011 : begin
				rdata = fifo_rdata_i[319 : 256];
			end
			3'b100 : begin
				rdata = fifo_rdata_i[255 : 192];
			end
			3'b101 : begin
				rdata = fifo_rdata_i[191 : 128];
			end
			3'b110 : begin
				rdata = fifo_rdata_i[127 : 64];
			end
			3'b111 : begin
				rdata = fifo_rdata_i[63 : 0];
			end
        endcase

		if(cnt == 3'b111) begin
			rlast = 1'b1;
		end
	end

	assign rvalid_o 	= (!fifo_aempty_i);
	assign rdata_o		= rdata;
	assign rlast_o		= rlast;
	assign fifo_rden_o 	= rlast;
endmodule
