__kernel void asg_parallel(
    const float a1,
    const float d,
    const unsigned int n,
    __global float* output)
{
    // Get the index of the current work item
    unsigned int i = get_global_id(0);

    // Only compute if within range
    if (i < n) {
        output[i] = a1 + i * d;
    }
}
