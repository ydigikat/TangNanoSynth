//------------------------------------------------------------------------------
// (c) Jason Wilden 2026
//------------------------------------------------------------------------------
`default_nettype none
`include "../defs.svh"

module serial_rx (
  input  `VAR logic        clk_i,
  input  `VAR logic        rst_ni,
  input  `VAR logic [10:0] div_i,
  input  `VAR logic        rx_i,
  output      logic [7:0]  rx_data_o,
  output      logic        rx_valid_o,
  output      logic        rx_error_o,

  output      logic[7:0]   debug_o
);

//------------------------------------------------------------------------------
// State machine encoding
//------------------------------------------------------------------------------
typedef enum logic [2:0]
{
  Idle,
  Start,
  Data,
  Stop,
  Flush
} uart_state_t;

uart_state_t state, state_d;

//------------------------------------------------------------------------------
// Double flop sync
//------------------------------------------------------------------------------
logic rx_s0, rx_s1;

always_ff @(posedge clk_i) begin
  if (!rst_ni) begin
    rx_s0 <= 1'b1;
    rx_s1 <= 1'b1;
  end else begin
    rx_s0 <= rx_i;
    rx_s1 <= rx_s0;
  end
end

//------------------------------------------------------------------------------
// Registers
//------------------------------------------------------------------------------
logic [10:0] sample_div, sample_div_d;
logic [3:0]  sample_cnt, sample_cnt_d;
logic [2:0]  bit_cnt,    bit_cnt_d;
logic [7:0]  data,       data_d;

// Output registers
logic        rx_valid,   rx_valid_d;
logic        rx_error,   rx_error_d;

always_ff @(posedge clk_i) begin
  if (!rst_ni) begin
    state      <= Idle;
    bit_cnt    <= '0;
    sample_cnt <= '0;
    data       <= '0;
    sample_div <= '0;
    rx_valid   <= 1'b0;
    rx_error   <= 1'b0;
  end else begin
    state      <= state_d;
    bit_cnt    <= bit_cnt_d;
    sample_cnt <= sample_cnt_d;
    data       <= data_d;
    sample_div <= sample_div_d;
    rx_valid   <= rx_valid_d;
    rx_error   <= rx_error_d;
  end
end

//------------------------------------------------------------------------------
// Sample rate divider
//------------------------------------------------------------------------------
logic sample_inc;
assign sample_inc   = (sample_div == div_i);
assign sample_div_d = (state == Idle) ? '0 :
                       sample_inc      ? '0 : (sample_div + 11'd1);

//------------------------------------------------------------------------------
// Next-state / output logic
//------------------------------------------------------------------------------
always_comb begin
  state_d      = state;
  bit_cnt_d    = bit_cnt;
  sample_cnt_d = sample_cnt;
  data_d       = data;  
  rx_error_d   = rx_error;
  rx_valid_d   = 1'b0;  

  case (state) 

    // Idle — line is high. Wait for falling edge is a start-bit candidate.
    Idle: begin
      rx_error_d   = 1'b0;
      if(rx_s1) begin
        sample_cnt_d = '0;
      end
      if (!rx_s1) begin
        state_d      = Start;
        sample_cnt_d = 4'd0;
      end
    end

    // Start bit — wait 8 samples to place us in the middle of the start bit.
    Start: begin
      if (sample_inc) begin
        if (sample_cnt == 4'd7) begin
          if (!rx_s1) begin

            // In the middle and still valid so move next to data state.
            state_d      = Data;
            sample_cnt_d = 4'd0;
            bit_cnt_d    = 3'd0;
          end else begin
            state_d = Idle;
            sample_cnt_d = 4'd0;
          end
        end else begin
          sample_cnt_d = sample_cnt + 4'd1;
        end
      end
    end

    Data: begin
      if (sample_inc) begin

        // Wait 16 samples which places us in the middle of the data bit        
        if (sample_cnt == 4'd15) begin
          sample_cnt_d = 4'd0;        
          // Shift register: LSB-first from wire means each new bit enters at
          // the MSB and shifts right. After 8 bits, data[0] holds the first
          // received bit (LSB of the transmitted byte).
          data_d = (data >> 1) | (rx_s1 ? 8'h80 : 8'h00);
          if (bit_cnt == 3'd7) begin
            state_d = Stop;
          end else begin
            bit_cnt_d = bit_cnt + 3'd1;
          end
        end else begin
          sample_cnt_d = sample_cnt + 4'd1;
        end
      end
    end

    // Stop bit — line must be high; framing error if not.
    Stop: begin
      if (sample_inc) begin
        if (sample_cnt == 4'd15) begin
          sample_cnt_d = 4'd0;
          if(rx_s1) begin
            rx_valid_d = 1'b1;
            rx_error_d = 1'b0;
            state_d = Idle;
          end else begin
            rx_valid_d = 0;
            rx_error_d = 1;
            state_d    = Flush;
          end
        end else begin
          sample_cnt_d = sample_cnt + 4'd1;
        end
      end
    end

    // Flush line after a parity error and wait for Idle state to recover
    Flush: begin
      sample_cnt_d = 4'd0;
      bit_cnt_d = 3'd0;
      if(rx_s1) begin
        state_d = Idle;
      end
    end

    default: begin
    end

  endcase
end

//------------------------------------------------------------------------------
// Outputs
//------------------------------------------------------------------------------
assign rx_data_o  = data;
assign rx_valid_o = rx_valid;
assign rx_error_o = rx_error;


// assign debug_o[0] = rx_valid;
// assign debug_o[1] = rx_error;
// assign debug_o[4:2] = state;


endmodule

`default_nettype wire