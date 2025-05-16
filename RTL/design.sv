`timescale 1ns/1ps
module simple_asg (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [31:0] a1,    // First term (integer)
    input wire [31:0] d,     // Common difference (integer)
    input wire [31:0] n,     // Number of terms
    output reg signed [31:0] term,  // Current term output
    output reg valid,        // Term valid signal
    output reg done          // Sequence complete
);
    reg [31:0] current_term;
    reg [31:0] counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_term <= 0;
            counter <= 0;
            term <= 0;
            valid <= 0;
            done <= 0;
        end else begin
            if (enable) begin
                // Default state for valid 
                valid <= 0;
                
                if (counter == 0) begin
                    // First term
                    current_term <= a1;
                    term <= a1;
                    valid <= 1;
                    counter <= counter + 1;
                end else if (counter < n) begin
                    // Subsequent terms
                    current_term <= current_term + d;
                    term <= current_term + d;
                    valid <= 1;
                    counter <= counter + 1;
                end
                
                // Check if sequence is complete
                if (counter >= n && !done) begin
                    done <= 1;
                end
            end else begin
                // When disabled, reset counters and status signals
                counter <= 0;
                valid <= 0;
                done <= 0;
            end
        end
    end
endmodule