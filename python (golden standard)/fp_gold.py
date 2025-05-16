def arithmetic_sequence_generator(a1, d, n):
    """
    Generate an arithmetic sequence with first term a1, common difference d, for n terms.

    Parameters:
    a1 (float): First term of the sequence
    d (float): Common difference
    n (int): Number of terms to generate

    Returns:
    list: List containing n terms of the arithmetic sequence
    """
    sequence = []

    for i in range(n):
        term = a1 + i * d
        sequence.append(term)

    return sequence
def fixed_point_q16_16(value):
    """
    Convert a floating-point value to Q16.16 fixed-point representation

    Parameters:
    value (float): Floating-point value to convert

    Returns:
    int: Q16.16 fixed-point representation (32-bit integer)
    """
    # Scale by 2^16 and round to nearest integer
    fixed_point = int(round(value * 65536))
    return fixed_point
def q16_16_to_float(fixed_point):
    """
    Convert a Q16.16 fixed-point value back to floating-point

    Parameters:
    fixed_point (int): Q16.16 fixed-point value (32-bit integer)

    Returns:
    float: Corresponding floating-point value
    """
    # Handle sign properly
    if fixed_point >= 231:  # Negative number in two's complement
        fixed_point = fixed_point - 232

    # Scale back by dividing by 2^16
    return fixed_point / 65536.0
def fixed_point_asg(a1_float, d_float, n):
    """
    Generate arithmetic sequence using Q16.16 fixed-point arithmetic
    to simulate hardware behavior

    Parameters:
    a1_float (float): First term of the sequence
    d_float (float): Common difference
    n (int): Number of terms to generate

    Returns:
    list: List containing n terms as floating-point values
    """
    # Convert inputs to fixed-point
    a1 = fixed_point_q16_16(a1_float)
    d = fixed_point_q16_16(d_float)

    sequence = []
    current_term = a1

    # Generate sequence using only fixed-point arithmetic
    for i in range(n):
        # Store the current term converted back to float
        sequence.append(q16_16_to_float(current_term))

        # Calculate next term using fixed-point addition
        current_term = current_term + d

    return sequence
# Example usage and validation
if name == "main":
    # Parameters
    a1 = 1.0    # First term
    d = 0.5     # Common difference
    n = 10      # Number of terms

    # Generate sequence using floating-point (ideal case)
    float_sequence = arithmetic_sequence_generator(a1, d, n)
    print("Floating-point sequence:")
    print(float_sequence)

    # Generate sequence using fixed-point arithmetic (hardware simulation)
    fixed_sequence = fixed_point_asg(a1, d, n)
    print("\nFixed-point Q16.16 sequence:")
    print(fixed_sequence)

    # Compare results to show any precision differences
    print("\nDifference between floating-point and fixed-point:")
    for i in range(n):
        diff = float_sequence[i] - fixed_sequence[i]
        print(f"Term {i+1}: {diff:.10f}")

    # Time measurement for performance comparison
    import time

    # Measure time for a larger sequence to simulate hardware performance baseline
    large_n = 1000000

    start_time = time.time()
    arithmetic_sequence_generator(a1, d, large_n)
    float_time = time.time() - start_time

    start_time = time.time()
    fixed_point_asg(a1, d, large_n)
    fixed_time = time.time() - start_time

    print(f"\nTime to generate {large_n} terms:")
    print(f"Floating-point: {float_time:.6f} seconds")
    print(f"Fixed-point:    {fixed_time:.6f} seconds")
