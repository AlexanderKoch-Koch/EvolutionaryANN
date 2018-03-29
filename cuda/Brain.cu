#include <stdio.h>
#include <cuda.h>
#include <curand_kernel.h>
#include "Synapse.h"
#include "BrainSetup.h"
#include "Visualize.h"
#include "Compute.h"
#include "Hyperparameters.h"
#include "CudaError.h"

dim3 block_dim(256, 1, 1);
dim3 grid_dim((NUM_NEURONS + block_dim.x - 1) / block_dim.x);
size_t dev_pitch;
struct Synapse *d_synapses;
int *d_neuron_outputs;
float *d_weighted_sums;
int *d_brain_inputs;
curandState_t *d_curand_state;

void init(){
    printf("num_neurons: %d block size: %d grid size: %d", NUM_NEURONS, block_dim.x, grid_dim.x);
    cudaMalloc(&d_curand_state, sizeof(curandState_t));
    init_random_seed<<<1, 1>>>(1, d_curand_state);
    //allocate memory on the device
    cudaMalloc(&d_brain_inputs, sizeof(int) * NUM_INPUTS);
    cudaMalloc(&d_weighted_sums, sizeof(float) * NUM_NEURONS);
    cudaMalloc(&d_neuron_outputs, sizeof(int) * NUM_NEURONS);
    cudaMallocPitch(&d_synapses, &dev_pitch, NUM_SYNAPSES_PER_NEURON * sizeof(struct Synapse), NUM_NEURONS);
    
    // initialize brain
    CudaCheckError();
    init_synapses<<<grid_dim, block_dim>>>(d_synapses, dev_pitch, d_neuron_outputs, d_brain_inputs, d_curand_state);
    CudaCheckError();
    //init_neurons<<<grid_dim, block_dim>>>(d_neuron_outputs, d_weighted_sums);
    cudaDeviceSynchronize();
    
    //printSynapses<<<1, synapses_dim>>>(d_synapses, dev_pitch);
    //printNeurons<<<grid_dim, block_dim>>>(d_neuron_outputs, d_weighted_sums);
    cudaDeviceSynchronize();
}


int* think(int *inputs){
    //set brain inputs
    cudaMemcpy(d_brain_inputs, inputs, sizeof(int) * NUM_INPUTS, cudaMemcpyHostToDevice);
    CudaCheckError();
    //sum up the inputs
    //compute_synapses<<<1, synapses_dim>>>(d_synapses, d_weighted_sums, dev_pitch);
    read<<<grid_dim, block_dim>>>(d_synapses, dev_pitch);
    cudaDeviceSynchronize();
    
    //decide Threshold
    printf("compuyte neurons");
    CudaCheckError();
    compute_neurons<<<grid_dim, block_dim>>>(d_synapses, d_neuron_outputs, dev_pitch);
    cudaDeviceSynchronize();
    CudaCheckError();
    //tag_synapses<<<1, synapses_dim>>>(d_synapses, d_neuron_outputs, dev_pitch);
    //copy results back to host
    int *outputs = (int*) malloc(sizeof(int) * NUM_OUTPUTS);
    cudaMemcpy(outputs, d_neuron_outputs, sizeof(int) * NUM_OUTPUTS, cudaMemcpyDeviceToHost);
    return outputs;
}

void process_reward(float reward){
    printf("reward is %.2f", reward);
    learn<<<grid_dim, block_dim>>>(d_synapses, reward, dev_pitch);
}

void reset_memory(){
    reset_synapses<<<grid_dim, block_dim>>>(d_synapses, d_weighted_sums, dev_pitch);
}

void release_memory(){
    cudaFree(d_brain_inputs);
    cudaFree(d_neuron_outputs);
    cudaFree(d_synapses);
    cudaFree(d_weighted_sums);
}