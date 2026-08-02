`timescale 1ns/1ps
`default_nettype none

module midi_tb;

//------------------------------------------------------------------------------
// Test control counts
//------------------------------------------------------------------------------
integer test_failures = 0;
integer test_count    = 0;

//------------------------------------------------------------------------------
// DUT parameters
//------------------------------------------------------------------------------
localparam logic [10:0] DVSR       = 11'd4;
localparam integer      BIT_CLOCKS = 16 * (DVSR + 1);

//------------------------------------------------------------------------------
// Clock and reset
//------------------------------------------------------------------------------
logic clk = 0;
always #5 clk = ~clk;

logic rst_n;
initial begin
  rst_n = 0;
  #50;
  rst_n = 1;
end

// ------------------------------------------------------------------
// UUT
// ------------------------------------------------------------------
logic         rx_i;
logic         irq_o;
logic         select_i;

logic         mem_ready_o;
logic [3:0]   mem_wstrb_i;
logic [31:0]  mem_addr_i;
logic [31:0]  mem_wdata_i;
logic [31:0]  mem_rdata_o;


midi #(
  .FIFO_DEPTH(16),
  .FIFO_AW   (4)
) uut (
  .clk_i       (clk),
  .rst_ni      (rst_n),
  .rx_i        (rx_i),
  .irq_o       (irq_o),
  .select_i    (select_i),
  .mem_ready_o (mem_ready_o),
  .mem_wstrb_i (mem_wstrb_i),
  .mem_addr_i  (mem_addr_i),
  .mem_wdata_i (mem_wdata_i),
  .mem_rdata_o (mem_rdata_o),
  .debug_o()
);

// MMIO helpers (single cycle)
localparam logic[3:0] CR = 4'h0;
localparam logic [3:0] SR  = 4'h1;
localparam logic [3:0] RD  = 4'h2;
localparam logic [3:0] ICR = 4'h3;

task automatic mmio_write(logic [3:0] mmio_reg, logic [31:0] data);
    begin
        @(posedge clk);
        select_i    <= 1'b1;
        mem_addr_i  <= {26'h0, mmio_reg, 2'b00}; // word index in [5:2]
        mem_wstrb_i <= 4'b1111;
        mem_wdata_i <= data;
        @(posedge clk);

        // mem_ready_o is just select_i, so one cycle is enough
        select_i    <= 1'b0;
        mem_wstrb_i <= 4'b0000;
    end
endtask

task automatic mmio_read(input logic [3:0] mmio_reg, output logic [31:0] data);
  begin
      @(posedge clk);
      select_i    <= 1'b1;
      mem_addr_i  <= {26'h0, mmio_reg, 2'b00};
      mem_wstrb_i <= 4'b0000;
      @(posedge clk);
      data        = mem_rdata_o;
      select_i    <= 1'b0;
  end
endtask

// ------------------------------------------------------------------
// Drive serial byte
// ------------------------------------------------------------------
task automatic drive_byte(logic [7:0] data);
  @(posedge clk); #1;
  rx_i = 1'b0;
  repeat (BIT_CLOCKS) @(posedge clk);

  for (int i = 0; i < 8; i++) begin
    rx_i = data[i];
    repeat (BIT_CLOCKS) @(posedge clk);
  end
  
  rx_i = 1'b1;
  repeat (BIT_CLOCKS) @(posedge clk);
endtask

task automatic display_error(string msg);
    begin
        test_failures++;
        $display(msg);
    end
endtask

// cause a framing error
task automatic drive_framing_error(logic [7:0] data);
  @(posedge clk); #1;
  rx_i = 1'b0;
  repeat (BIT_CLOCKS) @(posedge clk);

  for (int i = 0; i < 8; i++) begin
    rx_i = data[i];
    repeat (BIT_CLOCKS) @(posedge clk);
  end

  // hold the stop bit low for 16 samples
  rx_i = 1'b0;
  repeat (BIT_CLOCKS) @(posedge clk);

  // Idle state
  rx_i = 1'b1;
  repeat (BIT_CLOCKS) @(posedge clk);
endtask


