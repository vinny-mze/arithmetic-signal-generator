`timescale 1ns/1ps

module standalone_asg_memory (
    input wire clk,                  // Clock signal
    input wire rst_n,                // Active-low reset
    input wire start,                // Start signal to begin sequence generation
    input wire [31:0] a1,            // First term
    input wire [31:0] d,             // Common difference
    input wire [31:0] n,             // Number of terms
    
    // Memory interface signals
    output reg mem_write_enable,     // Memory write enable
    output reg [9:0] mem_address,    // Memory address (supports up to 1024 terms)
    output reg [31:0] mem_write_data,// Data to write to memory
    output reg sequence_complete     // Indicates sequence generation and storage is complete
);

    // FSM states
    localparam IDLE = 2'b00;
    localparam GENERATE = 2'b01;
    localparam STORE = 2'b10;
    localparam DONE = 2'b11;
    
    reg [1:0] state;
    reg [31:0] current_term;         // Current term value
    reg [31:0] counter;              // Term counter
    
    // State machine implementation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mem_write_enable <= 1'b0;
            mem_address <= 10'b0;
            mem_write_data <= 32'b0;
            current_term <= 32'b0;
            counter <= 32'b0;
            sequence_complete <= 1'b0;
        end else begin
            // Default values
            mem_write_enable <= 1'b0;
            
            case (state)
                IDLE: begin
                    // Reset sequence state
                    mem_address <= 10'b0;
                    counter <= 32'b0;
                    sequence_complete <= 1'b0;
                    
                    if (start) begin
                        // Initialize first term
                        current_term <= a1;
                        state <= GENERATE;
                    end
                end
                
                GENERATE: begin
                    // Prepare term for storage
                    mem_write_data <= current_term;
                    state <= STORE;
                end
                
                STORE: begin
                    // Write term to memory
                    mem_write_enable <= 1'b1;
                    
                    // Increment counter and update current_term for next iteration
                    counter <= counter + 1'b1;
                    
                    if (counter + 1 < n) begin
                        // Calculate next term
                        current_term <= current_term + d;
                        mem_address <= mem_address + 1'b1;  // Increment address for next term
                        state <= GENERATE;
                    end else begin
                        // This is the last term
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    // All terms have been generated and stored
                    sequence_complete <= 1'b1;
                    
                    // Return to IDLE if start is deasserted
                    if (!start)
                        state <= IDLE;
                end
            endcase
        end
    end
endmodule
