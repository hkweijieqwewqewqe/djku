#ifndef WAVEFORM_AGENT_H
#define WAVEFORM_AGENT_H

#include <vector>

class WaveformAgent {
public:
    WaveformAgent() = default;
    // Analyze waveform data and store results
    void analyze(const std::vector<float> &samples);
};

#endif // WAVEFORM_AGENT_H
