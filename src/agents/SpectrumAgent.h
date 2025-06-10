#ifndef SPECTRUM_AGENT_H
#define SPECTRUM_AGENT_H

#include <vector>

class SpectrumAgent {
public:
    SpectrumAgent() = default;
    // Perform FFT to compute spectrum data
    void compute(const std::vector<float> &samples);
};

#endif // SPECTRUM_AGENT_H
