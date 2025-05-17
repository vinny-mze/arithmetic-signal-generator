`timescale 1ns/1ps  // Sets simulation time units (1ns) and precision (1ps)

// IEEE-754 single precision floating-point arithmetic sequence generator
// Generates sequence a(n) = a1 + (n-1)d and stores in memory
module fp_arithmetic_sequence_generator (
    input wire clk,                  // Clock signal (for synchronous operation)
    input wire rst_n,                // Active-low reset (asynchronous)
    input wire activate,             // Pulse high to start sequence generation
    input wire [31:0] a1,            // First term (IEEE-754 single precision)
    input wire [31:0] d,             // Common difference (IEEE-754 single precision)
    input wire [31:0] n,             // Number of terms (32-bit unsigned integer)
    input wire [31:0] saddr,         // Starting memory address for results
    output reg done,                 // High when sequence generation complete
    
    // Memory interface signals (typical wishbone-like)
    output reg [31:0] mem_addr,      // Memory address (byte addressable)
    output reg [31:0] mem_wdata,     // Data to write to memory
    output reg mem_write,            // Write enable signal
    input wire mem_ready             // Memory ready signal (handshake)
);

    // State definitions for main control FSM
    localparam IDLE = 3'b000;       // Waiting for activation
    localparam INIT = 3'b001;       // Initialize sequence parameters
    localparam LOAD_ADD = 3'b010;   // Setup floating-point addition
    localparam WAIT_ADD = 3'b011;   // Wait for adder completion
    localparam MEM_WRITE = 3'b100;  // Initiate memory write
    localparam WAIT_MEM = 3'b101;   // Wait for memory ready
    localparam UPDATE = 3'b110;     // Update state (not currently used)
    localparam FINISH = 3'b111;     // Sequence generation complete
    
    reg [2:0] state;                // Current state of FSM
    reg [31:0] counter;             // Term counter (0 to n-1)
    reg [31:0] current_term;        // Current term being processed
    
    // Floating-point adder interface signals
    reg [31:0] add_a, add_b;       // Operands for adder
    reg add_start;                  // Pulse to start addition
    wire [31:0] add_result;         // Result from adder
    wire add_done;                  // Adder completion signal
    
    // Instantiate IEEE-754 floating-point adder module
    fp_adder fp_add_inst (
        .clk(clk),
        .rst_n(rst_n),
        .a(add_a),
        .b(add_b),
        .start(add_start),
        .result(add_result),
        .done(add_done)
    );
    
    // Main control state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Asynchronous reset - initialize all registers
            state <= IDLE;
            counter <= 32'b0;
            current_term <= 32'b0;
            done <= 1'b0;
            add_start <= 1'b0;
            add_a <= 32'b0;
            add_b <= 32'b0;
            mem_addr <= 32'b0;
            mem_wdata <= 32'b0;
            mem_write <= 1'b0;
        end else begin
            // Default assignments (avoid latches)
            add_start <= 1'b0;
            mem_write <= 1'b0;
            
            case (state)
                IDLE: begin
                    // Wait for activation signal
                    counter <= 32'b0;
                    done <= 1'b0;
                    
                    if (activate) begin
                        state <= INIT;  // Start sequence generation
                    end
                end
                
                INIT: begin
                    // Initialize sequence parameters
                    current_term <= a1;         // Store first term
                    counter <= 32'b0;           // Reset term counter
                    mem_addr <= saddr;          // Set starting address
                    state <= MEM_WRITE;         // Write first term to memory
                end
                
                LOAD_ADD: begin
                    // Setup next floating-point addition: current_term + d
                    add_a <= current_term;
                    add_b <= d;
                    add_start <= 1'b1;          // Trigger adder
                    state <= WAIT_ADD;
                end
                
                WAIT_ADD: begin
                    // Wait for adder to complete (critical path for benchmarking)
                    if (add_done) begin
                        state <= MEM_WRITE;     // Proceed to store result
                    end
                end
                
                MEM_WRITE: begin
                    // Store result in memory (either a1 or calculated term)
                    mem_wdata <= (counter == 0) ? a1 : add_result;
                    mem_write <= 1'b1;          // Initiate write
                    state <= WAIT_MEM;
                end
                
                WAIT_MEM: begin
                    // Wait for memory to acknowledge write
                    if (mem_ready) begin
                        mem_addr <= mem_addr + 4; // Increment address (32-bit words)
                        counter <= counter + 1'b1; // Increment term counter
                        
                        if (counter == 0) begin
                            // Special case: first term already stored
                            current_term <= a1;
                            state <= LOAD_ADD;  // Calculate next term
                        end else if (counter >= (n - 1)) begin
                            // All terms generated
                            state <= FINISH;
                        end else begin
                            // Update current term and continue
                            current_term <= add_result;
                            state <= LOAD_ADD;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;              // Signal completion
                    
                    if (!activate) begin
                        state <= IDLE;         // Ready for next sequence
                    end
                end
                
                default: state <= IDLE;        // Handle undefined states
            endcase
        end
    end
endmodule

// IEEE-754 single precision floating-point adder
module fp_adder (
    input wire clk,
    input wire rst_n,
    input wire [31:0] a,        // Input operand A
    input wire [31:0] b,        // Input operand B
    input wire start,           // Start signal (pulse)
    output reg [31:0] result,   // Addition result
    output reg done             // Completion signal
);
    // IEEE-754 single precision format breakdown:
    // [31]    - Sign bit (1 = negative)
    // [30:23] - Exponent (8 bits, biased by 127)
    // [22:0]  - Mantissa (23 bits, with implied leading 1)
    
    // Internal registers
    reg [31:0] a_reg, b_reg;   // Registered inputs
    reg a_sign, b_sign;         // Sign bits
    reg [7:0] a_exp, b_exp;     // Exponents
    reg [23:0] a_mant, b_mant;  // Mantissas (24 bits with hidden bit)
    reg [7:0] result_exp;       // Result exponent
    reg result_sign;            // Result sign
    reg [24:0] result_mant;     // Result mantissa (25 bits for carry)
    reg [7:0] exp_diff;         // Exponent difference
    
    // Adder state machine states
    localparam IDLE = 8'h0;      // Waiting for start
    localparam UNPACK = 8'h1;    // Unpack IEEE-754 format
    localparam ALIGN = 8'h2;     // Align mantissas
    localparam ADD = 8'h3;       // Perform addition
    localparam NORMALIZE = 8'h4; // Normalize result
    localparam PACK = 8'h5;      // Pack into IEEE-754
    
    // Main adder state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'b0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;  // Default done signal
            
            case (state)
                IDLE: begin
                    if (start) begin
                        a_reg <= a;  // Register inputs
                        b_reg <= b;
                        state <= UNPACK;
                    end
                end
                
                UNPACK: begin
                    // Extract IEEE-754 components
                    a_sign <= a_reg[31];
                    a_exp <= a_reg[30:23];
                    a_mant <= {1'b1, a_reg[22:0]};  // Add hidden bit
                    
                    b_sign <= b_reg[31];
                    b_exp <= b_reg[30:23];
                    b_mant <= {1'b1, b_reg[22:0]};  // Add hidden bit
                    
                    state <= ALIGN;
                end
                
                ALIGN: begin
                    // Align mantissas by shifting the smaller one
                    if (a_exp > b_exp) begin
                        exp_diff <= a_exp - b_exp;
                        b_mant <= (exp_diff > 24) ? 24'b0 : (b_mant >> exp_diff);
                        result_exp <= a_exp;
                    end else begin
                        exp_diff <= b_exp - a_exp;
                        a_mant <= (exp_diff > 24) ? 24'b0 : (a_mant >> exp_diff);
                        result_exp <= b_exp;
                    end
                    state <= ADD;
                end
                
                ADD: begin
                    // Core addition/subtraction logic
                    if (a_sign == b_sign) begin
                        // Same sign: add mantissas
                        result_mant <= a_mant + b_mant;
                        result_sign <= a_sign;
                    end else begin
                        // Different signs: subtract smaller from larger
                        if (a_mant >= b_mant) begin
                            result_mant <= a_mant - b_mant;
                            result_sign <= a_sign;
                        end else begin
                            result_mant <= b_mant - a_mant;
                            result_sign <= b_sign;
                        end
                    end
                    state <= NORMALIZE;
                end
                
                NORMALIZE: begin
                    // Normalize to IEEE-754 format
                    if (result_mant[24]) begin
                        // Overflow case: shift right and adjust exponent
                        result_mant <= result_mant >> 1;
                        result_exp <= result_exp + 1;
                        state <= PACK;
                    end else if (result_mant[23:0] != 0) begin
                        // Find leading 1 (simplified - real impl would use priority encoder)
                        if (!result_mant[23]) begin
                            result_mant <= result_mant << 1;
                            result_exp <= result_exp - 1;
                            // Stay in NORMALIZE state until normalized
                        end else begin
                            state <= PACK;
                        end
                    end else begin
                        // Zero result
                        result_exp <= 8'b0;
                        state <= PACK;
                    end
                end
                
                PACK: begin
                    // Combine components into IEEE-754 format
                    result <= {result_sign, result_exp, result_mant[22:0]};
                    done <= 1'b1;  // Signal completion
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
