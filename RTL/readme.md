# Floating-Point Arithmetic Sequence Generator

![Verilog](https://img.shields.io/badge/Verilog-HDL-blue) 
![IEEE754](https://img.shields.io/badge/IEEE-754-green)
![FPGA](https://img.shields.io/badge/FPGA-Compatible-orange)
![Tested](https://img.shields.io/badge/Tested-6_Cases-success)

A high-performance, hardware-optimized arithmetic sequence generator implementing IEEE-754 single-precision floating-point arithmetic with comprehensive benchmarking capabilities.

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Test Cases](#test-cases)
  - [Functional Tests](#functional-tests)
  - [Performance Benchmark](#performance-benchmark)
- [Performance Metrics](#performance-metrics)
- [Getting Started](#getting-started)
  - [Simulation](#simulation)
  - [Synthesis](#synthesis)
- [Extending the Project](#extending-the-project)
- [Future Work](#future-work)
- [License](#license)

## Overview

The module generates arithmetic sequences of the form:

**a(n) = a₁ + (n − 1) × d**

Where:
- `a₁` = First term (IEEE-754 32-bit floating-point)
- `d` = Common difference (IEEE-754 32-bit floating-point)
- `n` = Number of terms (32-bit unsigned integer)

Key characteristics:
- Fully pipelined design
- Wishbone-compatible memory interface
- 6-stage floating-point adder
- Comprehensive testbench with performance metrics

## Architecture

![Block Diagram](https://i.imgur.com/JQ6G8vD.png)

### Core Components:
1. **Control FSM** (8 states)
   - IDLE, INIT, LOAD_ADD, WAIT_ADD, MEM_WRITE, WAIT_MEM, FINISH
2. **Floating-Point Adder**
   - IEEE-754 compliant
   - 6-stage pipeline (UNPACK → ALIGN → ADD → NORMALIZE → PACK)
3. **Memory Interface**
   - 32-bit data bus
   - Word-addressable
   - Ready/Write handshake protocol

## Features

### Core Functionality
- IEEE-754 single-precision floating-point arithmetic
- Configurable sequence parameters (a₁, d, n)
- Memory-mapped output with start address selection
- Proper handling of special cases:
  - Negative numbers
  - Small/large value ranges
  - Zero crossings

### Verification & Benchmarking
- Built-in performance metrics collection
- Functional correctness checks
- Waveform generation for debugging
- Automated test reporting

## Test Cases

### Functional Tests

| Test Case | Parameters | Expected Output | Purpose |
|-----------|------------|-----------------|---------|
| TC1 | `a₁=1.0, d=1.0, n=5` | [1.0, 2.0, 3.0, 4.0, 5.0] | Basic verification |
| TC2 | `a₁=10.0, d=-0.5, n=5` | [10.0, 9.5, 9.0, 8.5, 8.0] | Negative difference |
| TC3 | `a₁=1000.0, d=0.1, n=5` | [1000.0, 1000.1, 1000.2, 1000.3, 1000.4] | Precision validation |
| TC4 | `a₁=3.14, d=2.71, n=1` | [3.14] | Single-term edge case |
| TC5 | `a₁=-5.0, d=2.5, n=5` | [-5.0, -2.5, 0.0, 2.5, 5.0] | Sign handling |

### Performance Benchmark
**TC6**: `a₁=1.0, d=0.1, n=1000`  
Measures:
- Throughput scaling
- Memory bandwidth
- Pipeline efficiency

## Performance Metrics

The testbench automatically collects:

| Metric | Description | Formula |
|--------|-------------|---------|
| Execution Time | Total simulation time | end_time - start_time |
| First Element Latency | Cycles until first write | first_write - activation |
| Throughput | Elements per second | n/(execution_time × 10⁻⁶) |
| Cycles/Element | Pipeline efficiency | total_cycles/n |
| Memory BW | Data transfer rate | (n × 4B)/(execution_time × 10⁻⁶) |

## Getting Started

### Simulation

1. Compile and run:
```bash
iverilog -o sim fp_arithmetic_sequence_generator.v tb_with_metrics.v
vvp sim > results.log
