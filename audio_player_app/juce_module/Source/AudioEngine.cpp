#include "AudioEngine.h"
#include <iostream>
#include <algorithm> // For std::min/max
#include <vector>    // Required for std::vector
#include <numeric>   // Required for std::accumulate (potentially for averaging)
#include <algorithm> // For std::sort (used for median calculation)
#include <juce_core/juce_core.h> // For juce::jlimit, File etc.

// Helper to convert juce::String to std::string for convenience
std::string juceStringToStdString(const juce::String& juceStr) {
    return juceStr.toStdString();
}

// --- C-style API Implementation ---
AudioEngine* createAudioEngine() {
    return new AudioEngine();
}

void destroyAudioEngine(AudioEngine* engine) {
    delete engine;
}

bool loadAudioFile(AudioEngine* engine, const char* filePath) {
    if (!engine || !filePath) {
        return false;
    }
    return engine->loadFile(std::string(filePath));
}

bool getAudioFileInfo(AudioEngine* engine, AudioFileInfo* info) {
    if (!engine || !info) {
        return false;
    }
    return engine->getFileInfo(*info);
}

int getWaveformOverview(AudioEngine* engine, WaveformPoint* buffer, int bufferSize) {
    if (!engine || !buffer) {
        return 0;
    }
    const auto& overviewData = engine->getOverviewData();
    int pointsToCopy = std::min(static_cast<int>(overviewData.size()), bufferSize);
    for (int i = 0; i < pointsToCopy; ++i) {
        buffer[i] = overviewData[i];
    }
    return pointsToCopy;
}

double getBPM(AudioEngine* engine) {
    if (!engine) {
        return 0.0;
    }
    return engine->getDetectedBPM();
}

int getBeatPositions(AudioEngine* engine, double* buffer, int bufferSize) {
    if (!engine || !buffer) {
        return 0;
    }
    const auto& beatPositions = engine->getDetectedBeatPositions();
    int beatsToCopy = std::min(static_cast<int>(beatPositions.size()), bufferSize);
    for (int i = 0; i < beatsToCopy; ++i) {
        buffer[i] = beatPositions[i];
    }
    return beatsToCopy;
}

void play(AudioEngine* engine) {
    if (engine) engine->startPlayback();
}

void pause(AudioEngine* engine) {
    if (engine) engine->pausePlayback();
}

void stop(AudioEngine* engine) {
    if (engine) engine->stopPlayback();
}

bool isPlaying(AudioEngine* engine) {
    return engine ? engine->getIsPlaying() : false;
}

double getCurrentPlaybackPosition(AudioEngine* engine) {
    return engine ? engine->getCurrentPositionSeconds() : 0.0;
}

void setPositionSeconds(AudioEngine* engine, double seconds) {
    if (engine) engine->setPlaybackPositionSeconds(seconds);
}

// --- AudioEngine Class Implementation ---
AudioEngine::AudioEngine() { // FFT initialized in member initializer list in .h if needed, or here
    fft = std::make_unique<juce::dsp::FFT>(FFT_ORDER); // Ensure FFT is initialized
    formatManager.registerBasicFormats();
    // formatManager.registerFormat(new juce::MP3AudioFormat(), true); // Example for MP3
    std::cout << "AudioEngine created. FFT Size: " << FFT_SIZE << ". Registered formats: " << formatManager.getNumKnownFormats() << std::endl;

    const juce::String error (audioDeviceManager.initialise(
        0, // numInputChannelsNeeded
        2, // numOutputChannelsNeeded
        nullptr, // savedState (XML)
        true,    // selectDefaultDeviceOnFailure
        juce::String(), // preferredDeviceName
        nullptr  // preferredSetupOptions
    ));

    if (error.isNotEmpty()) {
        std::cerr << "AudioEngine: Could not initialise audio device manager: " << error.toStdString() << std::endl;
    } else {
        std::cout << "AudioEngine: AudioDeviceManager initialized." << std::endl;
        juce::AudioIODevice* device = audioDeviceManager.getCurrentAudioDevice();
        if (device) {
             std::cout << "  Output Device: " << device->getName().toStdString() << std::endl;
             std::cout << "  Sample Rate: " << device->getCurrentSampleRate() << std::endl;
             std::cout << "  Buffer Size: " << device->getCurrentBufferSizeSamples() << std::endl;
        } else {
             std::cerr << "AudioEngine: No audio output device found/initialized." << std::endl;
        }
    }

    audioSourcePlayer.setSource(&transportSource);
    transportSource.addChangeListener(this);

    audioDeviceManager.addAudioCallback(&audioSourcePlayer);
}

