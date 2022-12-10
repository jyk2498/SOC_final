// Copyright (c) 2022 Sungkyunkwan University

module CC_DATA_REORDER_UNIT
(
    input   wire            clk,
    input   wire            rst_n,
	
    // AMBA AXI interface between MEM and CC (R channel)
    input   wire    [63:0]  mem_rdata_i,
    input   wire            mem_rlast_i,
    input   wire            mem_rvalid_i,
    output  wire            mem_rready_o,    

    // Hit Flag FIFO write interface
    output  wire            hit_flag_fifo_afull_o,
    input   wire            hit_flag_fifo_wren_i,
    input   wire            hit_flag_fifo_wdata_i,

    // Hit data FIFO write interface
    output  wire            hit_data_fifo_afull_o,
    input   wire            hit_data_fifo_wren_i,
    input   wire    [517:0] hit_data_fifo_wdata_i,

	// AMBA AXI interface between INCT and CC (R channel)
    output  wire    [63:0]  inct_rdata_o,
    output  wire            inct_rlast_o,
    output  wire            inct_rvalid_o,
    input   wire            inct_rready_i
);

    // Fill the code here
    // ==================== HIT FLAG FIFO ====================
    wire hit_flag_fifo_afull_w;
    wire hit_flag_fifo_aempty_w;
    wire hit_flag_fifo_rden_w;

    wire hit_flag_fifo_rdata_w;
    CC_FIFO 
    #(
        .FIFO_DEPTH(16),
        .DATA_WIDTH(1),
        .AFULL_THRESHOLD(15),
        .AEMPTY_THRESHOLD()
    ) HIT_FLAG_FIFO (
        .clk(clk),
        .rst_n(rst_n),

        .full_o(),
        .afull_o(hit_flag_fifo_afull_w),
        .wren_i(hit_flag_fifo_wren_i),
        .wdata_i(hit_flag_fifo_wdata_i),

        .empty_o(),
        .aempty_o(hit_flag_fifo_aempty_w),
        .rden_i(hit_flag_fifo_rden_w),
        .rdata_o(hit_flag_fifo_rdata_w)
    );
    // ==================== HIT DATA FIFO ====================
    wire           hit_data_fifo_afull_w;
    wire           hit_data_fifo_aempty_w;

    wire           hit_data_fifo_rden_w;
    wire [517 : 0] hit_data_fifo_rdata_w;
    CC_FIFO 
    #(
        .FIFO_DEPTH(16),
        .DATA_WIDTH(518),
        .AFULL_THRESHOLD(15),
        .AEMPTY_THRESHOLD()
    ) HIT_DATA_FIFO (
        .clk(clk),
        .rst_n(rst_n),

        .full_o(),
        .afull_o(hit_data_fifo_afull_w),
        .wren_i(hit_data_fifo_wren_i),
        .wdata_i(hit_data_fifo_wdata_i),

        .empty_o(),
        .aempty_o(hit_data_fifo_aempty_w),
        .rden_i(hit_data_fifo_rden_w),
        .rdata_o(hit_data_fifo_rdata_w)
    );
    // ==================== SERIALIZER ====================
    wire [63 : 0]   serial_rdata_w;
    wire            serial_rlast_w;
    wire            serial_rvalid_w; 
    
    CC_SERIALIZER SERIALIZER_inst0 (
        .clk(clk),
        .rst_n(rst_n),

        .fifo_empty_i(),
        .fifo_aempty_i(hit_data_fifo_aempty_w),
        .fifo_rdata_i(hit_data_fifo_rdata_w),
        .fifo_rden_o(hit_data_fifo_rden_w),

        .rdata_o(serial_rdata_w),
        .rlast_o(serial_rlast_w),
        .rvalid_o(serial_rvalid_w),
        .rready_i(!hit_flag_fifo_aempty_w & hit_flag_fifo_rdata_w & inct_rready_i)
    );

    //output assignment
    assign hit_flag_fifo_afull_o = hit_flag_fifo_afull_w;
    assign hit_data_fifo_afull_o = hit_data_fifo_afull_w;

    assign mem_rready_o     = !hit_flag_fifo_aempty_w & !hit_flag_fifo_rdata_w & inct_rready_i;

    reg [63 : 0]    inct_rdata;
    reg             inct_rlast;
    reg             inct_rvalid;

    always_comb begin
        inct_rlast  = 1'b0;
        inct_rvalid = 1'b0;
        inct_rdata  = 64'd0;

/*
        if(hit_flag_fifo_rdata_w & !hit_flag_fifo_aempty_w) begin
            inct_rdata = serial_rdata_w;
        end else if(!hit_flag_fifo_rdata_w & !hit_data_fifo_aempty_w) begin
            inct_rdata = mem_rdata_i;
        end
        */

        if(!hit_flag_fifo_aempty_w) begin
            if(hit_flag_fifo_rdata_w) begin
                inct_rlast  = serial_rlast_w;
                inct_rvalid = serial_rvalid_w;
                inct_rdata  = serial_rdata_w;
            end else begin
                inct_rlast  = mem_rlast_i;
                inct_rvalid = mem_rvalid_i; 
                inct_rdata  = mem_rdata_i;
            end
        end
    end

    assign inct_rdata_o     = inct_rdata;
    assign inct_rlast_o     = inct_rlast;
    assign inct_rvalid_o    = inct_rvalid;

    assign hit_flag_fifo_rden_w = inct_rlast & inct_rvalid & inct_rready_i & !hit_flag_fifo_aempty_w;

endmodule