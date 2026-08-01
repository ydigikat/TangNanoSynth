/*
 *  (c) Jason Wilden, 2026
 */

#include "drv.h"
#include "synth.h"

#define IRQ_TIMER (1u)
#define IRQ_AUDIO (1u << 3)
#define IRQ_MIDI (1u << 4)

#define TIMER_COUNT (6000000UL)

static volatile uint8_t irq_count = 0;
static struct synth synth;
static volatile bool blink = false;

/* Private functions */
static void board_init();
static void midi_irq_handler();
static void timer_irq_handler();
static uint32_t reload_timer(uint32_t val);

/*
 * Entry point
 */
int main(void)
{

  board_init();
  synth_init(&synth);
  reload_timer(TIMER_COUNT);

  while (1)
  {
    irq_count = synth_run_control_block(&synth, irq_count);
  }

  /*NOTREACHED*/
  return 0;
}

/*
 * Initialise hardware.
 */
static void board_init()
{
#ifdef TRACE_ENABLED
  trace_init(TRACE);
#endif

  midi_init(MIDI);
}

/*
 * ISR.  The mask can have multiple IRQ bits so there is an implied
 * priority to the order of IRQ checks in the function.
 */
void handle_irq(uint32_t mask)
{
  /* Control block sample counter */
  if (mask & IRQ_AUDIO)
  {
    irq_count++;
  }

  /* Read pending MIDI bytes */
  if (mask & IRQ_MIDI)
  {
    midi_irq_handler();
  }

  /* Timer event */
  if (mask & IRQ_TIMER)
  {
    timer_irq_handler();
  }
}

/*
 * Handle the MIDI interrupt.  This drains the hardware FIFO into the
 * parser's ring-buffer for processing.  Errors are logged but otherwise
 * ignored (not much we can do).
 */
static void midi_irq_handler()
{
  uint32_t sr;
  uint32_t clr = 0U;

  sr = midi_status(MIDI);

  // Overflow
  if (sr & MIDI_SR_OVF)
  {
    // Catch this in debug, probably means FIFO is too small or not draining..
    // TRACE_ASSERT(false);
    clr |= MIDI_SR_OVF;
  }

  // Framing error 
  if (sr & MIDI_SR_FERR)
  { 
    // Not much we can do for a serial rx error - just trace it in debug.   
    // TRACE_PRINT("FRAME-ERROR");
    clr |= MIDI_SR_FERR;
  }  

  // Drain the FIFO
  while (sr & MIDI_SR_RXNE)
  {
    uint8_t byte = midi_read_byte(MIDI);    
    midi_buffer_write(byte);
    sr = midi_status(MIDI);
  }

  // Clear any sticky status bits that were set.
  if (clr != 0)
  {
    midi_clear_status(MIDI, clr);
  }
}

/*
 * Reloads the PicoRV32 one-shot timer, there is no C function to do this so
 * we need inline assembly.
 */
static uint32_t reload_timer(uint32_t val)
{
  uint32_t retval;
  __asm__ volatile(
      ".insn r 0b0001011, 0b110, 0b0000101, %0, %1, x0\n"
      : "=r"(retval)
      : "r"(val));

  return retval;
}

/*
 * Handler timer interrupt.  This just toggles a heartbeat LED and resets
 * the timer.
 */
static void timer_irq_handler()
{
  blink = !blink;
  blink ? gpo_set_pin(GPO1, GPO_BSR_3) : gpo_clear_pin(GPO1, GPO_BSR_3);
  reload_timer(TIMER_COUNT);
}
