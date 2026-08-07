//------------------------------------------------------------------------------
// (c) Jason Wilden 2026
//
// Trace MMIO module.
//
// Implements an unbuffered serial transmit peripheral for use by the
// tracing capabilty in the MCU. 
//
//------------------------------------------------------------------------------
`default_nettype none

module trace (
    input var logic clk_i,
    input var logic rst_ni,
    input var logic select_i,
    output    logic trace_o,

    output    logic        mem_ready_o,
    input var logic [ 3:0] mem_wstrb_i,
    input var logic [31:0] mem_addr_i,
    input var logic [31:0] mem_wdata_i,
    output    logic [31:0] mem_rdata_o
);

  //------------------------------------------------------------------------------
  // Register offsets (word addressed via addr[5:2])
  //------------------------------------------------------------------------------
  localparam CR = 4'h00;  // Control (divisor)
  localparam SR = 4'h01;  // Status
  localparam TD = 4'h02;  // TX data

  //------------------------------------------------------------------------------
  // Bus Decode
  //------------------------------------------------------------------------------
  logic wr_divisor, wr_uart, rd_status, bus_read, bus_write;

  assign bus_read   = select_i && (mem_wstrb_i == 4'b0000);
  assign bus_write  = select_i && (mem_wstrb_i != 4'b0000);

  assign wr_divisor = bus_write && (mem_addr_i[5:2] == CR);
  assign wr_uart    = bus_write && (mem_addr_i[5:2] == TD);
  assign rd_status  = bus_read  && (mem_addr_i[5:2] == SR);

  //------------------------------------------------------------------------------
  // Internal State
  //------------------------------------------------------------------------------
  logic [10:0] div;
  logic [ 7:0] data;
  logic        send;
  logic        mem_ready;
  logic        tx;
  logic        done;

  //------------------------------------------------------------------------------
  // Sequential Logic
  //------------------------------------------------------------------------------
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      div       <= '0;
      data      <= '0;
      send      <= 1'b0;
      mem_ready <= 1'b0;
    end else begin
      send <= 1'b0;  // Hold state

      // Write divisor register
      if (wr_divisor) div <= mem_wdata_i[10:0];

      // Write data register
      if (wr_uart && done) begin
        data <= mem_wdata_i[7:0];
        send <= 1'b1;
      end

      mem_ready <= (wr_uart ? done : select_i);
    end
  end

  //------------------------------------------------------------------------------
  // Serial output
  //------------------------------------------------------------------------------
  serial_tx utx (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .div_i(div),
      .data_i(data),
      .tx_start_i(send),
      .tx_done_o(done),
      .tx_o(tx)
  );

  //------------------------------------------------------------------------------
  // Output
  //------------------------------------------------------------------------------
  assign trace_o     = tx;
  assign mem_rdata_o = (rd_status ? {31'h0, done} : 32'h0000_0000);
  assign mem_ready_o = mem_ready;

endmodule

`default_nettype wire