AudioEngine::~AudioEngine() {
    transportSource.stop();
    transportSource.setSource(nullptr);
    audioSourcePlayer.setSource(nullptr);

    audioDeviceManager.removeAudioCallback(&audioSourcePlayer);
    audioDeviceManager.closeAudioDevice();

    currentAudioFileSource.reset();

    std::cout << "AudioEngine destroyed. Audio resources released." << std::endl;
}

bool AudioEngine::loadFile(const std::string& filePath) {
    transportSource.stop();
    transportSource.setSource(nullptr);
    currentAudioFileSource.reset();

    juce::File fileToLoad(filePath);
    if (!fileToLoad.existsAsFile()) {
        std::cerr << "AudioEngine::loadFile - File does not exist: " << filePath << std::endl;
        return false;
    }

    std::unique_ptr<juce::AudioFormatReader> playbackReader(formatManager.createReaderFor(fileToLoad));

    if (playbackReader == nullptr) {
        std::cerr << "AudioEngine::loadFile - Could not create PLAYBACK reader for file: " << filePath << std::endl;
        return false;
    }

    currentSampleRate = playbackReader->sampleRate;
    currentTotalSamples = playbackReader->lengthInSamples;
    currentNumChannels = playbackReader->numChannels;
    if (currentSampleRate > 0) {
        currentDurationSeconds = static_cast<double>(currentTotalSamples) / currentSampleRate;
    } else {
        currentDurationSeconds = 0.0;
    }

    std::cout << "AudioEngine::loadFile - Loaded metadata for playback: " << filePath << std::endl;
    std::cout << "  Sample Rate: " << currentSampleRate << std::endl;
    std::cout << "  Duration: " << currentDurationSeconds << "s" << std::endl;

    currentAudioFileSource = std::make_unique<juce::AudioFormatReaderSource>(playbackReader.release(), true);
    transportSource.setSource(currentAudioFileSource.get(),
                              0,
                              nullptr,
                              currentAudioFileSource->getAudioFormatReader()->sampleRate);

    reader.reset(formatManager.createReaderFor(fileToLoad)); // Re-assign to the class member 'reader'
    if (reader == nullptr) {
         std::cerr << "AudioEngine::loadFile - Could not create ANALYSIS reader for file: " << filePath << std::endl;
         transportSource.setSource(nullptr);
         currentAudioFileSource.reset();
         return false;
    }

    if (reader->lengthInSamples > 0 && reader->numChannels > 0) {
        audioBuffer.setSize(reader->numChannels, static_cast<int>(reader->lengthInSamples));
        reader->read(&audioBuffer, 0, static_cast<int>(reader->lengthInSamples), 0, true, true);
        std::cout << "AudioEngine::loadFile - Read " << audioBuffer.getNumSamples() << " samples into buffer for analysis." << std::endl;

        performFullWaveformAnalysis();
        performBeatDetection();
    } else {
        std::cerr << "AudioEngine::loadFile - No samples or channels to read for analysis." << std::endl;
        overviewWaveformPoints.clear();
        detectedBeatTimestamps.clear();
        detectedBPM = 0.0;
    }

    return true;
}

bool AudioEngine::getFileInfo(AudioFileInfo& info) {
    // Use the stored metadata; reader might be null if only playback source was set up
    // or if called before loadFile completes fully for analysis part.
    // This info is now set from the playbackReader initially.
    if (currentDurationSeconds == 0.0 && currentTotalSamples == 0) { // Basic check if anything loaded
         std::cerr << "AudioEngine::getFileInfo - No file metadata available." << std::endl;
        return false;
    }
    info.sampleRate = currentSampleRate;
    info.totalSamples = currentTotalSamples;
    info.numChannels = currentNumChannels;
    info.durationSeconds = currentDurationSeconds;
    return true;
}


const std::vector<WaveformPoint>& AudioEngine::getOverviewData() const {
    return overviewWaveformPoints;
}

