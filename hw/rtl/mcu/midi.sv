//------------------------------------------------------------------------------
// (c) Jason Wilden 2026
//
//  MIDI MMIO interface.
//
//  This module provides a FIFO based MIDI RX interface via UART. 
//
//  The serial_rx (UART) module produces a rx_valid/rx_data for each serial
//  byte received, The byte is pushed onto the FIFO on the rx_valid signal
//  providing the FIFO is not full otherwise an overflow error is signalled.
//
//  Each CPU read of the RD register returns the topmost byte in the
//  FIFO, this means it needs to be popped just once during each RD read
//  which is ensured by aligning the pop to the memory timing. Data is
//  only valid when bus_read is active.
//
//  The irq_o is the signal to the CPU that there is data in the FIFO.
//------------------------------------------------------------------------------
`default_nettype none

module midi
#(
  parameter int FIFO_DEPTH = 16,
  parameter int FIFO_AW    = 4
)
(
  input  var logic        clk_i,
  input  var logic        rst_ni,

  input  var logic        rx_i,
  output      logic        irq_o,

  input  var logic        select_i,
  output      logic        mem_ready_o,
  input  var logic [3:0]  mem_wstrb_i,
  input  var logic [31:0] mem_addr_i,
  input  var logic [31:0] mem_wdata_i,
  output      logic [31:0] mem_rdata_o,

  output      logic [7:0]  debug_o
);

//------------------------------------------------------------------------------
// Register offsets (word addressed via addr[5:2])
//------------------------------------------------------------------------------
localparam logic [3:0] CR  = 4'h0;  // Control : [10:0] baud divisor
localparam logic [3:0] SR  = 4'h1;  // Status  : [0] RXNE [1] FULL [2] OVF 
                                    //           [3] FERR, [15:8] FIFO COUNT
localparam logic [3:0] RD  = 4'h2;  // RX data : [7:0] reading pops FIFO
localparam logic [3:0] ICR = 4'h3;  // Clear   : write 1 to [2] OVF, [3] FERR

//------------------------------------------------------------------------------
// Bus decode
//------------------------------------------------------------------------------
logic wr_divisor;
logic wr_icr;
logic rd_status;
logic rd_data;
logic bus_read;
logic bus_write;
logic rd_pop;

assign mem_ready_o = select_i;

assign bus_read   = select_i && (mem_wstrb_i == 4'b0000);
assign bus_write  = select_i && (mem_wstrb_i != 4'b0000);

assign wr_divisor = bus_write && (mem_addr_i[5:2] == CR);
assign wr_icr     = bus_write && (mem_addr_i[5:2] == ICR);
assign rd_status  = bus_read  && (mem_addr_i[5:2] == SR);
assign rd_data    = bus_read  && (mem_addr_i[5:2] == RD);

// FIFO pop must only happen when mem_ready_o is high, that is once per
// read of the RD register.  This ensures only one byte is popped per read.
assign rd_pop = rd_data && mem_ready_o && !fifo_empty;

//------------------------------------------------------------------------------
// Internal state
//------------------------------------------------------------------------------
logic [10:0] div;
logic        irq_r;
logic        overflow_lat;
logic        frame_err_lat;

// UART RX interface
logic [7:0] rx_data;
logic       rx_valid;
logic       rx_error;

// FIFO state
logic [7:0] fifo_mem [0:FIFO_DEPTH-1];
logic [FIFO_AW-1:0] wr_ptr;
logic [FIFO_AW-1:0] rd_ptr;
logic [FIFO_AW:0]   fifo_count;
logic               fifo_empty;
logic               fifo_full;
logic               do_push;
logic [7:0]         fifo_head;

assign fifo_empty = (fifo_count == '0);
assign fifo_full  = (fifo_count == FIFO_DEPTH);
assign do_push    = rx_valid && !fifo_full;
assign fifo_head  = fifo_mem[rd_ptr];

//------------------------------------------------------------------------------
// Sequential logic
//------------------------------------------------------------------------------
always_ff @(posedge clk_i) begin
  if (!rst_ni) begin
    div           <= '0;
    irq_r         <= 1'b0;
    overflow_lat  <= 1'b0;
    frame_err_lat <= 1'b0;

    wr_ptr        <= '0;
    rd_ptr        <= '0;
    fifo_count    <= '0;
  end else begin

    // Registered IRQ signal.
    irq_r <= !fifo_empty;

    // Baud divisor.
    if (wr_divisor) div <= mem_wdata_i[10:0];

    // Sticky framing error flag 
    if (rx_error) frame_err_lat <= 1'b1;

    // FIFO push.
    if (rx_valid) begin
      if (!fifo_full) begin
        fifo_mem[wr_ptr] <= rx_data;
        wr_ptr <= wr_ptr + 1'b1;
      end else begin
        overflow_lat <= 1'b1;
      end
    end

    // FIFO pop on completed RD access.
    if (rd_pop) rd_ptr <= rd_ptr + 1'b1;

    // FIFO pointer book-keeping (dec/inc)
    case ({do_push, rd_pop})
      2'b10: fifo_count <= fifo_count + 1'b1;
      2'b01: fifo_count <= fifo_count - 1'b1;
      default: ;
    endcase

    // Clear sticky status flags
    if (wr_icr) begin
      if (mem_wdata_i[2]) overflow_lat  <= 1'b0;
      if (mem_wdata_i[3]) frame_err_lat <= 1'b0;
    end
  end
end

//------------------------------------------------------------------------------
// Serial RX core
//------------------------------------------------------------------------------
serial_rx u_rx (
  .clk_i     (clk_i),
  .rst_ni    (rst_ni),
  .div_i     (div),
  .rx_i      (rx_i),
  .rx_data_o (rx_data),
  .rx_valid_o(rx_valid),
  .rx_error_o(rx_error),
  .debug_o   ()
);

//------------------------------------------------------------------------------
// Read data mux
// mem_rdata_o only valid on the cycle where select_i and mem_ready_o are high. 
//------------------------------------------------------------------------------
assign mem_rdata_o = rd_data   ? {24'h0, fifo_head} :
                     rd_status ? {16'h0,
                                  fifo_count[FIFO_AW:0],
                                  4'h0,
                                  frame_err_lat,
                                  overflow_lat,
                                  fifo_full,
                                  !fifo_empty} :
                     32'h0000_0000;

assign irq_o = irq_r;

endmodule

`default_nettype wire