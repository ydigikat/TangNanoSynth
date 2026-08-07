//------------------------------------------------------------------------------
// (c) Jason Wilden 2026
//------------------------------------------------------------------------------
`default_nettype none


module test_tone (
    input var logic clk_i,
    input var logic rst_ni,
    input var logic [15:0] fcw_i,
    input var logic sample_req_i,
    output logic [31:0] sample_o

);

  logic [15:0] acc, acc_next;
  logic [31:0] sample, sample_next;

  //------------------------------------------------------------------------------
  // State registers
  //------------------------------------------------------------------------------
  always_ff @(posedge clk_i) begin
    if (~rst_ni) begin
      acc <= 15'd0;
      sample <= 31'd0;
    end else begin
      acc <= acc_next;
      sample <= sample_next;
    end
  end


  //------------------------------------------------------------------------------
  // Next state logic
  //------------------------------------------------------------------------------


  always_comb begin
    acc_next = acc;
    sample_next = sample;

    if (sample_req_i) begin
      acc_next = acc + fcw_i;
      sample_next = {acc_next, acc_next};
    end
  end

  //------------------------------------------------------------------------------
  // Output logic
  //------------------------------------------------------------------------------
  assign sample_o = sample;

endmodule

`default_nettype wire

