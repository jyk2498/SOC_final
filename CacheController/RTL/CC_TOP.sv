module CC_TOP
(
    input   wire        clk,
    input   wire        rst_n,

    // AMBA APB interface
    input   wire                psel_i,
    input   wire                penable_i,
    input   wire    [11:0]      paddr_i,
    input   wire                pwrite_i,
    input   wire    [31:0]      pwdata_i,
    output  reg                 pready_o,
    output  reg     [31:0]      prdata_o,
    output  reg                 pslverr_o,

    // AMBA AXI interface between INCT and CC (AR channel)
    input   wire    [3:0]       inct_arid_i,
    input   wire    [31:0]      inct_araddr_i,
    input   wire    [3:0]       inct_arlen_i,
    input   wire    [2:0]       inct_arsize_i,
    input   wire    [1:0]       inct_arburst_i,
    input   wire                inct_arvalid_i,
    output  wire                inct_arready_o,
    
    // AMBA AXI interface between INCT and CC  (R channel)
    output  wire    [3:0]       inct_rid_o,
    output  wire    [63:0]      inct_rdata_o,
    output  wire    [1:0]       inct_rresp_o,
    output  wire                inct_rlast_o,
    output  wire                inct_rvalid_o,
    input   wire                inct_rready_i,

    // AMBA AXI interface between memory and CC (AR channel)
    output  wire    [3:0]       mem_arid_o,
    output  wire    [31:0]      mem_araddr_o,
    output  wire    [3:0]       mem_arlen_o,
    output  wire    [2:0]       mem_arsize_o,
    output  wire    [1:0]       mem_arburst_o,
    output  wire                mem_arvalid_o,
    input   wire                mem_arready_i,

    // AMBA AXI interface between memory and CC  (R channel)
    input   wire    [3:0]       mem_rid_i,
    input   wire    [63:0]      mem_rdata_i,
    input   wire    [1:0]       mem_rresp_i,
    input   wire                mem_rlast_i,
    input   wire                mem_rvalid_i,
    output  wire                mem_rready_o,    

    // SRAM read port interface
    output  wire                rden_o,
    output  wire    [8:0]       raddr_o,
    input   wire    [17:0]      rdata_tag_i,
    input   wire    [511:0]     rdata_data_i,

    // SRAM write port interface
    output  wire                wren_o,
    output  wire    [8:0]       waddr_o,
    output  wire    [17:0]      wdata_tag_o,
    output  wire    [511:0]     wdata_data_o    
);

    // You can modify the code in the module block.

    CC_CFG u_cfg(
        .clk            (clk),
        .rst_n          (rst_n),
        .psel_i         (psel_i),
        .penable_i      (penable_i),
        .paddr_i        (paddr_i),
        .pwrite_i       (pwrite_i),
        .pwdata_i       (pwdata_i),
        .pready_o       (pready_o),
        .prdata_o       (prdata_o),
        .pslverr_o      (pslverr_o)
    );

    wire [16 : 0]       decoder_tag_w;
    wire [8 : 0]        decoder_index_w;
    wire [5 : 0]        decoder_offset_w;
    wire                decoder_hs_pulse_w;

    wire                miss_addr_fifo_afull_w;
    wire                miss_req_fifo_afull_w;
    wire                hit_flag_fifo_afull_w;
    wire                hit_data_fifo_afull_w;

    CC_DECODER u_decoder(
        .inct_araddr_i          (inct_araddr_i),
        .inct_arvalid_i         (inct_arvalid_i),
        .inct_arready_o         (inct_arready_o),
        .miss_addr_fifo_afull_i (miss_addr_fifo_afull_w),
        .miss_req_fifo_afull_i  (miss_req_fifo_afull_w),
        .hit_flag_fifo_afull_i  (hit_flag_fifo_afull_w),
        .hit_data_fifo_afull_i  (hit_data_fifo_afull_w),
        .tag_o                  (decoder_tag_w),
        .index_o                (decoder_index_w),
        .offset_o               (decoder_offset_w),
        .hs_pulse_o             (decoder_hs_pulse_w)
    );

    wire [16 : 0]       comparator_tag_delayed_w;
    wire [8 : 0]        comparator_index_delayed_w;
    wire [5 : 0]        comparator_offset_delayed_w;
    wire                comparator_hs_pulse_delayed_w;
    wire                comparator_hit_w;
    wire                comparator_miss_w;
    
    CC_TAG_COMPARATOR u_tag_comparator(
        .clk                    (clk),
        .rst_n                  (rst_n),
        .tag_i                  (decoder_tag_w),
        .index_i                (decoder_index_w),
        .offset_i               (decoder_offset_w),
        .tag_delayed_o          (comparator_tag_delayed_w),
        .index_delayed_o        (comparator_index_delayed_w),
        .offset_delayed_o       (comparator_offset_delayed_w),
        .hs_pulse_delayed_o     (comparator_hs_pulse_delayed_w),
        .hs_pulse_i             (decoder_hs_pulse_w),
        .rdata_tag_i            (rdata_tag_i),
        .hit_o                  (comparator_hit_w),
        .miss_o                 (comparator_miss_w)
    );

    wire            miss_req_fifo_aempty_w;
    wire [31 : 0]   miss_req_fifo_rdata_w;

    CC_FIFO #(.FIFO_DEPTH(16), .DATA_WIDTH(32), .AFULL_THRESHOLD(12)) u_miss_req_fifo(
        .clk                    (clk),
        .rst_n                  (rst_n),
        .full_o                 (),
        .afull_o                (miss_req_fifo_afull_w), 
        .wren_i                 (comparator_hs_pulse_delayed_w & comparator_miss_w), 
        .wdata_i                ({comparator_tag_delayed_w, comparator_index_delayed_w, comparator_offset_delayed_w}), 
        .empty_o                (), 
        .aempty_o               (miss_req_fifo_aempty_w),
        .rden_i                 (mem_arready_i & mem_arvalid_o), 
        .rdata_o                (miss_req_fifo_rdata_w) 
    );

    wire miss_addr_fifo_aempty_w;
    wire miss_addr_fifo_rden_w;
    wire [31 : 0] miss_addr_fifo_rdata_w;
    CC_FIFO #(.FIFO_DEPTH(16), .DATA_WIDTH(32), .AFULL_THRESHOLD(12)) u_miss_addr_fifo(
        .clk                    (clk),
        .rst_n                  (rst_n),
        .full_o                 (),
        .afull_o                (miss_addr_fifo_afull_w), 
        .wren_i                 (comparator_hs_pulse_delayed_w & comparator_miss_w), 
        .wdata_i                ({comparator_tag_delayed_w, comparator_index_delayed_w, comparator_offset_delayed_w}), 
        .empty_o                (), 
        .aempty_o               (miss_addr_fifo_aempty_w),
        .rden_i                 (miss_addr_fifo_rden_w), 
        .rdata_o                (miss_addr_fifo_rdata_w)
    );

    wire reorder_mem_rready_w;
    CC_DATA_REORDER_UNIT    u_data_reorder_unit(
        .clk                        (clk),   
        .rst_n                      (rst_n), 
        .mem_rdata_i                (mem_rdata_i), 
        .mem_rlast_i                (mem_rlast_i), 
        .mem_rvalid_i               (mem_rvalid_i), 
        .mem_rready_o               (reorder_mem_rready_w), 
        .hit_flag_fifo_afull_o      (hit_flag_fifo_afull_w), 
        .hit_flag_fifo_wren_i       (comparator_hit_w | comparator_miss_w), 
        .hit_flag_fifo_wdata_i      (comparator_hit_w), 
        .hit_data_fifo_afull_o      (hit_data_fifo_afull_w), 
        .hit_data_fifo_wren_i       (comparator_hit_w), 
        .hit_data_fifo_wdata_i      ({comparator_offset_delayed_w, rdata_data_i}), 
        .inct_rdata_o               (inct_rdata_o), 
        .inct_rlast_o               (inct_rlast_o), 
        .inct_rvalid_o              (inct_rvalid_o), 
        .inct_rready_i              (inct_rready_i)
    );

    CC_DATA_FILL_UNIT       u_data_fill_unit(
        .clk                        (clk),
        .rst_n                      (rst_n),
        .mem_rdata_i                (mem_rdata_i), 
        .mem_rlast_i                (mem_rlast_i), 
        .mem_rvalid_i               (mem_rvalid_i), 
        .mem_rready_i               (reorder_mem_rready_w),
        .miss_addr_fifo_empty_i     (miss_addr_fifo_aempty_w), 
        .miss_addr_fifo_rdata_i     (miss_addr_fifo_rdata_w), 
        .miss_addr_fifo_rden_o      (miss_addr_fifo_rden_w), 
        .wren_o                     (wren_o), 
        .waddr_o                    (waddr_o), 
        .wdata_tag_o                (wdata_tag_o),    
        .wdata_data_o               (wdata_data_o)
    );

    //AXI assign
    assign inct_rresp_o     = 2'b00;
    assign inct_rvalid_o    = 4'b0000;

    assign mem_arid_o       = 4'b0000;
    assign mem_araddr_o     = miss_req_fifo_rdata_w;
    assign mem_arlen_o      = 4'b0111;
    assign mem_arsize_o     = 3'b011;
    assign mem_arburst_o    = 2'b10;
    assign mem_rready_o     = reorder_mem_rready_w;
    assign mem_arvalid_o    = !miss_req_fifo_aempty_w;

    assign rden_o           = decoder_hs_pulse_w;
    assign raddr_o          = decoder_index_w;
endmodule