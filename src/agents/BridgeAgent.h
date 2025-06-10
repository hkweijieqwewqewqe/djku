#ifndef BRIDGE_AGENT_H
#define BRIDGE_AGENT_H

#include <string>

class BridgeAgent {
public:
    BridgeAgent() = default;
    // Dispatch commands from Flutter to native agents
    void handleMessage(const std::string &message);
};

#endif // BRIDGE_AGENT_H
