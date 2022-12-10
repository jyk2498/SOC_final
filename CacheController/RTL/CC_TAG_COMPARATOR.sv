// Copyright (c) 2022 Sungkyunkwan University

module CC_TAG_COMPARATOR
(
	input	wire			clk,
	input	wire			rst_n,

	input	wire	[16:0]	tag_i,
	input	wire	[8:0]	index_i,
	input   wire	[5:0]	offset_i,
	output	wire	[16:0]	tag_delayed_o,
	output	wire	[8:0]	index_delayed_o,
	output	wire	[5:0]	offset_delayed_o,
	output 	wire			hs_pulse_delayed_o,

	input	wire			hs_pulse_i,

	input	wire	[17:0]	rdata_tag_i,

	output	wire			hit_o,
	output	wire			miss_o

);

	// Fill the code here
	reg [16 : 0]		tag_d;
	reg [8 : 0]			index_d;
	reg [5 : 0]			offset_d;
	reg					hs_pulse_d;

	reg					hit;
	reg					miss;

	always_ff@(posedge clk) begin
		if(!rst_n) begin
			tag_d 		<= 17'd0;
			index_d		<= 9'd0;
			offset_d	<= 6'd0;
			hs_pulse_d	<= 1'b0;
		end else begin
			tag_d		<= tag_i;
			index_d		<= index_i;
			offset_d	<= offset_i;
			hs_pulse_d	<= hs_pulse_i;
		end
	end

	always_comb begin
		hit		= 1'b0;
		miss	= 1'b0;

		if(hs_pulse_d) begin
			if(rdata_tag_i[17] && (rdata_tag_i[16 : 0] == tag_d)) begin // notice Valid bit
				hit = 1'b1;
			end else begin
				miss = 1'b1;
			end
		end
	end

	// assign output
	assign tag_delayed_o 			= tag_d;
	assign index_delayed_o			= index_d;
	assign offset_delayed_o			= offset_d;
	assign hs_pulse_delayed_o		= hs_pulse_d;
	assign hit_o					= hit;
	assign miss_o					= miss;
endmodule
