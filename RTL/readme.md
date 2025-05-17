# Floating-Point Arithmetic Sequence Generator

## Overview
This project implements an IEEE-754 single-precision floating-point arithmetic sequence generator in Verilog. The module generates a sequence of numbers in the form `a(n) = a1 + (n-1)d` and stores the results in memory.

## Module Description

### `fp_arithmetic_sequence_generator`
#### Inputs:
- `clk`: Clock signal
- `rst_n`: Active-low reset
- `activate`: Pulse to start sequence generation
- `a1`: First term (IEEE-754 single precision)
- `d`: Common difference (IEEE-754 single precision)
- `n`: Number of terms (32-bit unsigned integer)
- `saddr`: Starting memory address for results
- `mem_ready`: Memory ready signal

#### Outputs:
- `done`: High when sequence generation is complete
- `mem_addr`: Memory address (byte addressable)
- `mem_wdata`: Data to write to memory
- `mem_write`: Write enable signal

#### Features:
- Generates arithmetic sequences with floating-point precision
- Uses a finite state machine (FSM) for control flow
- Includes a floating-point adder module for calculations
- Handles memory writes with handshake protocol

### `fp_adder`
A supporting module that performs IEEE-754 single-precision floating-point addition. It:
1. Unpacks the floating-point numbers
2. Aligns mantissas
3. Performs addition/subtraction
4. Normalizes the result
5. Packs it back into IEEE-754 format

## Testbench
The testbench (`fp_arithmetic_sequence_generator_tb`) verifies the functionality with several test cases:

1. Simple sequence: 1.0, 2.0, 3.0, 4.0, 5.0
2. Decreasing sequence: 10.0, 9.5, 9.0, 8.5, 8.0
3. Large values with small difference: 1000.0, 1000.1, 1000.2, 1000.3, 1000.4
4. Single term sequence: 3.14
5. Negative values: -5.0, -2.5, 0.0, 2.5, 5.0

The testbench includes helper functions to convert between floating-point numbers and their IEEE-754 representations for verification.

## Simulation
To run the simulation:
1. Use a Verilog simulator (e.g., Icarus Verilog, ModelSim)
2. Compile both the design and testbench files
3. Run the simulation
4. View the waveform output (`fp_arithmetic_sequence_generator_tb.vcd`) if desired

## Expected Output
The testbench will:
- Display results of each test case
- Report any discrepancies between expected and actual values
- Provide a summary indicating whether all tests passed or the number of errors detected

## Implementation Notes
- Synchronous active-low reset
- Memory writes use handshake protocol (`mem_write` and `mem_ready`)
- Floating-point adder handles normalization and special cases (like zero)
- Testbench includes a reset test that interrupts an ongoing sequence

## Limitations
- Floating-point adder uses simplified normalization
- Assumes word-aligned memory addresses
- Denormal numbers and NaN/infinity cases not fully handled

This implementation provides a solid foundation for generating arithmetic sequences with floating-point precision in hardware.
