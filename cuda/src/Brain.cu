#include <stdio.h>
#include <cuda.h>
#include <curand_kernel.h>
#include "Synapse.h"
#include "BrainSetup.h"
#include "Visualize.h"
#include "Compute.h"
#include "Hyperparameters.h"
#include "Parameters.h"
#include "TensorboardInterface.h"

dim3 block_dim(512, 1, 1);
dim3 grid_dim((NUM_NEURONS + block_dim.x - 1) / block_dim.x);
curandState_t *d_curand_state;

struct Parameters *d_parameters;
struct Synapse *d_synapses;
size_t synapses_pitch;
int *d_neuron_outputs;
float *d_weighted_sums;
int *d_brain_inputs;
unsigned long iteration_counter = 0;


int init(const char *log_dir){
    //initialize tensorboard event writer
    init_events_writer(log_dir);
    //mark output start
    printf("\n#################################################################################################");
    printf("\n#################################################################################################");
    printf("\nsynapses memory usage: %zu Bytes", sizeof(struct Synapse) * NUM_NEURONS * NUM_SYNAPSES_PER_NEURON);
    printf("\nnum_neurons: %d block size: %d grid size: %d", NUM_NEURONS, block_dim.x, grid_dim.x);
    printf("\nnum inputs: %d  num outputs: %d", NUM_INPUTS, NUM_OUTPUTS);
    if(NUM_OUTPUTS > NUM_NEURONS){
        printf("Error: NUM_OUTPUTS is greater than NUM_NEURONS. This is not possible");
        return -1;
    }
    
    cudaMalloc(&d_curand_state, sizeof(curandState_t) * NUM_NEURONS);
    init_random_seed<<<grid_dim, block_dim>>>(time(NULL), d_curand_state);
    //allocate memory on the device
    cudaMalloc(&d_parameters, sizeof(struct Parameters));
    cudaMalloc(&d_brain_inputs, sizeof(int) * NUM_INPUTS);
    cudaMalloc(&d_weighted_sums, sizeof(float) * NUM_NEURONS);
    cudaMalloc(&d_neuron_outputs, sizeof(int) * NUM_NEURONS);
    cudaMallocPitch(&d_synapses, &synapses_pitch, NUM_SYNAPSES_PER_NEURON * sizeof(struct Synapse), NUM_NEURONS);

    struct Parameters start_parameters;
    start_parameters.threshold_randomness_factor = THRESHOLD_RANDOMNESS_FACTOR_START;
    cudaMemcpy(d_parameters, &start_parameters, sizeof(struct Parameters), cudaMemcpyHostToDevice);
    // initialize brain
    init_synapses<<<grid_dim, block_dim>>>(d_synapses, synapses_pitch, d_neuron_outputs, d_brain_inputs, d_curand_state);
    
    return 0;
}


int* think(int *inputs){
    //set brain inputs
    cudaMemcpy(d_brain_inputs, inputs, sizeof(int) * NUM_INPUTS, cudaMemcpyHostToDevice);

    //read
    update_parameters<<<1, 1>>>(d_parameters);
    read<<<grid_dim, block_dim>>>(d_synapses, synapses_pitch);
    cudaDeviceSynchronize();
    
    //compute
    compute<<<grid_dim, block_dim>>>(d_synapses, d_neuron_outputs, synapses_pitch, d_curand_state, d_parameters);

    cudaDeviceSynchronize();

    if(iteration_counter % 10 == 0){
        //show info
        //printf("iteration: %ld\n", iteration_counter);
        //float avr_neuron_output;
        //float* d_avr_neuron_output;
        //cudaMalloc(&d_avr_neuron_output, sizeof(float));
        neuron_stats(d_neuron_outputs, iteration_counter);
        synapse_stats(d_synapses, synapses_pitch, iteration_counter);
        //cudaMemcpy(&avr_neuron_output, d_avr_neuron_output, sizeof(float), cudaMemcpyDeviceToHost);
        //cudaFree(d_avr_neuron_output);
        //printf("Received avr?neuron output form device: %.2f", avr_neuron_output);
        
        //print_synapse_stats<<<grid_dim, block_dim>>>(d_synapses, synapses_pitch);
        //printSynapses<<<grid_dim, block_dim>>>(d_synapses, synapses_pitch);
        //print_parameters<<<1, 1>>>(d_parameters);
    }
    
    //get brain outputs
    int *outputs = (int*) malloc(sizeof(int) * NUM_OUTPUTS);
    cudaMemcpy(outputs, d_neuron_outputs, sizeof(int) * NUM_OUTPUTS, cudaMemcpyDeviceToHost);
    iteration_counter++;
    return outputs;
}

void process_reward(float reward){
    learn<<<grid_dim, block_dim>>>(d_synapses, reward, synapses_pitch, d_neuron_outputs, d_brain_inputs, d_curand_state);
    write_scalar(iteration_counter, reward, "reward");
}

void reset_memory(){
    reset_synapses<<<grid_dim, block_dim>>>(d_synapses, d_weighted_sums, synapses_pitch);
}

void release_memory(){
    cudaFree(d_brain_inputs);
    cudaFree(d_neuron_outputs);
    cudaFree(d_synapses);
    cudaFree(d_weighted_sums);
}

void write_tensorboard()
{
    printf("\nwriting to tensorboard");
    write_histogram(0, "test_by_alex");
}