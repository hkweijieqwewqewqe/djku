#pragma once

#include <juce_audio_formats/juce_audio_formats.h>
#include <juce_dsp/juce_dsp.h>
#include <juce_audio_devices/juce_audio_devices.h> // For AudioDeviceManager, AudioSourcePlayer
#include <juce_audio_utils/juce_audio_utils.h>   // For AudioTransportSource, AudioFormatReaderSource
#include <string>
#include <vector>
#include <memory> // For std::unique_ptr

// Forward declaration
class AudioEngine;

// C-style API for FFI
extern "C" {
    struct AudioFileInfo {
        double sampleRate;
        long long totalSamples;
        int numChannels;
        double durationSeconds;
    };

    struct WaveformPoint {
        float minValue;
        float maxValue;
        unsigned char r;
        unsigned char g;
        unsigned char b;
    };

    AudioEngine* createAudioEngine();
    void destroyAudioEngine(AudioEngine* engine);
    bool loadAudioFile(AudioEngine* engine, const char* filePath);
    bool getAudioFileInfo(AudioEngine* engine, AudioFileInfo* info);
    int getWaveformOverview(AudioEngine* engine, WaveformPoint* buffer, int bufferSize);
    double getBPM(AudioEngine* engine);
    int getBeatPositions(AudioEngine* engine, double* buffer, int bufferSize);

    // New FFI functions for playback
    void play(AudioEngine* engine);
    void pause(AudioEngine* engine);
    void stop(AudioEngine* engine);
    bool isPlaying(AudioEngine* engine);
    double getCurrentPlaybackPosition(AudioEngine* engine);
    void setPositionSeconds(AudioEngine* engine, double seconds);
}

class AudioEngine : private juce::ChangeListener { // Inherit from ChangeListener for transport state changes
public:
    AudioEngine();
    ~AudioEngine() override;

    bool loadFile(const std::string& filePath);
    bool getFileInfo(AudioFileInfo& info); // Remains for basic info
    const std::vector<WaveformPoint>& getOverviewData() const;
    double getDetectedBPM() const;
    const std::vector<double>& getDetectedBeatPositions() const;

    // Playback control methods
    void startPlayback();
    void pausePlayback();
    void stopPlayback();
    bool getIsPlaying() const; // Will now query transportSource
    double getCurrentPositionSeconds() const; // Will now query transportSource
    void setPlaybackPositionSeconds(double seconds); // Will now use transportSource

private:
    void performFullWaveformAnalysis();
    void performBeatDetection();
    void changeListenerCallback(juce::ChangeBroadcaster* source) override; // For transport state

    juce::AudioFormatManager formatManager;
    std::unique_ptr<juce::AudioFormatReader> reader; // For analysis
    juce::AudioBuffer<float> audioBuffer; // For analysis

    // Metadata (can be derived from reader or playbackReader)
    double currentSampleRate = 0.0;
    long long currentTotalSamples = 0;
    int currentNumChannels = 0;
    double currentDurationSeconds = 0.0;

    std::vector<WaveformPoint> overviewWaveformPoints;
    static const int DEFAULT_OVERVIEW_RESOLUTION = 1024;

    std::unique_ptr<juce::dsp::FFT> fft;
    static const int FFT_ORDER = 10;
    static const int FFT_SIZE = 1 << FFT_ORDER;
    float fftWindowBuffer[FFT_SIZE];

    const float LOW_FREQ_CUTOFF = 200.0f;
    const float MID_FREQ_CUTOFF = 2000.0f;

    double detectedBPM = 0.0;
    std::vector<double> detectedBeatTimestamps;

    // --- JUCE Playback Engine Members ---
    juce::AudioDeviceManager audioDeviceManager;
    juce::AudioSourcePlayer audioSourcePlayer;
    juce::AudioTransportSource transportSource;
    std::unique_ptr<juce::AudioFormatReaderSource> currentAudioFileSource;
};
