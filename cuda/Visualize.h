#ifndef VISUALIZE_H
#define VISUALIZE_H

__global__ void printSynapses(struct Synapse *d_synapses, size_t pitch);

__global__ void printNeurons(int *d_neuron_outputs, float *d_weighted_sums);

void neuron_stats(int *d_neuron_outputs);

#endif