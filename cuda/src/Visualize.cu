#include <stdio.h>
#include <cuda.h>
#include <curand_kernel.h>
#include "Synapse.h"
#include "Hyperparameters.h"



__global__ void printSynapses(struct Synapse *d_synapses, size_t pitch){
    int neuron = blockIdx.x * blockDim.x + threadIdx.x;
    if(neuron < NUM_NEURONS){
        struct Synapse *neuron_array = (struct Synapse *) ((char*)d_synapses + neuron * pitch);
        for(int synapse = 0; synapse< NUM_SYNAPSES_PER_NEURON; synapse++){
            printf("neuron: %d, synapse: %d, weight: %.2f, activity: %.2f, input: %d\n",
                neuron, synapse, neuron_array[synapse].weight,
                neuron_array[synapse].activity, neuron_array[synapse].input);
        }
    }
    
}

__global__ void printNeurons(int *d_neuron_outputs, float *d_weighted_sums){
    int neuron = blockIdx.x*blockDim.x + threadIdx.x;
    printf("neuron: %d, weighted sum: %.2f, output: %d\n", neuron, d_weighted_sums[neuron], d_neuron_outputs[neuron]);
}


void neuron_stats(int *d_neuron_outputs){
    int *neuron_outputs = (int*) malloc(sizeof(int) * NUM_NEURONS);
    cudaMemcpy(neuron_outputs, d_neuron_outputs, sizeof(int) * NUM_NEURONS, cudaMemcpyDeviceToHost);
    int output_sum = 0;
    for(int i = 0; i <NUM_NEURONS; i++){
        output_sum += neuron_outputs[i];
    }
    
    printf("avr_output: %.2f\n", output_sum/(float)NUM_NEURONS);
}