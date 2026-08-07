//------------------------------------------------------------------------------
// (c) Jason Wilden 2026
//------------------------------------------------------------------------------
`default_nettype none

module aud_pipeline (
    input var logic clk_i,
    input var logic rst_ni,    

    // Audio interrupt out
    output logic irq_o,

    // I2S out
    output logic aud_bclk_o,
    output logic aud_lrclk_o,
    output logic aud_sda_o
);
  //------------------------------------------------------------------------------
  // Audio pipeline fans out into 4 voices
  //------------------------------------------------------------------------------

  // Voice processing here x 4


  //------------------------------------------------------------------------------
  // Voices mixed back into single output and scaled for I2S
  //------------------------------------------------------------------------------


  //------------------------------------------------------------------------------
  // I2S peripheral
  //------------------------------------------------------------------------------
  logic bclk, lrclk, sda, req;
  logic [15:0] left;
  logic [15:0] right;

  i2s_tx it (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .sample_i({left, right}),
      .req_o(req),
      .aud_bclk_o(bclk),
      .aud_lrclk_o(lrclk),
      .aud_sda_o(sda)
  );

  //------------------------------------------------------------------------------
  // Test sawtooth generator
  //------------------------------------------------------------------------------
  test_tone tt (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .fcw_i(16'd615),
      .sample_req_i(req),
      .sample_o({left, right})
  );


  //------------------------------------------------------------------------------
  // Outputs
  //------------------------------------------------------------------------------
  assign aud_bclk_o = bclk;
  assign aud_lrclk_o = lrclk;
  assign aud_sda_o = sda;
  assign irq_o = req;

endmodule

`default_nettype wire
