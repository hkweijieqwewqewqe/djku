#ifndef FILE_MANAGER_AGENT_H
#define FILE_MANAGER_AGENT_H

#include <string>

class FileManagerAgent {
public:
    FileManagerAgent() = default;
    // Load an audio file and return success status
    bool loadFile(const std::string &path);
};

#endif // FILE_MANAGER_AGENT_H