void AudioEngine::performFullWaveformAnalysis() {
    overviewWaveformPoints.clear();
    if (audioBuffer.getNumSamples() == 0 || currentSampleRate == 0.0) {
        std::cout << "AudioEngine::performFullWaveformAnalysis - No audio data to analyze." << std::endl;
        return;
    }

    std::cout << "AudioEngine::performFullWaveformAnalysis - Starting analysis..." << std::endl;

    const float* channelData = audioBuffer.getReadPointer(0);
    if (audioBuffer.getNumChannels() > 1) {
        std::cout << "  Warning: Using only first channel for analysis of multi-channel audio." << std::endl;
    }

    long long totalSamplesInFile = audioBuffer.getNumSamples();
    int samplesPerPoint = static_cast<int>(totalSamplesInFile / DEFAULT_OVERVIEW_RESOLUTION);
    if (samplesPerPoint == 0) samplesPerPoint = 1;

    overviewWaveformPoints.reserve(DEFAULT_OVERVIEW_RESOLUTION);

    for (int i = 0; i < DEFAULT_OVERVIEW_RESOLUTION; ++i) {
        long long startSample = static_cast<long long>(i) * samplesPerPoint;
        long long endSample = startSample + samplesPerPoint;
        if (endSample > totalSamplesInFile) {
            endSample = totalSamplesInFile;
        }
        if (startSample >= totalSamplesInFile) break;

        WaveformPoint point = {0.0f, 0.0f, 128, 128, 128};

        float minValue = channelData[startSample];
        float maxValue = channelData[startSample];
        for (long long s = startSample + 1; s < endSample; ++s) {
            if (channelData[s] < minValue) minValue = channelData[s];
            if (channelData[s] > maxValue) maxValue = channelData[s];
        }
        point.minValue = minValue;
        point.maxValue = maxValue;

        long long segmentCenterSample = startSample + (endSample - startSample) / 2;
        long long fftStartSample = std::max(0LL, segmentCenterSample - FFT_SIZE / 2);
        int samplesToCopyForFFT = FFT_SIZE;

        if (totalSamplesInFile - fftStartSample < FFT_SIZE) {
             samplesToCopyForFFT = static_cast<int>(totalSamplesInFile - fftStartSample);
        }

        if (samplesToCopyForFFT > 0) {
            juce::dsp::WindowingFunction<float> window(FFT_SIZE, juce::dsp::WindowingFunction<float>::hann);

            for(int k=0; k < FFT_SIZE; ++k) {
                if (fftStartSample + k < totalSamplesInFile) {
                    fftWindowBuffer[k] = channelData[fftStartSample + k];
                } else {
                    fftWindowBuffer[k] = 0.0f;
                }
            }
            window.multiplyWithWindowingTable(fftWindowBuffer, FFT_SIZE);

            fft->performFrequencyOnlyForwardTransform(fftWindowBuffer);

            float lowEnergy = 0.0f, midEnergy = 0.0f, highEnergy = 0.0f;
            float totalEnergy = 0.0001f;

            for (int k = 0; k < FFT_SIZE / 2 + 1; ++k) {
                float freq = static_cast<float>(k) * (static_cast<float>(currentSampleRate) / FFT_SIZE);
                float magnitude = fftWindowBuffer[k];

                if (freq <= LOW_FREQ_CUTOFF) {
                    lowEnergy += magnitude;
                } else if (freq <= MID_FREQ_CUTOFF) {
                    midEnergy += magnitude;
                } else {
                    highEnergy += magnitude;
                }
                totalEnergy += magnitude;
            }

            if (totalEnergy > 0) {
                point.r = static_cast<unsigned char>(std::min(255.0f, (lowEnergy / totalEnergy) * 255.0f * 3.0f));
                point.g = static_cast<unsigned char>(std::min(255.0f, (midEnergy / totalEnergy) * 255.0f * 3.0f));
                point.b = static_cast<unsigned char>(std::min(255.0f, (highEnergy / totalEnergy) * 255.0f * 3.0f));
            }
        }
        overviewWaveformPoints.push_back(point);
    }
    std::cout << "AudioEngine::performFullWaveformAnalysis - Analysis complete. Generated " << overviewWaveformPoints.size() << " overview points." << std::endl;
}

double AudioEngine::getDetectedBPM() const {
    return detectedBPM;
}

const std::vector<double>& AudioEngine::getDetectedBeatPositions() const {
    return detectedBeatTimestamps;
}

