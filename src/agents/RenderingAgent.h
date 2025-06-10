#ifndef RENDERING_AGENT_H
#define RENDERING_AGENT_H

class RenderingAgent {
public:
    RenderingAgent() = default;
    // Combine waveform and beat data to render frames
    void renderFrame();
};

#endif // RENDERING_AGENT_H
