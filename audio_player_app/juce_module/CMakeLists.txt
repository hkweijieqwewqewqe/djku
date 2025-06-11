cmake_minimum_required(VERSION 3.10)
project(JuceModule)

# This assumes JUCE is added as a subdirectory or found via find_package
# For now, we'll focus on compiling our source files.
# JUCE integration will be more complex and involve linking against JUCE libraries.

# Add source files
add_library(JuceModule STATIC
    Source/AudioEngine.cpp
    # Source/placeholder.cpp # We can remove this if AudioEngine.cpp is present
)

# Public include directories (so FFI bridge code can find AudioEngine.h)
target_include_directories(JuceModule PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/Source)

# JUCE modules to link against (example) - THIS WILL BE HANDLED LATER
# target_link_libraries(JuceModule PRIVATE
#     juce_audio_basics
#     juce_audio_formats
#     juce_core
#     juce_events
# )

# For now, this CMakeLists.txt is primarily for organizing our files.
# Full JUCE compilation will require Projucer setup or a more detailed CMake setup
# that correctly incorporates the JUCE library itself.
