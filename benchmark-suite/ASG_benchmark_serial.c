#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>

// Function to generate arithmetic series
void generate_arithmetic_series(float a1, float d, unsigned int n, float* output) {
    for (unsigned int i = 0; i < n; i++) {
        output[i] = a1 + i * d;
    }
}

// High-resolution timer
double get_current_time() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + tv.tv_usec * 1e-6;
}

int main(int argc, char** argv) {
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <a1> <d> <n>\n", argv[0]);
        return 1;
    }

    float a1 = atof(argv[1]);
    float d = atof(argv[2]);
    unsigned int n = atoi(argv[3]);

    // Allocate memory for the output
    float* output = (float*)malloc(n * sizeof(float));
    if (output == NULL) {
        fprintf(stderr, "Memory allocation failed\n");
        return 1;
    }

    // Time the generation
    double start_time = get_current_time();
    generate_arithmetic_series(a1, d, n, output);
    double end_time = get_current_time();

    // Calculate performance metrics
    double total_time = end_time - start_time;
    double throughput = n / (total_time * 1e6); // million elements per second

    // Print results
    printf("Serial Implementation Results:\n");
    printf("Total elements: %u\n", n);
    printf("Total time: %.6f seconds\n", total_time);
    printf("Throughput: %.2f million elements/second\n", throughput);
    
    // Print first and last 5 elements for verification
    printf("\nFirst 5 elements: ");
    for (int i = 0; i < 5 && i < n; i++) printf("%.2f ", output[i]);
    printf("\nLast 5 elements: ");
    for (int i = n > 5 ? n - 5 : 0; i < n; i++) printf("%.2f ", output[i]);
    printf("\n");

    // Clean up
    free(output);
    return 0;
}
