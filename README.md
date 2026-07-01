# RISC-V-Processor-using-RV32I
Complete RTL-to-GDSII implementation of an RV32IM RISC-V processor using OpenLane (SKY130), featuring CSR integration, STA, FPGA validation, and ASIC physical design flow.
Overview

This project presents the complete design, implementation, verification, and physical realization of a 32-bit RV32IM RISC-V processor. The processor was developed as part of the VLSI Design Laboratory course at IIT Bombay.

The project covers the complete ASIC implementation flow, beginning with RTL design in Verilog and extending through synthesis, floorplanning, placement, clock tree synthesis, routing, static timing analysis, GDSII generation, and FPGA validation.

The objective was to gain practical experience with the complete digital ASIC design flow while implementing a fully functional RISC-V processor.

Features
RV32I compliant RISC-V processor
Complete Control and Status Register (CSR) implementation
Verilog RTL implementation
System-level processor integration
FPGA implementation on PYNQ-Z2
RTL-to-GDSII implementation using OpenLane
Static Timing Analysis using Vivado Timing Analyser and OpenSTA
Functional verification through simulation


Project Highlights
RTL Design
Designed and integrated all processor modules in Verilog
Implemented the complete CSR module supporting privileged architecture features
Performed system-level integration of the RV32IM processor
Physical Design

The processor was taken through a complete RTL-to-GDSII implementation using the OpenLane automated ASIC flow with the SKY130 Process Design Kit (PDK).

Major stages included:

RTL Synthesis
Floorplanning
Power Distribution Network generation
Placement
Clock Tree Synthesis (CTS)
Global & Detailed Routing
Static Timing Analysis
GDSII Generation