// -------------------------------------------------------------------------
// TEST 1 – reset state and IRQ/FIFO empty
// -------------------------------------------------------------------------
task automatic verify_reset_state;
  logic [31:0] sr;
  begin      

      // After reset, FIFO empty → RXNE=0, FULL=0, OVF=0, FERR=0, irq_o=0
      mmio_read(SR, sr);

      if (irq_o !== 1'b0) display_error("FAIL: verify_reset_state: irq_o should be 0");      
      if (sr[0] !== 1'b0) display_error("FAIL: verify_reset_state: RXNE should be 0");
      if (sr[1] !== 1'b0) display_error("FAIL: verify_reset_state: FULL should be 0");
      if (sr[2] !== 1'b0) display_error("FAIL: verify_reset_state: OVF should be 0");
      if (sr[3] !== 1'b0) display_error("FAIL: verify_reset_state: FERR should be 0");
    
      test_count++;
  end
endtask

// -------------------------------------------------------------------------
// TEST 2 – single byte RX: FIFO push, IRQ high, RXNE set
// -------------------------------------------------------------------------
task automatic verify_single_byte;
    logic [31:0] sr;
    logic [31:0] rd_val;
    begin        
        // Set a sensible baud divisor (non-zero, to enable serial_rx)
        mmio_write(CR, DVSR);

        // Patterned byte for testing
        drive_byte(8'hAA);

        // Allow time for FIFO push
        repeat (200) @(posedge clk);

        // Check for incoming byte interrupt signal
        if (irq_o !== 1'b1) display_error("FAIL: verify_single_byte: irq_o should be 1");      

        // Status: RXNE=1, fifo_count=1
        mmio_read(SR, sr);
        
        if (sr[0] !== 1'b1) display_error("FAIL: verify_single_byte: RXNE should be 1");      
        if (sr[2] !== 1'b0) display_error("FAIL: verify_single_byte: OVF should remain 0");      
        if (sr[3] !== 1'b0) display_error("FAIL: verify_single_byte: FERR should remain 0");      
        if (sr[8+:5] != 'd1) display_error("FAIL: verify_single_byte: fifo_count should be 1");

        // Read RD once: mem_rdata_o[7:0] == 0x90, FIFO pops, RXNE clears, IRQ clears
        mmio_read(RD, rd_val);

        if (rd_val[7:0] !== 8'hAA) display_error("FAIL: verify_single_byte: RD did not return received byte");

        // Give bookkeeping time to settle
        @(posedge clk);
        mmio_read(SR, sr);

        if (sr[0] !== 1'b0) display_error("RXNE should be 0 after draining");
        if (irq_o !== 1'b0) display_error("irq_o should be low after FIFO empty");
        if (sr[8+:5] != 'd0) display_error("FAIL: verify_single_byte: fifo_count should be 0");

        test_count++;
    end
endtask

// -------------------------------------------------------------------------
// TEST 3 – overflow and ICR clear
// -------------------------------------------------------------------------
task automatic verify_overflow_and_clear;
  logic [31:0] sr;
  begin
      // Flood FIFO to trigger OVF latch        
      integer i;
      for (i = 0; i < 20; i++) begin
          drive_byte(8'hA0 + i[7:0]);
          repeat (100) @(posedge clk);
      end

      mmio_read(SR, sr);

      if (sr[2] !== 1'b1) display_error("OVF flag not set after overflow attempt");

      // Clear OVF using ICR bit[2]
      mmio_write(ICR, 32'h4); 

      // Check sticky flag cleared
      mmio_read(SR, sr);
      if (sr[2] !== 1'b0) display_error("OVF flag not cleared by ICR write");
  end
endtask

// -------------------------------------------------------------------------
// TEST 3 – FERR and ICR clear
// -------------------------------------------------------------------------
task automatic verify_framing_error_and_clear;
  logic [31:0] sr;
  begin
      // Flood FIFO to trigger OVF latch        
      integer i;
      for (i = 0; i < 20; i++) begin
          drive_framing_error(8'hA0 + i[7:0]);
          repeat (100) @(posedge clk);
      end

      mmio_read(SR, sr);

      if (sr[3] !== 1'b1) display_error("FERR flag not set after overflow attempt");

      // Clear FERR using ICR bit[3]
      mmio_write(ICR, 32'h4); 

      // Check sticky flag cleared
      mmio_read(SR, sr);
      if (sr[2] !== 1'b0) display_error("FERR flag not cleared by ICR write");
  end
endtask


// -------------------------------------------------------------------------
// Test executor
// -------------------------------------------------------------------------
initial begin
    $dumpfile("midi_tb.fst");
    $dumpvars(0, midi_tb);    
    $display("TESTBENCH: midi_tb");

    // Default bus/line state
    select_i    = 1'b0;
    mem_wstrb_i = 4'b0000;
    mem_addr_i  = 32'h0;
    mem_wdata_i = 32'h0;
    rx_i        = 1'b1; // idle

    // Wait for reset to complete
    @(posedge rst_n);
    @(posedge clk);

    verify_reset_state();
    verify_single_byte();
    verify_overflow_and_clear();
    verify_framing_error_and_clear();

    if (test_failures == 0) $display("PASS: All %0d tests passed.", test_count);
    else $fatal(1, "FAIL: serial_rx_tb. %0d test(s) failed.", test_failures);

    $finish;
end
endmodule

`default_nettype wire