void AudioEngine::performBeatDetection() {
    detectedBPM = 0.0;
    detectedBeatTimestamps.clear();

    if (audioBuffer.getNumSamples() == 0 || currentSampleRate == 0.0) {
        std::cout << "AudioEngine::performBeatDetection - No audio data for beat detection." << std::endl;
        return;
    }

    std::cout << "AudioEngine::performBeatDetection - Starting beat detection (simplified)..." << std::endl;

    const int numSamples = audioBuffer.getNumSamples();
    const float duration = static_cast<float>(numSamples) / currentSampleRate;

    if (overviewWaveformPoints.empty()) {
        std::cout << "AudioEngine::performBeatDetection - Waveform overview data not available. Skipping." << std::endl;
        return;
    }

    std::vector<float> energies;
    energies.reserve(overviewWaveformPoints.size());
    for(const auto& point : overviewWaveformPoints) {
        energies.push_back(point.maxValue - point.minValue);
    }

    if (energies.size() < 2) {
        std::cout << "AudioEngine::performBeatDetection - Not enough energy points to detect beats." << std::endl;
        return;
    }

    std::vector<double> onsets;
    const int historySize = 10;
    float energySum = 0.0f;
    for(size_t i = 0; i < std::min((size_t)historySize, energies.size()); ++i) {
        energySum += energies[i];
    }

    for(size_t i = 0; i < energies.size(); ++i) {
        float currentEnergy = energies[i];
        float localAverageEnergy = 0.0f;

        if (i > 0) {
             if (i < historySize) {
                localAverageEnergy = energySum / (i + 1) ;
             } else {
                localAverageEnergy = energySum / historySize;
             }
        }

        if (currentEnergy > localAverageEnergy * 1.5f && currentEnergy > 0.05f) {
            double timeStamp = (static_cast<double>(i) / DEFAULT_OVERVIEW_RESOLUTION) * duration;
            if (onsets.empty() || (timeStamp - onsets.back()) > 0.2) {
                 onsets.push_back(timeStamp);
            }
        }

        if (i >= historySize && (i - historySize) < energies.size() ) { // Check bounds for energies[i-historySize]
             energySum -= energies[i - historySize];
        }
        if (i + 1 < energies.size()) { // Add next element to sum for *next* iteration's average
             energySum += energies[i+1];
        } else if (i < historySize && i + 1 < energies.size()) {
            // This else-if branch seems redundant with the one above.
            // The sum for the initial window (less than historySize) is already built.
            // The sum adjustment for sliding window is the main concern.
        }
    }

    if (onsets.size() < 2) {
        std::cout << "AudioEngine::performBeatDetection - Not enough onsets detected to calculate BPM." << std::endl;
        detectedBPM = 0.0;
        detectedBeatTimestamps = onsets;
        return;
    }

    std::vector<double> iois;
    for (size_t i = 0; i < onsets.size() - 1; ++i) {
        iois.push_back(onsets[i+1] - onsets[i]);
    }
    std::sort(iois.begin(), iois.end());
    if (iois.empty()) { // Guard against empty iois vector
        detectedBPM = 0.0;
    } else {
        double medianIOI = iois[iois.size() / 2];
        if (medianIOI > 0.01) {
            detectedBPM = 60.0 / medianIOI;
            while (detectedBPM < 70.0 && detectedBPM > 0.1) detectedBPM *= 2.0;
            while (detectedBPM > 180.0) detectedBPM /= 2.0;
        } else {
            detectedBPM = 0.0;
        }
    }

    detectedBeatTimestamps = onsets;

    std::cout << "AudioEngine::performBeatDetection - Detection complete." << std::endl;
    std::cout << "  Detected Onsets: " << detectedBeatTimestamps.size() << std::endl;
    std::cout << "  Estimated BPM: " << detectedBPM << std::endl;
}

// --- Playback method implementations using AudioTransportSource ---
void AudioEngine::startPlayback() {
    if (currentAudioFileSource == nullptr) {
        std::cout << "AudioEngine::startPlayback - No file loaded/prepared for playback." << std::endl;
        return;
    }
    std::cout << "AudioEngine::startPlayback - Starting transport." << std::endl;
    transportSource.start();
}

void AudioEngine::pausePlayback() {
    if (!transportSource.isPlaying()) return;
    std::cout << "AudioEngine::pausePlayback - Pausing transport." << std::endl;
    transportSource.stop();
}

void AudioEngine::stopPlayback() {
    std::cout << "AudioEngine::stopPlayback - Stopping transport and resetting position." << std::endl;
    transportSource.stop();
    transportSource.setPosition(0.0);
}

bool AudioEngine::getIsPlaying() const {
    return transportSource.isPlaying();
}

double AudioEngine::getCurrentPositionSeconds() const {
    return transportSource.getCurrentPosition();
}

void AudioEngine::setPlaybackPositionSeconds(double seconds) {
    if (currentAudioFileSource == nullptr || currentDurationSeconds == 0.0) return; // Ensure file is loaded
    double clampedSeconds = juce::jlimit(0.0, currentDurationSeconds, seconds);
    std::cout << "AudioEngine::setPlaybackPositionSeconds - Setting position to " << clampedSeconds << "s." << std::endl;
    transportSource.setPosition(clampedSeconds);
}

// --- ChangeListener Callback ---
void AudioEngine::changeListenerCallback(juce::ChangeBroadcaster* source) {
    if (source == &transportSource) {
        if (transportSource.hasStreamFinished()) {
            std::cout << "AudioEngine: Transport stream finished." << std::endl;
            // The transport source stops automatically.
            // The Dart side timer will poll isPlaying() and update its state.
            // We could explicitly call transportSource.stop() here if needed for other cleanup,
            // but it should already be stopped.
            // To make it loop, you could call transportSource.setPosition(0.0); transportSource.start();
        }
    }
}
