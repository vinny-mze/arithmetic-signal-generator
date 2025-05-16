def arithmetic_sequence_generator(a1, d, n):
    """
    Generate an arithmetic sequence with first term a1, common difference d, for n terms.
    
    Parameters:
    a1 (int): First term of the sequence (32-bit integer in fixed-point format)
    d (int): Common difference (32-bit integer in fixed-point format)
    n (int): Number of terms to generate
    
    Returns:
    list: List containing n terms of the arithmetic sequence
    """
    sequence = []
    current_term = a1
    
    for i in range(n):
        sequence.append(current_term)
        current_term = current_term + d
    
    return sequence

# Example usage
if __name__ == "__main__":
    # Parameters using 32-bit integers (same as Verilog implementation)
    a1 = 100    # First term
    d = 50      # Common difference
    n = 10      # Number of terms
    
    # Generate sequence
    sequence = arithmetic_sequence_generator(a1, d, n)
    print("Arithmetic sequence:")
    for i, term in enumerate(sequence):
        print(f"Term {i+1}: {term}")
