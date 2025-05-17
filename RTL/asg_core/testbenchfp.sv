`timescale 1ns/1ps

module fp_arithmetic_sequence_generator_tb;

    // Parameters
    parameter CLK_PERIOD = 10; // 10ns (100MHz clock)
    
    // Test bench signals
    reg clk;
    reg rst_n;
    reg enable;
    reg [31:0] a1;        // First term
    reg [31:0] d;         // Common difference
    reg [31:0] n;         // Number of terms
    wire [31:0] term;     // Current term
    wire valid;           // Term valid signal
    wire done;            // Sequence complete
    
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
        .enable(enable),
        .a1(a1),
        .d(d),
        .n(n),
        .term(term),
        .valid(valid),
        .done(done)
    );
    
    // Clock generation
    always begin
        #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Task to wait for a valid term
    task wait_for_valid;
    begin
        while (!valid) @(posedge clk);
    end
    endtask
    
    // VCD dump for waveform visualization
    initial begin
        $dumpfile("fp_arithmetic_sequence_generator_tb.vcd");
        $dumpvars(0, fp_arithmetic_sequence_generator_tb);
    end
    
    // Test sequence
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        enable = 0;
        a1 = 0;
        d = 0;
        n = 0;
        error_count = 0;
        
        // Reset sequence
        #(2*CLK_PERIOD);
        rst_n = 1;
        #(2*CLK_PERIOD);
        
        // Display header
        $display("============================================================");
        $display("Starting FP Arithmetic Sequence Generator Testbench");
        $display("============================================================");
        
        // Test Case 1: Simple sequence (1.0, 2.0, 3.0, 4.0, 5.0)
        $display("\nTest Case 1: a1=1.0, d=1.0, n=5");
        // Initialize expected sequence
        for (i = 0; i < 5; i = i + 1) begin
            expected_terms[i] = float_to_ieee754(1.0 + i * 1.0);
        end
        
        a1 = float_to_ieee754(1.0);  // First term = 1.0
        d = float_to_ieee754(1.0);   // Common difference = 1.0
        n = 5;                       // Number of terms = 5
        
        // Start sequence generation
        enable = 1;
        
        // Collect and verify all terms
        for (i = 0; i < n; i = i + 1) begin
            wait_for_valid();
            
            if (term != expected_terms[i]) begin
                $display("Error at term %0d: Expected %f (0x%h), Got %f (0x%h)",
                         i+1, ieee754_to_float(expected_terms[i]), expected_terms[i],
                         ieee754_to_float(term), term);
                error_count = error_count + 1;
            end else begin
                $display("Term %0d: %f (0x%h) - Correct",
                         i+1, ieee754_to_float(term), term);
            end
            
            @(posedge clk); // Wait one clock cycle
        end
        
        // Wait for done signal
        while (!done) @(posedge clk);
        $display("Test Case 1 Done signal received");
        
        // Disable the generator
        enable = 0;
        #(5*CLK_PERIOD);
        
        // Test Case 2: Decreasing sequence (10.0, 9.5, 9.0, 8.5, 8.0)
        $display("\nTest Case 2: a1=10.0, d=-0.5, n=5");
        // Initialize expected sequence
        for (i = 0; i < 5; i = i + 1) begin
            expected_terms[i] = float_to_ieee754(10.0 + i * (-0.5));
        end
        
        a1 = float_to_ieee754(10.0);   // First term = 10.0
        d = float_to_ieee754(-0.5);    // Common difference = -0.5
        n = 5;                         // Number of terms = 5
        
        // Start sequence generation
        enable = 1;
        
        // Collect and verify all terms
        for (i = 0; i < n; i = i + 1) begin
            wait_for_valid();
            
            if (term != expected_terms[i]) begin
                $display("Error at term %0d: Expected %f (0x%h), Got %f (0x%h)",
                         i+1, ieee754_to_float(expected_terms[i]), expected_terms[i],
                         ieee754_to_float(term), term);
                error_count = error_count + 1;
            end else begin
                $display("Term %0d: %f (0x%h) - Correct",
                         i+1, ieee754_to_float(term), term);
            end
            
            @(posedge clk); // Wait one clock cycle
        end
        
        // Wait for done signal
        while (!done) @(posedge clk);
        $display("Test Case 2 Done signal received");
        
        // Disable the generator
        enable = 0;
        #(5*CLK_PERIOD);
        
        // Test Case 3: Sequence with large values and small difference
        $display("\nTest Case 3: a1=1000.0, d=0.1, n=5");
        // Initialize expected sequence
        for (i = 0; i < 5; i = i + 1) begin
            expected_terms[i] = float_to_ieee754(1000.0 + i * 0.1);
        end
        
        a1 = float_to_ieee754(1000.0);  // First term = 1000.0
        d = float_to_ieee754(0.1);      // Common difference = 0.1
        n = 5;                          // Number of terms = 5
        
        // Start sequence generation
        enable = 1;
        
        // Collect and verify all terms
        for (i = 0; i < n; i = i + 1) begin
            wait_for_valid();
            
            if (term != expected_terms[i]) begin
                $display("Error at term %0d: Expected %f (0x%h), Got %f (0x%h)",
                         i+1, ieee754_to_float(expected_terms[i]), expected_terms[i],
                         ieee754_to_float(term), term);
                error_count = error_count + 1;
            end else begin
                $display("Term %0d: %f (0x%h) - Correct",
                         i+1, ieee754_to_float(term), term);
            end
            
            @(posedge clk); // Wait one clock cycle
        end
        
        // Wait for done signal
        while (!done) @(posedge clk);
        $display("Test Case 3 Done signal received");
        
        // Disable the generator
        enable = 0;
        #(5*CLK_PERIOD);
        
        // Test Case 4: Single term sequence
        $display("\nTest Case 4: a1=3.14, d=2.71, n=1");
        a1 = float_to_ieee754(3.14);  // First term = 3.14
        d = float_to_ieee754(2.71);   // Common difference = 2.71 (unused)
        n = 1;                        // Number of terms = 1
        
        // Start sequence generation
        enable = 1;
        
        // Wait for valid term
        wait_for_valid();
        
        if (term != a1) begin
            $display("Error at term 1: Expected %f (0x%h), Got %f (0x%h)",
                     ieee754_to_float(a1), a1, ieee754_to_float(term), term);
            error_count = error_count + 1;
        end else begin
            $display("Term 1: %f (0x%h) - Correct", ieee754_to_float(term), term);
        end
        
        // Wait for done signal
        while (!done) @(posedge clk);
        $display("Test Case 4 Done signal received");
        
        // Disable the generator
        enable = 0;
        #(5*CLK_PERIOD);
        
        // Test Case 5: Negative values
        $display("\nTest Case 5: a1=-5.0, d=2.5, n=5");
        // Initialize expected sequence
        for (i = 0; i < 5; i = i + 1) begin
            expected_terms[i] = float_to_ieee754(-5.0 + i * 2.5);
        end
        
        a1 = float_to_ieee754(-5.0);  // First term = -5.0
        d = float_to_ieee754(2.5);    // Common difference = 2.5
        n = 5;                        // Number of terms = 5
        
        // Start sequence generation
        enable = 1;
        
        // Collect and verify all terms
        for (i = 0; i < n; i = i + 1) begin
            wait_for_valid();
            
            if (term != expected_terms[i]) begin
                $display("Error at term %0d: Expected %f (0x%h), Got %f (0x%h)",
                         i+1, ieee754_to_float(expected_terms[i]), expected_terms[i],
                         ieee754_to_float(term), term);
                error_count = error_count + 1;
            end else begin
                $display("Term %0d: %f (0x%h) - Correct",
                         i+1, ieee754_to_float(term), term);
            end
            
            @(posedge clk); // Wait one clock cycle
        end
        
        // Wait for done signal
        while (!done) @(posedge clk);
        $display("Test Case 5 Done signal received");
        
        // Disable the generator
        enable = 0;
        #(5*CLK_PERIOD);
        
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
    
    // Additional test to check reset during operation
    initial begin
        // Wait until the first test case has started
        wait(enable == 1);
        #(30*CLK_PERIOD);
        
        // Apply reset in the middle of a sequence
        $display("\nTesting reset during operation");
        rst_n = 0;
        #(2*CLK_PERIOD);
        rst_n = 1;
        #(5*CLK_PERIOD);
        
        // The main test sequence will continue after reset
    end
    
    // Monitor signals
    initial begin
        $monitor("Time=%0t, State: enable=%b, valid=%b, done=%b", 
                 $time, enable, valid, done);
    end

endmodule
