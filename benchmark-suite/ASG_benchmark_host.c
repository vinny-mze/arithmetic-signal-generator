#define CL_TARGET_OPENCL_VERSION 220

#include <stdio.h>
#include <stdlib.h>
#include <CL/cl.h>
#include <sys/time.h>

#define MAX_SOURCE_SIZE (0x100000)

double get_current_time() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + tv.tv_usec * 1e-6;
}

void check_error(cl_int err, const char* msg) {
    if (err != CL_SUCCESS) {
        fprintf(stderr, "Error: %s (%d)\n", msg, err);
        exit(EXIT_FAILURE);
    }
}

int main(int argc, char** argv) {
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <a1> <d> <n>\n", argv[0]);
        return 1;
    }

    float a1 = atof(argv[1]);
    float d = atof(argv[2]);
    unsigned int n = atoi(argv[3]);

    if (n == 0) {
        fprintf(stderr, "Error: 'n' must be greater than 0.\n");
        return 1;
    }

    FILE* fp = fopen("ASG_benchmark.cl", "r");
    if (!fp) {
        fprintf(stderr, "Failed to load kernel file.\n");
        return 1;
    }

    char* source_str = (char*)malloc(MAX_SOURCE_SIZE);
    size_t source_size = fread(source_str, 1, MAX_SOURCE_SIZE, fp);
    fclose(fp);

    cl_int ret;
    cl_platform_id platform_id = NULL;
    cl_device_id device_id = NULL;
    cl_uint ret_num_devices, ret_num_platforms;

    ret = clGetPlatformIDs(1, &platform_id, &ret_num_platforms);
    check_error(ret, "Getting platform ID");

    ret = clGetDeviceIDs(platform_id, CL_DEVICE_TYPE_GPU, 1, &device_id, &ret_num_devices);
    if (ret != CL_SUCCESS) {
        printf("Using CPU as fallback\n");
        ret = clGetDeviceIDs(platform_id, CL_DEVICE_TYPE_CPU, 1, &device_id, &ret_num_devices);
        check_error(ret, "Getting CPU device ID");
    }

    cl_context context = clCreateContext(NULL, 1, &device_id, NULL, NULL, &ret);
    check_error(ret, "Creating context");

    cl_command_queue_properties props[] = {CL_QUEUE_PROPERTIES, CL_QUEUE_PROFILING_ENABLE, 0};
    cl_command_queue command_queue = clCreateCommandQueueWithProperties(context, device_id, props, &ret);
    check_error(ret, "Creating command queue");

    cl_mem output_mem_obj = clCreateBuffer(context, CL_MEM_WRITE_ONLY, n * sizeof(float), NULL, &ret);
    check_error(ret, "Creating output buffer");

    cl_program program = clCreateProgramWithSource(context, 1, (const char**)&source_str, &source_size, &ret);
    check_error(ret, "Creating program");

    ret = clBuildProgram(program, 1, &device_id, NULL, NULL, NULL);
    if (ret != CL_SUCCESS) {
        size_t log_size;
        clGetProgramBuildInfo(program, device_id, CL_PROGRAM_BUILD_LOG, 0, NULL, &log_size);
        char* log = (char*)malloc(log_size);
        clGetProgramBuildInfo(program, device_id, CL_PROGRAM_BUILD_LOG, log_size, log, NULL);
        fprintf(stderr, "Kernel build error:\n%s\n", log);
        free(log);
        return 1;
    }

    cl_kernel kernel = clCreateKernel(program, "asg_parallel", &ret);
    check_error(ret, "Creating kernel");

    check_error(clSetKernelArg(kernel, 0, sizeof(float), &a1), "Setting arg 0");
    check_error(clSetKernelArg(kernel, 1, sizeof(float), &d), "Setting arg 1");
    check_error(clSetKernelArg(kernel, 2, sizeof(unsigned int), &n), "Setting arg 2");
    check_error(clSetKernelArg(kernel, 3, sizeof(cl_mem), &output_mem_obj), "Setting arg 3");

    size_t local_item_size = (n < 64) ? n : 64;
    size_t global_item_size = ((n + local_item_size - 1) / local_item_size) * local_item_size;

    cl_event event;
    double start_time = get_current_time();

    ret = clEnqueueNDRangeKernel(command_queue, kernel, 1, NULL, &global_item_size, &local_item_size, 0, NULL, &event);
    check_error(ret, "Enqueueing kernel");

    clFinish(command_queue);
    double end_time = get_current_time();

    cl_ulong time_start, time_end;
    clGetEventProfilingInfo(event, CL_PROFILING_COMMAND_START, sizeof(time_start), &time_start, NULL);
    clGetEventProfilingInfo(event, CL_PROFILING_COMMAND_END, sizeof(time_end), &time_end, NULL);
    double kernel_time = (time_end - time_start) * 1e-9;

    float* output = (float*)malloc(n * sizeof(float));
    check_error(clEnqueueReadBuffer(command_queue, output_mem_obj, CL_TRUE, 0, n * sizeof(float), output, 0, NULL, NULL), "Reading buffer");

    printf("OpenCL Implementation Results:\n");
    printf("Total elements: %u\n", n);
    printf("Total wall time: %.6f seconds\n", end_time - start_time);
    printf("Kernel execution time: %.6f seconds\n", kernel_time);
    printf("Throughput: %.2f million elements/second\n", n / (kernel_time * 1e6));

    printf("\nFirst 5 elements: ");
    for (int i = 0; i < 5 && i < n; i++) printf("%.2f ", output[i]);

    printf("\nLast 5 elements: ");
    for (int i = (n > 5 ? n - 5 : 0); i < n; i++) printf("%.2f ", output[i]);
    printf("\n");

    free(output);
    free(source_str);
    clReleaseMemObject(output_mem_obj);
    clReleaseProgram(program);
    clReleaseKernel(kernel);
    clReleaseCommandQueue(command_queue);
    clReleaseContext(context);

    return 0;
}
