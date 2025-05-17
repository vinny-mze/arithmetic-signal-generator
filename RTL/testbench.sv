`timescale 1ns/1ps
module testbench;
    reg clk;
    reg rst_n;
    reg enable;
    reg [31:0] a1;
    reg [31:0] d;
    reg [31:0] n;
    wire [31:0] term;
    
    wire valid;
    wire done;
    
    // Instantiate the simplified ASG
    simple_asg dut (
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
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test sequence
    initial begin
        // Initialize signals
        rst_n = 0;
        enable = 0;
        a1 = 0;
        d = 0;
        n = 0;
        
        // Reset
        #20;
        rst_n = 1;
        
        // Test case 1: Simple sequence 1, 3, 5, 7 (4 terms)
        #10;
        $display("\n----- Test case 1: Simple sequence 1, 3, 5, 7 (4 terms) -----");
        a1 = 1;
        d = 2;
        n = 4;
        enable = 1;
        
        // Wait for completion
        wait(done);
        #20;
        enable = 0;
        
        // Test case 2: Sequence 10, 7, 4, 1, -2 (5 terms)
        #20;
        $display("\n----- Test case 2: Sequence 10, 7, 4, 1, -2 (5 terms) -----");
        a1 = 10;
        d = -3;
        n = 5;
        enable = 1;
        
        // Wait for completion
        wait(done);
        #20;
        enable = 0;
        
        #20;
        $display("\nSimulation complete");
        $finish;
    end
    
    // Monitor outputs with improved tracking and formatting
    integer term_count = 0;  // Add term counter to track sequence progression
    reg prev_done = 0;       // Track previous done state to detect rising edge
    
    always @(posedge clk) begin
        if (valid) begin
            $display("Term %0d: %0d", term_count, $signed(term));
            term_count = term_count + 1;
        end
        
        // Detect rising edge of done signal
        if (done && !prev_done) begin
            $display("Sequence generation complete - Generated %0d terms\n", term_count);
            term_count = 0;  // Reset term counter for next sequence
        end
        
        prev_done = done;  // Update previous done state
    end
    
    // Waveform dumping for visualization
    initial begin
        $dumpfile("simple_asg.vcd");
        $dumpvars(0, testbench);
    end
endmodule