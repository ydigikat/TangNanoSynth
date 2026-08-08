# TangNanoSynth

TangNanoSynth will become my template design for FPGA based digital synthesisers on the Tang Nano 9K development board (GW1NR-9 FPGA).

The synth is architected as a system on chip (SOC) using the soft core picorv32. The project also serves as an exploration of applying audio techniques on FPGAs, a learning and work-bench exploration tool for me.

>This is a work in progress as well as a part-time project.  It will likely go for extended periods without updates when my professional work takes up my time.  I am a commercial embedded engineer (with some 44 years experience) but I do not apply the same rigour to my hobby projects as I would to a peer-reviewed commercial project, so other engineers should expect to see things that might make them wince.

### Documentation

- [Overview](<docs/00 Overview.md>)
- [MCU Design](<docs/01 MCU Design.md>)
- [MCU Modules (MMIO)](<docs/02 MCU Modules.md>)
- [Audio Pipeline Design](<docs/03 Audio Pipeline Design.md>)
- [Synthesiser Architecture](<docs/04 Synthesiser Architecture.md>)

### Tooling

> My tooling configuration is for Linux (Ubuntu 22.04)

The project is set up for work with Microsoft VSCode and includes build tasks to build and program the device.  This is the simplest way to run the build tools.

| Task | Purpose |
| ---- | ------- |
| Build & Program  |  Builds both firmware & hardware. Programs bitstream to FPGA RAM|
| HW: Build | Builds hardware |
| HW: Program | Builds hardware and programs bitstream to RAM|
| HW: Flash | Builds hardware and flashes bitstream to FLASH|
| HW: Test | Runs hardware testbench verification|
| FW: Configure | Configures the CMake build for firmware |
| FW: Build | Builds the firmware |
| FW: Clean | Cleans the firmware build outputs |
| FW: Test | Run the firmware unit tests (Unity) |

#### Hardware Toolchain

The easiest way to obtain this is to use the ```devcontainer``` capability of vs code.  Download and build my ```GowinDevContainer``` project which creates the basic docker container (you will need docker.io for Linux or Docker Desktop for Windows/Mac).  When you open this project subsequently, vscode should offer to 'reopen in devcontainer'.  This will then do some additional configuration and download the required vscode extensions for the tools.  If you don't want to use devcontainers the just decline and delete the ```.devcontainer``` folder.

The hardware toolchain is used to build and program/flash the FPGA bitstream.

| Tool  | Purpose |Notes |
| ----  | ----- | ---- |
| gw_sh | Build|Gowin EDA command line tool (TCL console) |
| openFPGALoader | Programming | Open source programmer. The Gowin programmer does not work on Linux|
| iverilog | Simulation |Hardware simulation/verification|
| gtkwave | Simulation| Hardware tracing/analysis|
| slang| LSP & Linting | IDE support and static analysis|
| verilatpr | Formatter | IDE code formatting |

*While the Gowin EDA tools are not open source, they do provide a free license for non-commercial use.  I use this because Gowin generates a more optimally sized implementation than Yosys/Apicula open source tooling (for the present) and space is constrained on this device.*

The build is scripted using ```/hw/tools/build.tcl.``` and invoked using the command ```gw_sh /hw/tools/build.tcl -flags```

| Flag | Meaning |
| -----| ------- |
| -program | Programs the bitstream into the FPGA RAM|
| -flash | Programs the bitstream into the FPGA FLASH|
| -test  | Runs testbench verifications |
| -preprocess | Pre-process source for any Gowin EDA specifics|

I use a number of vscode extensions, see the ```extensions.json``` file.

#### Preprocessing of Testbenches

I use ```iVerilog``` for testbench simulation, however iVerilog does not support all HDL constructs provided by modern SystemVerilog.  

To resolve this, I've opted to preprocess the source so as to not complicate my HDL with macros and conditional compilation.

The python script ```iverilog_pp.py``` creates modified copies of the source at the top-level of the ```test``` folder, the original source is left unchanged.  The testbench ```Makefile``` uses this modified source for execution.

The following preprocessing is applied:

1. The ```var``` keyword is stripped from input ports.  This is required by Gowin EDA when nettype is defaulted to none, unsupported by iVerilog.


#### Firmware Toolchain
The firmware tools are used to build the firmware binary and unit tests. Firmware should always be built before the hardware as it is handed off to the hardware build for inclusion in the bitstream.

| Tool  | Purpose |Notes |
| ----  | ----- | ---- |
| riscv32-unknown-elf-gcc | Cross-Compiler | Builds the RISCV32I firmware binary |
| x86_64-linux-gnu-gcc-11 | Native Compiler| Builds the Unity unit-tests|
| cmake | Build | Build configuration|
| ninja | Build | Build orchestration|
| bin_to_hex.py | Handoff |  Split & binary handoff to hardware|
| gen_luts.py | Code Gen | Generates various lookup tables for firmware|

The firmware build is scripted using ```CMake``` & ```Ninja``` and invoked using the command ```cmake```  

Unit tests are built with the Unity framework and invokved using the command ```cmake```



