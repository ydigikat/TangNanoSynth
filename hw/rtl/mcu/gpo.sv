//------------------------------------------------------------------------------
// (c) Jason Wilden 2026
//
// General purpose output (GPO) MMIO module.
//
// A simple module providing set/reset of 16 output pins.  
//------------------------------------------------------------------------------
`default_nettype none
`include "defs.svh"

module gpo
(
  input `VAR  logic        clk_i,
  input `VAR  logic        rst_ni,  

  input `VAR  logic        select_i,  
  output      logic[15:0]  gpo_o,     
  
  output      logic        mem_ready_o,    
  input `VAR  logic [3:0]  mem_wstrb_i,    
  input `VAR  logic [31:0] mem_addr_i,     
  input `VAR  logic [31:0] mem_wdata_i,    
  output      logic [31:0] mem_rdata_o      
);


//------------------------------------------------------------------------------
// Register offsets (word addressed via addr[5:2])
//------------------------------------------------------------------------------
localparam BSR = 4'h00;               // [31:16] reset, [15:0] set

//------------------------------------------------------------------------------
// Bus decode
//------------------------------------------------------------------------------
logic wr_pins;

assign mem_ready_o = select_i;

assign bus_read   = select_i && (mem_wstrb_i == 4'b0000);
assign bus_write  = select_i && (mem_wstrb_i != 4'b0000);

assign wr_pins = bus_write && (mem_addr_i[5:2] == BSR);



//------------------------------------------------------------------------------
// Internal State
//------------------------------------------------------------------------------
logic [15:0] gpo, gpo_d;           

always_ff @(posedge clk_i) begin
  if (!rst_ni) gpo <= 16'b0;
  else  gpo <=  gpo_d;      
end

//------------------------------------------------------------------------------
// Sequential Logic
//------------------------------------------------------------------------------
always_comb begin
  gpo_d = gpo;

  if(wr_pins) begin
    gpo_d = gpo | mem_wdata_i[15:0];    // Sets
    gpo_d = gpo_d & ~mem_wdata_i[31:16];  // Clears
  end  
end

//------------------------------------------------------------------------------
// Output 
//------------------------------------------------------------------------------
assign gpo_o = gpo;
assign mem_ready_o = select_i;  

// No read operation.  
assign mem_rdata_o = 32'h0000_0000;    

endmodule

`default_nettype wire