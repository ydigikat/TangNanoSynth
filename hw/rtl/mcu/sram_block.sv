//------------------------------------------------------------------------------
// (c) Jason Wilden 2026
//------------------------------------------------------------------------------
`default_nettype none

//------------------------------------------------------------------------------
// Infer a BSRAM instance
//------------------------------------------------------------------------------
module sram_block #(parameter MEM_FILE, 
                            WORD_ADDRESS_WIDTH)
(
  input var logic clk_i,
  input var logic rst_ni,
  input var logic clk_en_i,
  input var logic wrt_en_i,
  input var logic[WORD_ADDRESS_WIDTH-1:0] addr_i,
  input var logic[7:0] data_i,
  output logic[7:0] data_o
);

logic [7:0] bsram[1 << WORD_ADDRESS_WIDTH], data;

//------------------------------------------------------------------------------
// Load firmware into RAM
//------------------------------------------------------------------------------
initial begin
  if (MEM_FILE != "") $readmemh(MEM_FILE, bsram);  
end

always @(posedge clk_i) begin
  if(clk_en_i) begin
    if(wrt_en_i) bsram[addr_i] <= data_i;      
    data <= bsram[addr_i];        
  end
end

assign data_o = data;

endmodule

`default_nettype wire