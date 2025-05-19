// Code your testbench here
// or browse Examples
// Modified testbench for benchmark comparison
`timescale 1ns/1ps

module fp_benchmark_simulation;

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
    
    // Memory model (increased for larger tests)
    reg [31:0] mem [0:1000000]; // Large memory for big sequences
    
    // Performance metrics
    time start_time, end_time;
    integer cycle_count;
    time first_write_time;
    reg first_write_detected;
    time last_write_time;
    real execution_time_ns;
    real throughput;
    
    // Overall performance metrics
    real total_elements_processed;
    time total_execution_time;
    
    // Test variables
    integer i;
    
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
    
    // Run benchmark test
    task run_benchmark;
        input real first_term;
        input real diff;
        input integer num_terms;
        begin
            // Setup parameters
            a1 = float_to_ieee754(first_term);
            d = float_to_ieee754(diff);
            n = num_terms;
            saddr = 0;
            
            // Reset metrics
            cycle_count = 0;
            first_write_detected = 0;
            
            // Start sequence generation
            start_time = $time;
            activate = 1;
            
            // Wait for done signal
            while (!done) @(posedge clk);
            end_time = $time;
            
            // Calculate metrics
            execution_time_ns = end_time - start_time;
            throughput = (num_terms * 1000000000.0) / execution_time_ns; // Million elements per second
            
            // Display results
            $display("n=%d, Time=%0.6f ms, Throughput=%0.2f million elements/s", 
                      num_terms, execution_time_ns/1000000.0, throughput/1000000.0);
            
            // Update totals
            total_elements_processed = total_elements_processed + num_terms;
            total_execution_time = total_execution_time + execution_time_ns;
            
            // Disable the generator
            activate = 0;
            #(5*CLK_PERIOD);
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
        total_elements_processed = 0;
        total_execution_time = 0;
        
        // Reset sequence
        #(2*CLK_PERIOD);
        rst_n = 1;
        #(2*CLK_PERIOD);
        
        // Display header
        $display("===========================================================");
        $display("Benchmark Comparison: a1=1.0, d=0.5, Varying n");
        $display("===========================================================");
        $display("n\tTime (ms)\tThroughput (Million elements/s)");
        
        // Run benchmark tests
        run_benchmark(1.0, 0.5, 100);
        run_benchmark(1.0, 0.5, 1000);
        run_benchmark(1.0, 0.5, 10000);
        run_benchmark(1.0, 0.5, 100000);
        run_benchmark(1.0, 0.5, 1000000);
        run_benchmark(1.0, 0.5, 10000000);
        run_benchmark(1.0, 0.5, 100000000);
        
        // End simulation
        #(10*CLK_PERIOD);
        $finish;
    end

endmodule
