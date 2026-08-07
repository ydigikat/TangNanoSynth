//------------------------------------------------------------------------------
// (c) Jason Wilden 2026
//------------------------------------------------------------------------------
`default_nettype none

module top (
    input var  logic       clk_i,  
    input var  logic       rst_btn_ni,
    input var  logic       midi_i,    
    

    // IO lines
    output      logic       ftdi_o,      
    output      logic[4:0]  led_o,    
    output      logic       led_trap_o,    

    // I2S
    output      logic       i2s_bclk_o,
    output      logic       i2s_lrclk_o,
    output      logic       i2s_sda_o,

    // Debug output and triggers
    output      logic[15:0] d_o
);

  //------------------------------------------------------------------------------
  // Clock and reset generation.
  //------------------------------------------------------------------------------
  logic clk, rst_n;

  clock_gen cg (
      .clk_i(clk_i),        
      .rst_btn_ni(rst_btn_ni),   
      .clk_o(clk),          
      .rst_no(rst_n)      
  );

  //------------------------------------------------------------------------------
  // MCU 
  //------------------------------------------------------------------------------
  logic trap, trace, audio_irq;
  logic[15:0] gpo;  
  
  mcu #(             
     .B0_MEM_FILE("../handoff/firmware_b0.hex"),
     .B1_MEM_FILE("../handoff/firmware_b1.hex"),
     .B2_MEM_FILE("../handoff/firmware_b2.hex"),
     .B3_MEM_FILE("../handoff/firmware_b3.hex")
  )
  u_mcu (
    .clk_i(clk),
    .rst_ni(rst_n),
    .aud_irq_i(audio_irq),    
    //.pipe_vram_addr_i(vram_addr),
    // .pipe_vram_data_o(vram_data),
    // .pipe_vram_valid_o(vram_valid),
    // .pipe_vram_update_o(pipe_update),
    .gpo_o(gpo),
    .trap_o(trap),
    .trace_o(trace),
    .midi_i(midi_i)      
  );

  //------------------------------------------------------------------------------
  // Audio Pipeline
  //------------------------------------------------------------------------------  
  logic bclk,lrclk,sda;

  aud_pipeline u_aud_pipeline
  (
    .clk_i(clk),
    .rst_ni(rst_n),
    .irq_o(audio_irq),
    .aud_bclk_o(bclk),
    .aud_lrclk_o(lrclk),
    .aud_sda_o(sda)    
  );  
  

  //------------------------------------------------------------------------------
  // Outputs
  //------------------------------------------------------------------------------
  assign led_trap_o = ~trap;      // Processor trap indicator LED (active low)
  assign led_o[4:0] = ~gpo[4:0];  // First 5 gpo pins go to LEDs (active low)
  assign ftdi_o = trace;          // Serial trace output


  assign i2s_bclk_o = bclk;
  assign i2s_lrclk_o = lrclk;
  assign i2s_sda_o = sda;

  assign d_o = 0;

  
  endmodule


`default_nettype wire
