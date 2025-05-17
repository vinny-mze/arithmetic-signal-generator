// Code your testbench here
// or browse Examples
`timescale 1ns/1ps

module fp_arithmetic_sequence_generator_tb_with_metrics;

    // Parameters
    parameter CLK_PERIOD = 10; // 10ns (100MHz clock)
    
    // Test bench signals
    reg clk;
    reg rst_n;
    reg activate;
    reg [31:0] a1;        // First term
    reg [31:0] d;         // Common difference
    reg [31:0] n;         // Number of terms
    reg [31:0] saddr;     // Starting address
    wire done;            // Sequence complete

    // Memory interface signals
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire mem_write;
    reg mem_ready;
    
    // Memory model
    reg [31:0] mem [0:1023]; // 1024 words of memory
    
    // Performance metrics
    time start_time, end_time;
    integer cycle_count;
    time first_write_time;
    reg first_write_detected;
    time last_write_time;
    
    // Overall performance metrics
    real total_elements_processed;
    time total_execution_time;
    real avg_throughput;
    real avg_cycles_per_element;
    
    // Test variables
    integer i;
    reg [31:0] expected_terms[0:9]; // Store expected terms for verification
    integer error_count;
    
    // Function to convert float to IEEE-754 format
    function [31:0] float_to_ieee754;
        input real float_num;
        reg sign;
        reg [7:0] exponent;
        reg [22:0] mantissa;
        real abs_num, normalized_num;
        integer exp;
    begin
        // Get sign bit
        sign = (float_num < 0) ? 1'b1 : 1'b0;
        abs_num = (float_num < 0) ? -float_num : float_num;
        
        // Handle zero case
        if (abs_num == 0) begin
            float_to_ieee754 = 32'h0;
        end else begin
            // Find exponent
            exp = 0;
            normalized_num = abs_num;
            
            if (normalized_num >= 2.0) begin
                while (normalized_num >= 2.0) begin
                    normalized_num = normalized_num / 2.0;
                    exp = exp + 1;
                end
            end else begin
                while (normalized_num < 1.0) begin
                    normalized_num = normalized_num * 2.0;
                    exp = exp - 1;
                end
            end
            
            // IEEE-754 exponent with bias of 127
            exponent = exp + 127;
            
            // Calculate mantissa (fractional part)
            mantissa = 0;
            normalized_num = normalized_num - 1.0; // Remove leading 1
            
            for (i = 0; i < 23; i = i + 1) begin
                normalized_num = normalized_num * 2.0;
                if (normalized_num >= 1.0) begin
                    mantissa = (mantissa << 1) | 1'b1;
                    normalized_num = normalized_num - 1.0;
                end else begin
                    mantissa = mantissa << 1;
                end
            end
            
            // Combine all parts
            float_to_ieee754 = {sign, exponent, mantissa};
        end
    end
    endfunction
    
    // Function to convert IEEE-754 format to float (for display purposes)
    function real ieee754_to_float;
        input [31:0] ieee_num;
        reg sign;
        reg [7:0] exponent;
        reg [22:0] mantissa;
        real result, mantissa_val;
        integer exp;
    begin
        sign = ieee_num[31];
        exponent = ieee_num[30:23];
        mantissa = ieee_num[22:0];
        
        // Handle special cases
        if (exponent == 0) begin
            // Zero or denormalized (treat as zero for simplicity)
            ieee754_to_float = 0.0;
        end else if (exponent == 8'hFF) begin
            // Infinity or NaN (return a large value for simplicity)
            ieee754_to_float = (sign) ? -1.0e38 : 1.0e38;
        end else begin
            // Normal number
            exp = exponent - 127;
            
            // Calculate value from mantissa (implied leading 1)
            mantissa_val = 1.0;
            for (i = 0; i < 23; i = i + 1) begin
                if (mantissa[22-i])
                    mantissa_val = mantissa_val + (2.0 ** (-1 - i));
            end
            
            // Apply exponent and sign
            result = mantissa_val * (2.0 ** exp);
            ieee754_to_float = (sign) ? -result : result;
        end
    end
    endfunction
    
    // Instantiate the module under test
    fp_arithmetic_sequence_generator DUT (
        .clk(clk),
        .rst_n(rst_n),
        .activate(activate),
        .a1(a1),
        .d(d),
        .n(n),
        .saddr(saddr),
        .done(done),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_write(mem_write),
        .mem_ready(mem_ready)
    );
    
    // Clock generation
    always begin
        #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Memory model
    always @(posedge clk) begin
        if (mem_write) begin
            mem[mem_addr/4] <= mem_wdata; // Assuming word-aligned addresses
            mem_ready <= 1'b1;
            
            // Track first and last memory write times
            if (!first_write_detected) begin
                first_write_time = $time;
                first_write_detected = 1;
            end
            last_write_time = $time;
        end else begin
            mem_ready <= 1'b0;
        end
    end
    
    // Cycle counter
    always @(posedge clk) begin
        if (activate && !done) begin
            cycle_count = cycle_count + 1;
        end
    end
    
    // VCD dump for waveform visualization
    initial begin
        $dumpfile("fp_arithmetic_sequence_generator_tb.vcd");
        $dumpvars(0, fp_arithmetic_sequence_generator_tb_with_metrics);
    end
    
    // Performance metrics display task
    task display_metrics;
        input integer seq_size;
        input real seq_first;
        input real seq_diff;
        input time exec_time;
        real throughput, cycles_per_element;
        real latency_first_element;
        begin
            throughput = (seq_size * 1000.0) / exec_time;  // Million elements per second
            cycles_per_element = cycle_count * 1.0 / seq_size;
            latency_first_element = first_write_time - start_time;
            
            // Update overall metrics
            total_elements_processed = total_elements_processed + seq_size;
            total_execution_time = total_execution_time + exec_time;
            
            $display("============================================================");
            $display("PERFORMANCE METRICS - VERILOG IMPLEMENTATION");
            $display("============================================================");
            $display("Configuration:");
            $display("  - Clock Frequency: %0d MHz", 1000/CLK_PERIOD);
            $display("  - Sequence Parameters: a1=%.2f, d=%.2f, n=%0d", seq_first, seq_diff, seq_size);
            $display("  - Memory Start Address: 0x%h", saddr);
            $display("\nTiming Metrics:");
            $display("  - Total Execution Time: %.3f microseconds", exec_time/1000.0);
            $display("  - First Element Latency: %.3f ns", latency_first_element);
            $display("\nPerformance Metrics:");
            $display("  - Clock Cycles Used: %0d cycles", cycle_count);
            $display("  - Throughput: %.2f million elements/second", throughput);
            $display("  - Cycles per Element: %.3f cycles", cycles_per_element);
            $display("  - Memory Bandwidth: %.2f MB/s", throughput * 4.0);
            $display("============================================================");
        end
    endtask
    
    // Overall performance metrics display task
    task display_overall_metrics;
        real overall_throughput, overall_cycles_per_element;
        begin
            overall_throughput = (total_elements_processed * 1000.0) / total_execution_time;
            
            $display("============================================================");
            $display("OVERALL PERFORMANCE METRICS SUMMARY");
            $display("============================================================");
            $display("  - Total Elements Processed: %0d elements", total_elements_processed);
            $display("  - Total Execution Time: %.3f microseconds", total_execution_time/1000.0);
            $display("  - Average Throughput: %.2f million elements/second", overall_throughput);
            $display("  - Average Memory Bandwidth: %.2f MB/s", overall_throughput * 4.0);
            $display("============================================================");
        end
    endtask
    
    // Test sequence
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        activate = 0;
        a1 = 0;
        d = 0;
        n = 0;
        saddr = 0;
        mem_ready = 0;
        error_count = 0;
        cycle_count = 0;
        first_write_detected = 0;
        total_elements_processed = 0;
        total_execution_time = 0;
        
        // Reset sequence
        #(2*CLK_PERIOD);
        rst_n = 1;
        #(2*CLK_PERIOD);
        
        // Display header
        $display("============================================================");
        $display("Starting FP Arithmetic Sequence Generator Testbench");
        $display("============================================================");
        
        // Test Case 1: Simple sequence (1.0, 2.0, 3.0, 4.0, 5.0)
        $display("\nTest Case 1: a1=1.0, d=1.0, n=5, saddr=0");
        // Initialize expected sequence
        for (i = 0; i < 5; i = i + 1) begin
            expected_terms[i] = float_to_ieee754(1.0 + i * 1.0);
        end
        
        a1 = float_to_ieee754(1.0);  // First term = 1.0
        d = float_to_ieee754(1.0);   // Common difference = 1.0
        n = 5;                       // Number of terms = 5
        saddr = 0;                   // Start address = 0
        
        // Reset metrics
        cycle_count = 0;
        first_write_detected = 0;
        
        // Start sequence generation
        start_time = $time;
        activate = 1;
        
        // Wait for done signal
        while (!done) @(posedge clk);
        end_time = $time;
        $display("Test Case 1 Done signal received");
        
        // Display metrics
        display_metrics(5, 1.0, 1.0, end_time - start_time);
        
        // Verify memory contents
        for (i = 0; i < n; i = i + 1) begin
            if (mem[i] != expected_terms[i]) begin
                $display("Error at memory[%0d]: Expected %f (0x%h), Got %f (0x%h)",
                         i, ieee754_to_float(expected_terms[i]), expected_terms[i],
                         ieee754_to_float(mem[i]), mem[i]);
                error_count = error_count + 1;
            end
        end
        
        // Disable the generator
        activate = 0;
        #(5*CLK_PERIOD);
        
        // Test Case 2: Decreasing sequence (10.0, 9.5, 9.0, 8.5, 8.0)
        $display("\nTest Case 2: a1=10.0, d=-0.5, n=5, saddr=20");
        // Initialize expected sequence
        for (i = 0; i < 5; i = i + 1) begin
            expected_terms[i] = float_to_ieee754(10.0 + i * (-0.5));
        end
        
        a1 = float_to_ieee754(10.0);   // First term = 10.0
        d = float_to_ieee754(-0.5);    // Common difference = -0.5
        n = 5;                         // Number of terms = 5
        saddr = 20;                    // Start address = 20
        
        // Reset metrics
        cycle_count = 0;
        first_write_detected = 0;
        
        // Start sequence generation
        start_time = $time;
        activate = 1;
        
        // Wait for done signal
        while (!done) @(posedge clk);
        end_time = $time;
        $display("Test Case 2 Done signal received");
        
        // Display metrics
        display_metrics(5, 10.0, -0.5, end_time - start_time);
        
        // Verify memory contents
        for (i = 0; i < n; i = i + 1) begin
            if (mem[(saddr/4) + i] != expected_terms[i]) begin
                $display("Error at memory[%0d]: Expected %f (0x%h), Got %f (0x%h)",
                         (saddr/4) + i, ieee754_to_float(expected_terms[i]), expected_terms[i],
                         ieee754_to_float(mem[(saddr/4) + i]), mem[(saddr/4) + i]);
                error_count = error_count + 1;
            end
        end
        
        // Disable the generator
        activate = 0;
        #(5*CLK_PERIOD);
        
        // Test Case 3: Sequence with large values and small difference
        $display("\nTest Case 3: a1=1000.0, d=0.1, n=5, saddr=40");
        // Initialize expected sequence
        for (i = 0; i < 5; i = i + 1) begin
            expected_terms[i] = float_to_ieee754(1000.0 + i * 0.1);
        end
        
        a1 = float_to_ieee754(1000.0);  // First term = 1000.0
        d = float_to_ieee754(0.1);      // Common difference = 0.1
        n = 5;                          // Number of terms = 5
        saddr = 40;                     // Start address = 40
        
        // Reset metrics
        cycle_count = 0;
        first_write_detected = 0;
        
        // Start sequence generation
        start_time = $time;
        activate = 1;
        
        // Wait for done signal
        while (!done) @(posedge clk);
        end_time = $time;
        $display("Test Case 3 Done signal received");
        
        // Display metrics
        display_metrics(5, 1000.0, 0.1, end_time - start_time);
        
        // Verify memory contents
        for (i = 0; i < n; i = i + 1) begin
            if (mem[(saddr/4) + i] != expected_terms[i]) begin
                $display("Error at memory[%0d]: Expected %f (0x%h), Got %f (0x%h)",
                         (saddr/4) + i, ieee754_to_float(expected_terms[i]), expected_terms[i],
                         ieee754_to_float(mem[(saddr/4) + i]), mem[(saddr/4) + i]);
                error_count = error_count + 1;
            end
        end
        
        // Disable the generator
        activate = 0;
        #(5*CLK_PERIOD);
        
        // Test Case 4: Single term sequence
        $display("\nTest Case 4: a1=3.14, d=2.71, n=1, saddr=60");
        a1 = float_to_ieee754(3.14);  // First term = 3.14
        d = float_to_ieee754(2.71);   // Common difference = 2.71 (unused)
        n = 1;                        // Number of terms = 1
        saddr = 60;                   // Start address = 60
        
        // Reset metrics
        cycle_count = 0;
        first_write_detected = 0;
        
        // Start sequence generation
        start_time = $time;
        activate = 1;
        
        // Wait for done signal
        while (!done) @(posedge clk);
        end_time = $time;
        $display("Test Case 4 Done signal received");
        
        // Display metrics
        display_metrics(1, 3.14, 2.71, end_time - start_time);
        
        // Verify memory contents
        if (mem[(saddr/4)] != a1) begin
            $display("Error at memory[%0d]: Expected %f (0x%h), Got %f (0x%h)",
                     (saddr/4), ieee754_to_float(a1), a1,
                     ieee754_to_float(mem[(saddr/4)]), mem[(saddr/4)]);
            error_count = error_count + 1;
        end
        
        // Disable the generator
        activate = 0;
        #(5*CLK_PERIOD);
        
        // Test Case 5: Negative values
        $display("\nTest Case 5: a1=-5.0, d=2.5, n=5, saddr=80");
        // Initialize expected sequence
        for (i = 0; i < 5; i = i + 1) begin
            expected_terms[i] = float_to_ieee754(-5.0 + i * 2.5);
        end
        
        a1 = float_to_ieee754(-5.0);  // First term = -5.0
        d = float_to_ieee754(2.5);    // Common difference = 2.5
        n = 5;                        // Number of terms = 5
        saddr = 80;                   // Start address = 80
        
        // Reset metrics
        cycle_count = 0;
        first_write_detected = 0;
        
        // Start sequence generation
        start_time = $time;
        activate = 1;
        
        // Wait for done signal
        while (!done) @(posedge clk);
        end_time = $time;
        $display("Test Case 5 Done signal received");
        
        // Display metrics
        display_metrics(5, -5.0, 2.5, end_time - start_time);
        
        // Verify memory contents
        for (i = 0; i < n; i = i + 1) begin
            if (mem[(saddr/4) + i] != expected_terms[i]) begin
                $display("Error at memory[%0d]: Expected %f (0x%h), Got %f (0x%h)",
                         (saddr/4) + i, ieee754_to_float(expected_terms[i]), expected_terms[i],
                         ieee754_to_float(mem[(saddr/4) + i]), mem[(saddr/4) + i]);
                error_count = error_count + 1;
            end
        end
        
        // Disable the generator
        activate = 0;
        #(5*CLK_PERIOD);
        
        // Test Case 6: Larger sequence (1000 elements) for performance benchmark
        $display("\nTest Case 6: a1=1.0, d=0.1, n=1000, saddr=100");
        a1 = float_to_ieee754(1.0);   // First term = 1.0
        d = float_to_ieee754(0.1);    // Common difference = 0.1
        n = 1000;                     // Number of terms = 1000
        saddr = 100;                  // Start address = 100
        
        // Reset metrics
        cycle_count = 0;
        first_write_detected = 0;
        
        // Start sequence generation
        start_time = $time;
        activate = 1;
        
        // Wait for done signal
        while (!done) @(posedge clk);
        end_time = $time;
        $display("Test Case 6 Done signal received");
        
        // Display metrics
        display_metrics(1000, 1.0, 0.1, end_time - start_time);
        
        // Disable the generator
        activate = 0;
        #(5*CLK_PERIOD);
        
        // Display overall performance metrics
        display_overall_metrics();
        
        // Final summary
        $display("\n============================================================");
        if (error_count == 0) begin
            $display("TESTBENCH PASSED - All tests completed successfully");
        end else begin
            $display("TESTBENCH FAILED - %0d errors detected", error_count);
        end
        $display("============================================================");
        
        // End simulation
        #(10*CLK_PERIOD);
        $finish;
    end

endmodule
