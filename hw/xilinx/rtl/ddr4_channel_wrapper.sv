// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description: This module is a wrapper for a single DDR4 channel.
//              It includes :
//                 - A clock converter to increase the frequency to 300 MHz
//                 - A datawidth converter to increase the datawidth to 512 bit
//                 - A DDR4 (MIG) IP
//
//              It has the following sub-architecture
//
//
//             _______________            ADDR: XELN    ____________  ADDR: XLEN       ADDR: 34 bit    ____________
//   250 MHz  |     Clock     | 300 MHz   DATA: XLEN   |   Dwidth   | DATA: 512 bit    DATA: 512 bit  |            |
// ---------> |   Converter   |----------------------->| Converter  |-------------------------------->| DDR4 (MIG) |
//            |_______________|                        |____________|                                 |____________|
//


`include "uninasoc_pcie.svh"
`include "uninasoc_ddr4.svh"

module ddr4_channel_wrapper # (
    parameter int unsigned    LOCAL_DATA_WIDTH  = 32,
    parameter int unsigned    LOCAL_ADDR_WIDTH  = 32,
    parameter int unsigned    LOCAL_ID_WIDTH    = 32
) (
    // SoC clock and reset
    input logic clock_i,
    input logic reset_ni,

    // DDR4 CH0 clock and reset
    input logic clk_300mhz_0_p_i,
    input logic clk_300mhz_0_n_i,

    // DDR4 channel interface (to PHYs)
    `DEFINE_DDR4_PORTS(x),

    // AXI-lite CSR interface
    `DEFINE_AXILITE_SLAVE_PORTS(s_ctrl, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH),

    // AXI4 Slave interface
    `DEFINE_AXI_SLAVE_PORTS(s, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)

);

    // DDR4 local parameters
    localparam DDR4_CHANNEL_ADDRESS_WIDTH = 34;
    localparam DDR4_CHANNEL_DATA_WIDTH = 512;

    // DDR4 sys reset - it is active high
    logic ddr4_reset = 1'b1;

    always @(posedge clock_i or negedge reset_ni) begin
        if (reset_ni == 1'b0) begin
            ddr4_reset <= 1'b1;
        end else begin
            ddr4_reset <= 1'b0;
        end
    end

    // DDR4 output clk and rst
    logic ddr_clk;
    logic ddr_rst;

    // DDR4 34-bits address signals
    logic [DDR4_CHANNEL_ADDRESS_WIDTH-1:0] ddr4_axi_awaddr;
    logic [DDR4_CHANNEL_ADDRESS_WIDTH-1:0] ddr4_axi_araddr;

    // AXI bus from the clock converter to the dwidth converter
    `DECLARE_AXI_BUS(clk_conv_to_dwidth_conv, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)

    // AXI bus from the dwidth converter to the cache
    `DECLARE_AXI_BUS(dwidth_conv_to_cache, DDR4_CHANNEL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)

    // AXI bus from the cache to the DDR4
    `DECLARE_AXI_BUS(cache_to_ddr4, DDR4_CHANNEL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)

    // Dwidth converter master ID signals assigned to 0
    // Since the AXI data width converter has a reordering depth of 1 it doesn't have ID in its master ports - for more details see the documentation
    // Thus, we assign 0 to all these signals that go to the DDR MIG
    assign dwidth_conv_to_ddr4_axi_awid = '0;
    //assign dwidth_conv_to_ddr4_axi_bid  = '0;
    assign dwidth_conv_to_ddr4_axi_arid = '0;

    // AXI Clock converter from 250 MHz (xdma global design clk) to 300 MHz (AXI user interface DDR clk) - the data width is XLEN
    axi_clock_converter_wrapper # (
        .LOCAL_DATA_WIDTH   ( LOCAL_DATA_WIDTH ),
        .LOCAL_ADDR_WIDTH   ( LOCAL_ADDR_WIDTH ),
        .LOCAL_ID_WIDTH     ( LOCAL_ID_WIDTH   )
    ) axi_clk_conv_u (

        .s_axi_aclk     ( clock_i        ),
        .s_axi_aresetn  ( reset_ni       ),

        .m_axi_aclk     ( ddr_clk        ),
        .m_axi_aresetn  ( ~ddr_rst       ),

        .s_axi_awid     ( s_axi_awid     ),
        .s_axi_awaddr   ( s_axi_awaddr   ),
        .s_axi_awlen    ( s_axi_awlen    ),
        .s_axi_awsize   ( s_axi_awsize   ),
        .s_axi_awburst  ( s_axi_awburst  ),
        .s_axi_awlock   ( s_axi_awlock   ),
        .s_axi_awcache  ( s_axi_awcache  ),
        .s_axi_awprot   ( s_axi_awprot   ),
        .s_axi_awqos    ( s_axi_awqos    ),
        .s_axi_awvalid  ( s_axi_awvalid  ),
        .s_axi_awready  ( s_axi_awready  ),
        .s_axi_awregion ( s_axi_awregion ),
        .s_axi_wdata    ( s_axi_wdata    ),
        .s_axi_wstrb    ( s_axi_wstrb    ),
        .s_axi_wlast    ( s_axi_wlast    ),
        .s_axi_wvalid   ( s_axi_wvalid   ),
        .s_axi_wready   ( s_axi_wready   ),
        .s_axi_bid      ( s_axi_bid      ),
        .s_axi_bresp    ( s_axi_bresp    ),
        .s_axi_bvalid   ( s_axi_bvalid   ),
        .s_axi_bready   ( s_axi_bready   ),
        .s_axi_arid     ( s_axi_arid     ),
        .s_axi_araddr   ( s_axi_araddr   ),
        .s_axi_arlen    ( s_axi_arlen    ),
        .s_axi_arsize   ( s_axi_arsize   ),
        .s_axi_arburst  ( s_axi_arburst  ),
        .s_axi_arlock   ( s_axi_arlock   ),
        .s_axi_arregion ( s_axi_arregion ),
        .s_axi_arcache  ( s_axi_arcache  ),
        .s_axi_arprot   ( s_axi_arprot   ),
        .s_axi_arqos    ( s_axi_arqos    ),
        .s_axi_arvalid  ( s_axi_arvalid  ),
        .s_axi_arready  ( s_axi_arready  ),
        .s_axi_rid      ( s_axi_rid      ),
        .s_axi_rdata    ( s_axi_rdata    ),
        .s_axi_rresp    ( s_axi_rresp    ),
        .s_axi_rlast    ( s_axi_rlast    ),
        .s_axi_rvalid   ( s_axi_rvalid   ),
        .s_axi_rready   ( s_axi_rready   ),

        .m_axi_awid     ( clk_conv_to_dwidth_conv_axi_awid      ),
        .m_axi_awaddr   ( clk_conv_to_dwidth_conv_axi_awaddr    ),
        .m_axi_awlen    ( clk_conv_to_dwidth_conv_axi_awlen     ),
        .m_axi_awsize   ( clk_conv_to_dwidth_conv_axi_awsize    ),
        .m_axi_awburst  ( clk_conv_to_dwidth_conv_axi_awburst   ),
        .m_axi_awlock   ( clk_conv_to_dwidth_conv_axi_awlock    ),
        .m_axi_awcache  ( clk_conv_to_dwidth_conv_axi_awcache   ),
        .m_axi_awprot   ( clk_conv_to_dwidth_conv_axi_awprot    ),
        .m_axi_awregion ( clk_conv_to_dwidth_conv_axi_awregion  ),
        .m_axi_awqos    ( clk_conv_to_dwidth_conv_axi_awqos     ),
        .m_axi_awvalid  ( clk_conv_to_dwidth_conv_axi_awvalid   ),
        .m_axi_awready  ( clk_conv_to_dwidth_conv_axi_awready   ),
        .m_axi_wdata    ( clk_conv_to_dwidth_conv_axi_wdata     ),
        .m_axi_wstrb    ( clk_conv_to_dwidth_conv_axi_wstrb     ),
        .m_axi_wlast    ( clk_conv_to_dwidth_conv_axi_wlast     ),
        .m_axi_wvalid   ( clk_conv_to_dwidth_conv_axi_wvalid    ),
        .m_axi_wready   ( clk_conv_to_dwidth_conv_axi_wready    ),
        .m_axi_bid      ( clk_conv_to_dwidth_conv_axi_bid       ),
        .m_axi_bresp    ( clk_conv_to_dwidth_conv_axi_bresp     ),
        .m_axi_bvalid   ( clk_conv_to_dwidth_conv_axi_bvalid    ),
        .m_axi_bready   ( clk_conv_to_dwidth_conv_axi_bready    ),
        .m_axi_arid     ( clk_conv_to_dwidth_conv_axi_arid      ),
        .m_axi_araddr   ( clk_conv_to_dwidth_conv_axi_araddr    ),
        .m_axi_arlen    ( clk_conv_to_dwidth_conv_axi_arlen     ),
        .m_axi_arsize   ( clk_conv_to_dwidth_conv_axi_arsize    ),
        .m_axi_arburst  ( clk_conv_to_dwidth_conv_axi_arburst   ),
        .m_axi_arlock   ( clk_conv_to_dwidth_conv_axi_arlock    ),
        .m_axi_arcache  ( clk_conv_to_dwidth_conv_axi_arcache   ),
        .m_axi_arprot   ( clk_conv_to_dwidth_conv_axi_arprot    ),
        .m_axi_arregion ( clk_conv_to_dwidth_conv_axi_arregion  ),
        .m_axi_arqos    ( clk_conv_to_dwidth_conv_axi_arqos     ),
        .m_axi_arvalid  ( clk_conv_to_dwidth_conv_axi_arvalid   ),
        .m_axi_arready  ( clk_conv_to_dwidth_conv_axi_arready   ),
        .m_axi_rid      ( clk_conv_to_dwidth_conv_axi_rid       ),
        .m_axi_rdata    ( clk_conv_to_dwidth_conv_axi_rdata     ),
        .m_axi_rresp    ( clk_conv_to_dwidth_conv_axi_rresp     ),
        .m_axi_rlast    ( clk_conv_to_dwidth_conv_axi_rlast     ),
        .m_axi_rvalid   ( clk_conv_to_dwidth_conv_axi_rvalid    ),
        .m_axi_rready   ( clk_conv_to_dwidth_conv_axi_rready    )

    );


    // AXI dwith converter from XLEN bit (global AXI data width) to 512 bit (AXI user interface DDR data width)
    xlnx_axi_dwidth_to512_converter axi_dwidth_conv_u (
        .s_axi_aclk     ( ddr_clk      ),
        .s_axi_aresetn  ( ~ddr_rst     ),

        // Slave from clock conv
        .s_axi_awid     ( clk_conv_to_dwidth_conv_axi_awid    ),
        .s_axi_awaddr   ( clk_conv_to_dwidth_conv_axi_awaddr  ),
        .s_axi_awlen    ( clk_conv_to_dwidth_conv_axi_awlen   ),
        .s_axi_awsize   ( clk_conv_to_dwidth_conv_axi_awsize  ),
        .s_axi_awburst  ( clk_conv_to_dwidth_conv_axi_awburst ),
        .s_axi_awvalid  ( clk_conv_to_dwidth_conv_axi_awvalid ),
        .s_axi_awready  ( clk_conv_to_dwidth_conv_axi_awready ),
        .s_axi_wdata    ( clk_conv_to_dwidth_conv_axi_wdata   ),
        .s_axi_wstrb    ( clk_conv_to_dwidth_conv_axi_wstrb   ),
        .s_axi_wlast    ( clk_conv_to_dwidth_conv_axi_wlast   ),
        .s_axi_wvalid   ( clk_conv_to_dwidth_conv_axi_wvalid  ),
        .s_axi_wready   ( clk_conv_to_dwidth_conv_axi_wready  ),
        .s_axi_bid      ( clk_conv_to_dwidth_conv_axi_bid     ),
        .s_axi_bresp    ( clk_conv_to_dwidth_conv_axi_bresp   ),
        .s_axi_bvalid   ( clk_conv_to_dwidth_conv_axi_bvalid  ),
        .s_axi_bready   ( clk_conv_to_dwidth_conv_axi_bready  ),
        .s_axi_arid     ( clk_conv_to_dwidth_conv_axi_arid    ),
        .s_axi_araddr   ( clk_conv_to_dwidth_conv_axi_araddr  ),
        .s_axi_arlen    ( clk_conv_to_dwidth_conv_axi_arlen   ),
        .s_axi_arsize   ( clk_conv_to_dwidth_conv_axi_arsize  ),
        .s_axi_arburst  ( clk_conv_to_dwidth_conv_axi_arburst ),
        .s_axi_arvalid  ( clk_conv_to_dwidth_conv_axi_arvalid ),
        .s_axi_arready  ( clk_conv_to_dwidth_conv_axi_arready ),
        .s_axi_rid      ( clk_conv_to_dwidth_conv_axi_rid     ),
        .s_axi_rdata    ( clk_conv_to_dwidth_conv_axi_rdata   ),
        .s_axi_rresp    ( clk_conv_to_dwidth_conv_axi_rresp   ),
        .s_axi_rlast    ( clk_conv_to_dwidth_conv_axi_rlast   ),
        .s_axi_rvalid   ( clk_conv_to_dwidth_conv_axi_rvalid  ),
        .s_axi_rready   ( clk_conv_to_dwidth_conv_axi_rready  ),
        .s_axi_awlock   ( clk_conv_to_dwidth_conv_axi_awlock  ),
        .s_axi_awcache  ( clk_conv_to_dwidth_conv_axi_awcache ),
        .s_axi_awprot   ( clk_conv_to_dwidth_conv_axi_awprot  ),
        .s_axi_awqos    ( 0   ),
        .s_axi_awregion ( 0   ),
        .s_axi_arlock   ( clk_conv_to_dwidth_conv_axi_arlock  ),
        .s_axi_arcache  ( clk_conv_to_dwidth_conv_axi_arcache ),
        .s_axi_arprot   ( clk_conv_to_dwidth_conv_axi_arprot  ),
        .s_axi_arqos    ( 0   ),
        .s_axi_arregion ( 0   ),


        // Master to DDR
        // .m_axi_awid     ( dwidth_conv_to_ddr4_axi_awid    ),
        .m_axi_awaddr   ( dwidth_conv_to_cache_axi_awaddr  ),
        .m_axi_awlen    ( dwidth_conv_to_cache_axi_awlen   ),
        .m_axi_awsize   ( dwidth_conv_to_cache_axi_awsize  ),
        .m_axi_awburst  ( dwidth_conv_to_cache_axi_awburst ),
        .m_axi_awlock   ( dwidth_conv_to_cache_axi_awlock  ),
        .m_axi_awcache  ( dwidth_conv_to_cache_axi_awcache ),
        .m_axi_awprot   ( dwidth_conv_to_cache_axi_awprot  ),
        .m_axi_awqos    ( dwidth_conv_to_cache_axi_awqos   ),
        .m_axi_awvalid  ( dwidth_conv_to_cache_axi_awvalid ),
        .m_axi_awready  ( dwidth_conv_to_cache_axi_awready ),
        .m_axi_wdata    ( dwidth_conv_to_cache_axi_wdata   ),
        .m_axi_wstrb    ( dwidth_conv_to_cache_axi_wstrb   ),
        .m_axi_wlast    ( dwidth_conv_to_cache_axi_wlast   ),
        .m_axi_wvalid   ( dwidth_conv_to_cache_axi_wvalid  ),
        .m_axi_wready   ( dwidth_conv_to_cache_axi_wready  ),
        // .m_axi_bid      ( dwidth_conv_to_cache_axi_bid     ),
        .m_axi_bresp    ( dwidth_conv_to_cache_axi_bresp   ),
        .m_axi_bvalid   ( dwidth_conv_to_cache_axi_bvalid  ),
        .m_axi_bready   ( dwidth_conv_to_cache_axi_bready  ),
        // .m_axi_arid     ( dwidth_conv_to_cache_axi_arid    ),
        .m_axi_araddr   ( dwidth_conv_to_cache_axi_araddr  ),
        .m_axi_arlen    ( dwidth_conv_to_cache_axi_arlen   ),
        .m_axi_arsize   ( dwidth_conv_to_cache_axi_arsize  ),
        .m_axi_arburst  ( dwidth_conv_to_cache_axi_arburst ),
        .m_axi_arlock   ( dwidth_conv_to_cache_axi_arlock  ),
        .m_axi_arcache  ( dwidth_conv_to_cache_axi_arcache ),
        .m_axi_arprot   ( dwidth_conv_to_cache_axi_arprot  ),
        .m_axi_arqos    ( dwidth_conv_to_cache_axi_arqos   ),
        .m_axi_arvalid  ( dwidth_conv_to_cache_axi_arvalid ),
        .m_axi_arready  ( dwidth_conv_to_cache_axi_arready ),
        // .m_axi_rid      ( dwidth_conv_to_cache_axi_rid     ),
        .m_axi_rdata    ( dwidth_conv_to_cache_axi_rdata   ),
        .m_axi_rresp    ( dwidth_conv_to_cache_axi_rresp   ),
        .m_axi_rlast    ( dwidth_conv_to_cache_axi_rlast   ),
        .m_axi_rvalid   ( dwidth_conv_to_cache_axi_rvalid  ),
        .m_axi_rready   ( dwidth_conv_to_cache_axi_rready  )
    );

    xlnx_axi_system_cache system_cache_u (
        .ACLK               (ddr_clk),                           // input wire ACLK
        .ARESETN            (~ddr_rst),                       // input wire ARESETN
        .Initializing       (    ),                      // output wire Initializing
        .S0_AXI_GEN_AWID    (dwidth_conv_to_cache_axi_awid),        // input wire [2 : 0] S0_AXI_GEN_AWID
        .S0_AXI_GEN_AWADDR  (dwidth_conv_to_cache_axi_awaddr),    // input wire [31 : 0] S0_AXI_GEN_AWADDR
        .S0_AXI_GEN_AWLEN   (dwidth_conv_to_cache_axi_awlen),      // input wire [7 : 0] S0_AXI_GEN_AWLEN
        .S0_AXI_GEN_AWSIZE  (dwidth_conv_to_cache_axi_awsize),    // input wire [2 : 0] S0_AXI_GEN_AWSIZE
        .S0_AXI_GEN_AWBURST (dwidth_conv_to_cache_axi_awburst),  // input wire [1 : 0] S0_AXI_GEN_AWBURST
        .S0_AXI_GEN_AWLOCK  (dwidth_conv_to_cache_axi_awlock),    // input wire S0_AXI_GEN_AWLOCK
        .S0_AXI_GEN_AWCACHE (dwidth_conv_to_cache_axi_awcache),  // input wire [3 : 0] S0_AXI_GEN_AWCACHE
        .S0_AXI_GEN_AWPROT  (dwidth_conv_to_cache_axi_awprot),    // input wire [2 : 0] S0_AXI_GEN_AWPROT
        .S0_AXI_GEN_AWQOS   (dwidth_conv_to_cache_axi_awqos),      // input wire [3 : 0] S0_AXI_GEN_AWQOS
        .S0_AXI_GEN_AWVALID (dwidth_conv_to_cache_axi_awvalid),  // input wire S0_AXI_GEN_AWVALID
        .S0_AXI_GEN_AWREADY (dwidth_conv_to_cache_axi_awready),  // output wire S0_AXI_GEN_AWREADY
        .S0_AXI_GEN_AWUSER  (dwidth_conv_to_cache_axi_awuser),    // input wire [31 : 0] S0_AXI_GEN_AWUSER
        .S0_AXI_GEN_WDATA   (dwidth_conv_to_cache_axi_wdata),      // input wire [511 : 0] S0_AXI_GEN_WDATA
        .S0_AXI_GEN_WSTRB   (dwidth_conv_to_cache_axi_wstrb),      // input wire [63 : 0] S0_AXI_GEN_WSTRB
        .S0_AXI_GEN_WLAST   (dwidth_conv_to_cache_axi_wlast),      // input wire S0_AXI_GEN_WLAST
        .S0_AXI_GEN_WVALID  (dwidth_conv_to_cache_axi_wvalid),    // input wire S0_AXI_GEN_WVALID
        .S0_AXI_GEN_WREADY  (dwidth_conv_to_cache_axi_wready),    // output wire S0_AXI_GEN_WREADY
        .S0_AXI_GEN_BRESP   (dwidth_conv_to_cache_axi_bresp),      // output wire [1 : 0] S0_AXI_GEN_BRESP
        .S0_AXI_GEN_BID     (dwidth_conv_to_cache_axi_bid),          // output wire [2 : 0] S0_AXI_GEN_BID
        .S0_AXI_GEN_BVALID  (dwidth_conv_to_cache_axi_bvalid),    // output wire S0_AXI_GEN_BVALID
        .S0_AXI_GEN_BREADY  (dwidth_conv_to_cache_axi_bready),    // input wire S0_AXI_GEN_BREADY
        .S0_AXI_GEN_ARID    (dwidth_conv_to_cache_axi_arid),        // input wire [2 : 0] S0_AXI_GEN_ARID
        .S0_AXI_GEN_ARADDR  (dwidth_conv_to_cache_axi_araddr),    // input wire [31 : 0] S0_AXI_GEN_ARADDR
        .S0_AXI_GEN_ARLEN   (dwidth_conv_to_cache_axi_arlen),      // input wire [7 : 0] S0_AXI_GEN_ARLEN
        .S0_AXI_GEN_ARSIZE  (dwidth_conv_to_cache_axi_arsize),    // input wire [2 : 0] S0_AXI_GEN_ARSIZE
        .S0_AXI_GEN_ARBURST (dwidth_conv_to_cache_axi_arburst),  // input wire [1 : 0] S0_AXI_GEN_ARBURST
        .S0_AXI_GEN_ARLOCK  (dwidth_conv_to_cache_axi_arlock),    // input wire S0_AXI_GEN_ARLOCK
        .S0_AXI_GEN_ARCACHE (dwidth_conv_to_cache_axi_arcache),  // input wire [3 : 0] S0_AXI_GEN_ARCACHE
        .S0_AXI_GEN_ARPROT  (dwidth_conv_to_cache_axi_arprot),    // input wire [2 : 0] S0_AXI_GEN_ARPROT
        .S0_AXI_GEN_ARQOS   (dwidth_conv_to_cache_axi_arqos),      // input wire [3 : 0] S0_AXI_GEN_ARQOS
        .S0_AXI_GEN_ARVALID (dwidth_conv_to_cache_axi_arvalid),  // input wire S0_AXI_GEN_ARVALID
        .S0_AXI_GEN_ARREADY (dwidth_conv_to_cache_axi_arready),  // output wire S0_AXI_GEN_ARREADY
        .S0_AXI_GEN_ARUSER  (dwidth_conv_to_cache_axi_aruser),    // input wire [31 : 0] S0_AXI_GEN_ARUSER
        .S0_AXI_GEN_RID     (dwidth_conv_to_cache_axi_rid),          // output wire [2 : 0] S0_AXI_GEN_RID
        .S0_AXI_GEN_RDATA   (dwidth_conv_to_cache_axi_rdata),      // output wire [511 : 0] S0_AXI_GEN_RDATA
        .S0_AXI_GEN_RRESP   (dwidth_conv_to_cache_axi_rresp),      // output wire [1 : 0] S0_AXI_GEN_RRESP
        .S0_AXI_GEN_RLAST   (dwidth_conv_to_cache_axi_rlast),      // output wire S0_AXI_GEN_RLAST
        .S0_AXI_GEN_RVALID  (dwidth_conv_to_cache_axi_rvalid),    // output wire S0_AXI_GEN_RVALID
        .S0_AXI_GEN_RREADY  (dwidth_conv_to_cache_axi_rready),    // input wire S0_AXI_GEN_RREADY
        .M0_AXI_AWID        (cache_to_ddr4_axi_awid),                // output wire [0 : 0] M0_AXI_AWID
        .M0_AXI_AWADDR      (cache_to_ddr4_axi_awaddr),            // output wire [31 : 0] M0_AXI_AWADDR
        .M0_AXI_AWLEN       (cache_to_ddr4_axi_awlen),              // output wire [7 : 0] M0_AXI_AWLEN
        .M0_AXI_AWSIZE      (cache_to_ddr4_axi_awsize),            // output wire [2 : 0] M0_AXI_AWSIZE
        .M0_AXI_AWBURST     (cache_to_ddr4_axi_awburst),          // output wire [1 : 0] M0_AXI_AWBURST
        .M0_AXI_AWLOCK      (cache_to_ddr4_axi_awlock),            // output wire M0_AXI_AWLOCK
        .M0_AXI_AWCACHE     (cache_to_ddr4_axi_awcache),          // output wire [3 : 0] M0_AXI_AWCACHE
        .M0_AXI_AWPROT      (cache_to_ddr4_axi_awprot),            // output wire [2 : 0] M0_AXI_AWPROT
        .M0_AXI_AWQOS       (cache_to_ddr4_axi_awqos),              // output wire [3 : 0] M0_AXI_AWQOS
        .M0_AXI_AWVALID     (cache_to_ddr4_axi_awvalid),          // output wire M0_AXI_AWVALID
        .M0_AXI_AWREADY     (cache_to_ddr4_axi_awready),          // input wire M0_AXI_AWREADY
        .M0_AXI_WDATA       (cache_to_ddr4_axi_wdata),              // output wire [31 : 0] M0_AXI_WDATA
        .M0_AXI_WSTRB       (cache_to_ddr4_axi_wstrb),              // output wire [3 : 0] M0_AXI_WSTRB
        .M0_AXI_WLAST       (cache_to_ddr4_axi_wlast),              // output wire M0_AXI_WLAST
        .M0_AXI_WVALID      (cache_to_ddr4_axi_wvalid),            // output wire M0_AXI_WVALID
        .M0_AXI_WREADY      (cache_to_ddr4_axi_wready),            // input wire M0_AXI_WREADY
        .M0_AXI_BRESP       (cache_to_ddr4_axi_bresp),              // input wire [1 : 0] M0_AXI_BRESP
        .M0_AXI_BID         (cache_to_ddr4_axi_bid),                  // input wire [0 : 0] M0_AXI_BID
        .M0_AXI_BVALID      (cache_to_ddr4_axi_bvalid),            // input wire M0_AXI_BVALID
        .M0_AXI_BREADY      (cache_to_ddr4_axi_bready),            // output wire M0_AXI_BREADY
        .M0_AXI_ARID        (cache_to_ddr4_axi_arid),                // output wire [0 : 0] M0_AXI_ARID
        .M0_AXI_ARADDR      (cache_to_ddr4_axi_araddr),            // output wire [31 : 0] M0_AXI_ARADDR
        .M0_AXI_ARLEN       (cache_to_ddr4_axi_arlen),              // output wire [7 : 0] M0_AXI_ARLEN
        .M0_AXI_ARSIZE      (cache_to_ddr4_axi_arsize),            // output wire [2 : 0] M0_AXI_ARSIZE
        .M0_AXI_ARBURST     (cache_to_ddr4_axi_arburst),          // output wire [1 : 0] M0_AXI_ARBURST
        .M0_AXI_ARLOCK      (cache_to_ddr4_axi_arlock),            // output wire M0_AXI_ARLOCK
        .M0_AXI_ARCACHE     (cache_to_ddr4_axi_arcache),          // output wire [3 : 0] M0_AXI_ARCACHE
        .M0_AXI_ARPROT      (cache_to_ddr4_axi_arprot),            // output wire [2 : 0] M0_AXI_ARPROT
        .M0_AXI_ARQOS       (cache_to_ddr4_axi_arqos),              // output wire [3 : 0] M0_AXI_ARQOS
        .M0_AXI_ARVALID     (cache_to_ddr4_axi_arvalid),          // output wire M0_AXI_ARVALID
        .M0_AXI_ARREADY     (cache_to_ddr4_axi_arready),          // input wire M0_AXI_ARREADY
        .M0_AXI_RID         (cache_to_ddr4_axi_rid),                  // input wire [0 : 0] M0_AXI_RID
        .M0_AXI_RDATA       (cache_to_ddr4_axi_rdata),              // input wire [31 : 0] M0_AXI_RDATA
        .M0_AXI_RRESP       (cache_to_ddr4_axi_rresp),              // input wire [1 : 0] M0_AXI_RRESP
        .M0_AXI_RLAST       (cache_to_ddr4_axi_rlast),              // input wire M0_AXI_RLAST
        .M0_AXI_RVALID      (cache_to_ddr4_axi_rvalid),            // input wire M0_AXI_RVALID
        .M0_AXI_RREADY      (cache_to_ddr4_axi_rready)            // output wire M0_AXI_RREADY
    );


    // Map DDR4 address signals
    // Zero extend them if the address width is 32, otherwise clip them down.
    assign ddr4_axi_awaddr = (LOCAL_ADDR_WIDTH == 32) ? { 2'b00, cache_to_ddr4_axi_awaddr } : cache_to_ddr4_axi_awaddr[DDR4_CHANNEL_ADDRESS_WIDTH-1:0];
    assign ddr4_axi_araddr = (LOCAL_ADDR_WIDTH == 32) ? { 2'b00, cache_to_ddr4_axi_araddr } : cache_to_ddr4_axi_araddr[DDR4_CHANNEL_ADDRESS_WIDTH-1:0];

    xlnx_ddr4 ddr4_u (
        .c0_sys_clk_n                ( clk_300mhz_0_n_i ),
        .c0_sys_clk_p                ( clk_300mhz_0_p_i ),

        .sys_rst                     ( ddr4_reset       ),

        // Output - Calibration complete, the memory controller waits for this
        .c0_init_calib_complete      ( /* empty */      ),
        // Output - Interrupt about ECC
        .c0_ddr4_interrupt           ( /* empty */      ),
        // Output - these two debug ports must be open, in the implementation phase Vivado connects these two properly
        .dbg_clk                     ( /* empty */      ),
        .dbg_bus                     ( /* empty */      ),

        // DDR4 interface - to the physical memory
        .c0_ddr4_adr                 ( cx_ddr4_adr      ),
        .c0_ddr4_ba                  ( cx_ddr4_ba       ),
        .c0_ddr4_cke                 ( cx_ddr4_cke      ),
        .c0_ddr4_cs_n                ( cx_ddr4_cs_n     ),
        .c0_ddr4_dq                  ( cx_ddr4_dq       ),
        .c0_ddr4_dqs_t               ( cx_ddr4_dqs_t    ),
        .c0_ddr4_dqs_c               ( cx_ddr4_dqs_c    ),
        .c0_ddr4_odt                 ( cx_ddr4_odt      ),
        .c0_ddr4_parity              ( cx_ddr4_par      ),
        .c0_ddr4_bg                  ( cx_ddr4_bg       ),
        .c0_ddr4_reset_n             ( cx_ddr4_reset_n  ),
        .c0_ddr4_act_n               ( cx_ddr4_act_n    ),
        .c0_ddr4_ck_t                ( cx_ddr4_ck_t     ),
        .c0_ddr4_ck_c                ( cx_ddr4_ck_c     ),

        .c0_ddr4_ui_clk              ( ddr_clk          ),
        .c0_ddr4_ui_clk_sync_rst     ( ddr_rst          ),

        .c0_ddr4_aresetn             ( ~ddr_rst         ),

        // AXILITE interface - for status and control
        .c0_ddr4_s_axi_ctrl_awvalid  ( s_ctrl_axilite_awvalid ),
        .c0_ddr4_s_axi_ctrl_awready  ( s_ctrl_axilite_awready ),
        .c0_ddr4_s_axi_ctrl_awaddr   ( s_ctrl_axilite_awaddr  ),
        .c0_ddr4_s_axi_ctrl_wvalid   ( s_ctrl_axilite_wvalid  ),
        .c0_ddr4_s_axi_ctrl_wready   ( s_ctrl_axilite_wready  ),
        .c0_ddr4_s_axi_ctrl_wdata    ( s_ctrl_axilite_wdata   ),
        .c0_ddr4_s_axi_ctrl_bvalid   ( s_ctrl_axilite_bvalid  ),
        .c0_ddr4_s_axi_ctrl_bready   ( s_ctrl_axilite_bready  ),
        .c0_ddr4_s_axi_ctrl_bresp    ( s_ctrl_axilite_bresp   ),
        .c0_ddr4_s_axi_ctrl_arvalid  ( s_ctrl_axilite_arvalid ),
        .c0_ddr4_s_axi_ctrl_arready  ( s_ctrl_axilite_arready ),
        .c0_ddr4_s_axi_ctrl_araddr   ( s_ctrl_axilite_araddr  ),
        .c0_ddr4_s_axi_ctrl_rvalid   ( s_ctrl_axilite_rvalid  ),
        .c0_ddr4_s_axi_ctrl_rready   ( s_ctrl_axilite_rready  ),
        .c0_ddr4_s_axi_ctrl_rdata    ( s_ctrl_axilite_rdata   ),
        .c0_ddr4_s_axi_ctrl_rresp    ( s_ctrl_axilite_rresp   ),


        // AXI4 interface
        .c0_ddr4_s_axi_awid          ( cache_to_ddr4_axi_awid    ),
        .c0_ddr4_s_axi_awaddr        ( ddr4_axi_awaddr           ),
        .c0_ddr4_s_axi_awlen         ( cache_to_ddr4_axi_awlen   ),
        .c0_ddr4_s_axi_awsize        ( cache_to_ddr4_axi_awsize  ),
        .c0_ddr4_s_axi_awburst       ( cache_to_ddr4_axi_awburst ),
        .c0_ddr4_s_axi_awlock        ( cache_to_ddr4_axi_awlock  ),
        .c0_ddr4_s_axi_awcache       ( cache_to_ddr4_axi_awcache ),
        .c0_ddr4_s_axi_awprot        ( cache_to_ddr4_axi_awprot  ),
        .c0_ddr4_s_axi_awqos         ( cache_to_ddr4_axi_awqos   ),
        .c0_ddr4_s_axi_awvalid       ( cache_to_ddr4_axi_awvalid ),
        .c0_ddr4_s_axi_awready       ( cache_to_ddr4_axi_awready ),
        .c0_ddr4_s_axi_wdata         ( cache_to_ddr4_axi_wdata   ),
        .c0_ddr4_s_axi_wstrb         ( cache_to_ddr4_axi_wstrb   ),
        .c0_ddr4_s_axi_wlast         ( cache_to_ddr4_axi_wlast   ),
        .c0_ddr4_s_axi_wvalid        ( cache_to_ddr4_axi_wvalid  ),
        .c0_ddr4_s_axi_wready        ( cache_to_ddr4_axi_wready  ),
        .c0_ddr4_s_axi_bready        ( cache_to_ddr4_axi_bready  ),
        .c0_ddr4_s_axi_bid           ( cache_to_ddr4_axi_bid     ),
        .c0_ddr4_s_axi_bresp         ( cache_to_ddr4_axi_bresp   ),
        .c0_ddr4_s_axi_bvalid        ( cache_to_ddr4_axi_bvalid  ),
        .c0_ddr4_s_axi_arid          ( cache_to_ddr4_axi_arid    ),
        .c0_ddr4_s_axi_araddr        ( ddr4_axi_araddr           ),
        .c0_ddr4_s_axi_arlen         ( cache_to_ddr4_axi_arlen   ),
        .c0_ddr4_s_axi_arsize        ( cache_to_ddr4_axi_arsize  ),
        .c0_ddr4_s_axi_arburst       ( cache_to_ddr4_axi_arburst ),
        .c0_ddr4_s_axi_arlock        ( cache_to_ddr4_axi_arlock  ),
        .c0_ddr4_s_axi_arcache       ( cache_to_ddr4_axi_arcache ),
        .c0_ddr4_s_axi_arprot        ( cache_to_ddr4_axi_arprot  ),
        .c0_ddr4_s_axi_arqos         ( cache_to_ddr4_axi_arqos   ),
        .c0_ddr4_s_axi_arvalid       ( cache_to_ddr4_axi_arvalid ),
        .c0_ddr4_s_axi_arready       ( cache_to_ddr4_axi_arready ),
        .c0_ddr4_s_axi_rready        ( cache_to_ddr4_axi_rready  ),
        .c0_ddr4_s_axi_rlast         ( cache_to_ddr4_axi_rlast   ),
        .c0_ddr4_s_axi_rvalid        ( cache_to_ddr4_axi_rvalid  ),
        .c0_ddr4_s_axi_rresp         ( cache_to_ddr4_axi_rresp   ),
        .c0_ddr4_s_axi_rid           ( cache_to_ddr4_axi_rid     ),
        .c0_ddr4_s_axi_rdata         ( cache_to_ddr4_axi_rdata   )
    );

endmodule



