#ifndef BEAT_DETECTION_AGENT_H
#define BEAT_DETECTION_AGENT_H

#include <vector>

class BeatDetectionAgent {
public:
    BeatDetectionAgent() = default;
    // Detect BPM and beat positions
    void detect(const std::vector<float> &samples);
};

#endif // BEAT_DETECTION_AGENT_H
