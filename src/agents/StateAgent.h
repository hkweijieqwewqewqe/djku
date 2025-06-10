#ifndef STATE_AGENT_H
#define STATE_AGENT_H

class StateAgent {
public:
    StateAgent() = default;
    // Maintain global state information
    void broadcastState();
};

#endif // STATE_AGENT_H
