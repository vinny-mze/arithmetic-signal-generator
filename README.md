# Arithmetic Signal Generator (ASG)

An FPGA-based hardware accelerator for generating arithmetic sequences with high throughput and low latency.

## Team FPGAcelerate - Group 6
- Morris Nkomo (NKMMOR001)
- Muzerengwa Vincent (MZRVIN001)
- Teddy Umba Muba (TDDMUB001)
- Mpumelelo Mpanza (MPNMPU002)

## Project Overview

This project implements an Arithmetic Series Generator (ASG) on FPGA to accelerate the generation of arithmetic sequences following the formula:

## a(n) = a₁ + (n-1) · d
Where:
- a₁ is the first term
- d is the common difference
- n is the term index

## Repository Structure

- `/rtl`: RTL design files for the FPGA implementation
- `/python`: Gold standard implementations for validation
- `/docs`: Documentation, diagrams, and reports
- `/results`: Performance benchmark results



### Building and Running
1. Clone the repository
```bash
git clone https://github.com/vinny-mze/arithmetic-signal-generator.git
cd arithmetic-signal-generator
