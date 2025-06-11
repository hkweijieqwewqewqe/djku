import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart'; // For Utf8, calloc, etc.
import 'dart:io' show Platform;

// --- Helper to determine library path ---
String _getDynamicLibraryPath() {
  if (Platform.isMacOS || Platform.isIOS) {
    // For macOS, typically a .dylib file in Frameworks or loaded directly
    // For iOS, it's part of the app bundle
    // This might need adjustment based on actual build output
    return 'libjuce_module.dylib'; // Placeholder
  } else if (Platform.isAndroid) {
    return 'libjuce_module.so';
  } else if (Platform.isWindows) {
    return 'juce_module.dll'; // Or libjuce_module.dll
  } else if (Platform.isLinux) {
    return 'libjuce_module.so';
  }
  throw UnsupportedError('Unsupported platform for JUCE FFI');
}

final ffi.DynamicLibrary _juceLib = ffi.DynamicLibrary.open(_getDynamicLibraryPath());

// --- C Struct Definitions (mirrored in Dart) ---

// typedef struct AudioFileInfo {
//     double sampleRate;
//     long long totalSamples;
//     int numChannels;
//     double durationSeconds;
// } AudioFileInfo;
class AudioFileInfo extends ffi.Struct {
  @ffi.Double()
  external double sampleRate;

  @ffi.Int64()
  external int totalSamples;

  @ffi.Int32()
  external int numChannels;

  @ffi.Double()
  external double durationSeconds;
}

// typedef struct WaveformPoint {
//     float minValue;
//     float maxValue;
//     unsigned char r;
//     unsigned char g;
//     unsigned char b;
// } WaveformPoint;
class WaveformPoint extends ffi.Struct {
  @ffi.Float()
  external double minValue; // Dart uses double for float

  @ffi.Float()
  external double maxValue; // Dart uses double for float

  @ffi.Uint8()
  external int r;

  @ffi.Uint8()
  external int g;

  @ffi.Uint8()
  external int b;
}

// --- FFI Function Signatures ---

// AudioEngine* createAudioEngine();
typedef CreateAudioEngineC = ffi.Pointer<ffi.Void> Function();
typedef CreateAudioEngineDart = ffi.Pointer<ffi.Void> Function();
final CreateAudioEngineDart createAudioEngine =
    _juceLib.lookup<ffi.NativeFunction<CreateAudioEngineC>>('createAudioEngine').asFunction();

// void destroyAudioEngine(AudioEngine* engine);
typedef DestroyAudioEngineC = ffi.Void Function(ffi.Pointer<ffi.Void> engine);
typedef DestroyAudioEngineDart = void Function(ffi.Pointer<ffi.Void> engine);
final DestroyAudioEngineDart destroyAudioEngine =
    _juceLib.lookup<ffi.NativeFunction<DestroyAudioEngineC>>('destroyAudioEngine').asFunction();

// bool loadAudioFile(AudioEngine* engine, const char* filePath);
typedef LoadAudioFileC = ffi.Bool Function(ffi.Pointer<ffi.Void> engine, ffi.Pointer<Utf8> filePath);
typedef LoadAudioFileDart = bool Function(ffi.Pointer<ffi.Void> engine, ffi.Pointer<Utf8> filePath);
final LoadAudioFileDart loadAudioFile =
    _juceLib.lookup<ffi.NativeFunction<LoadAudioFileC>>('loadAudioFile').asFunction();

// bool getAudioFileInfo(AudioEngine* engine, AudioFileInfo* info);
typedef GetAudioFileInfoC = ffi.Bool Function(ffi.Pointer<ffi.Void> engine, ffi.Pointer<AudioFileInfo> info);
typedef GetAudioFileInfoDart = bool Function(ffi.Pointer<ffi.Void> engine, ffi.Pointer<AudioFileInfo> info);
final GetAudioFileInfoDart getAudioFileInfo =
    _juceLib.lookup<ffi.NativeFunction<GetAudioFileInfoC>>('getAudioFileInfo').asFunction();

// int getWaveformOverview(AudioEngine* engine, WaveformPoint* buffer, int bufferSize);
typedef GetWaveformOverviewC = ffi.Int32 Function(ffi.Pointer<ffi.Void> engine, ffi.Pointer<WaveformPoint> buffer, ffi.Int32 bufferSize);
typedef GetWaveformOverviewDart = int Function(ffi.Pointer<ffi.Void> engine, ffi.Pointer<WaveformPoint> buffer, int bufferSize);
final GetWaveformOverviewDart getWaveformOverview =
    _juceLib.lookup<ffi.NativeFunction<GetWaveformOverviewC>>('getWaveformOverview').asFunction();

// double getBPM(AudioEngine* engine);
typedef GetBPMC = ffi.Double Function(ffi.Pointer<ffi.Void> engine);
typedef GetBPMDart = double Function(ffi.Pointer<ffi.Void> engine);
final GetBPMDart getBPM =
    _juceLib.lookup<ffi.NativeFunction<GetBPMC>>('getBPM').asFunction();

// int getBeatPositions(AudioEngine* engine, double* buffer, int bufferSize);
typedef GetBeatPositionsC = ffi.Int32 Function(ffi.Pointer<ffi.Void> engine, ffi.Pointer<ffi.Double> buffer, ffi.Int32 bufferSize);
typedef GetBeatPositionsDart = int Function(ffi.Pointer<ffi.Void> engine, ffi.Pointer<ffi.Double> buffer, int bufferSize);
final GetBeatPositionsDart getBeatPositions =
    _juceLib.lookup<ffi.NativeFunction<GetBeatPositionsC>>('getBeatPositions').asFunction();

// --- NEW FFI Functions for Playback ---

// void play(AudioEngine* engine);
typedef PlayC = ffi.Void Function(ffi.Pointer<ffi.Void> engine);
typedef PlayDart = void Function(ffi.Pointer<ffi.Void> engine);
final PlayDart play =
    _juceLib.lookup<ffi.NativeFunction<PlayC>>('play').asFunction();

// void pause(AudioEngine* engine);
typedef PauseC = ffi.Void Function(ffi.Pointer<ffi.Void> engine);
typedef PauseDart = void Function(ffi.Pointer<ffi.Void> engine);
final PauseDart pause =
    _juceLib.lookup<ffi.NativeFunction<PauseC>>('pause').asFunction();

// void stop(AudioEngine* engine);
typedef StopC = ffi.Void Function(ffi.Pointer<ffi.Void> engine);
typedef StopDart = void Function(ffi.Pointer<ffi.Void> engine);
final StopDart stop =
    _juceLib.lookup<ffi.NativeFunction<StopC>>('stop').asFunction();

// bool isPlaying(AudioEngine* engine);
typedef IsPlayingC = ffi.Bool Function(ffi.Pointer<ffi.Void> engine);
typedef IsPlayingDart = bool Function(ffi.Pointer<ffi.Void> engine);
final IsPlayingDart isPlaying =
    _juceLib.lookup<ffi.NativeFunction<IsPlayingC>>('isPlaying').asFunction();

// double getCurrentPlaybackPosition(AudioEngine* engine); // Returns position in seconds
typedef GetCurrentPlaybackPositionC = ffi.Double Function(ffi.Pointer<ffi.Void> engine);
typedef GetCurrentPlaybackPositionDart = double Function(ffi.Pointer<ffi.Void> engine);
final GetCurrentPlaybackPositionDart getCurrentPlaybackPosition =
    _juceLib.lookup<ffi.NativeFunction<GetCurrentPlaybackPositionC>>('getCurrentPlaybackPosition').asFunction();

// void setPositionSeconds(AudioEngine* engine, double seconds);
typedef SetPositionSecondsC = ffi.Void Function(ffi.Pointer<ffi.Void> engine, ffi.Double seconds);
typedef SetPositionSecondsDart = void Function(ffi.Pointer<ffi.Void> engine, double seconds);
final SetPositionSecondsDart setPositionSeconds =
    _juceLib.lookup<ffi.NativeFunction<SetPositionSecondsC>>('setPositionSeconds').asFunction();


// --- Dart Wrapper Class (optional but recommended) ---
// This class encapsulates the FFI calls and memory management.
class JuceAudioBridge {
  ffi.Pointer<ffi.Void> _engine;

  JuceAudioBridge() : _engine = createAudioEngine() {
    if (_engine == ffi.nullptr) {
      throw Exception('Failed to create AudioEngine');
    }
  }

  void dispose() {
    if (_engine != ffi.nullptr) {
      destroyAudioEngine(_engine);
      _engine = ffi.nullptr;
    }
  }

  bool loadFile(String filePath) {
    if (_engine == ffi.nullptr) return false;
    final filePathC = filePath.toNativeUtf8();
    final result = loadAudioFile(_engine, filePathC);
    calloc.free(filePathC);
    return result;
  }

  AudioFileInfoData? getFileInfo() {
    if (_engine == ffi.nullptr) return null;

    final infoPtr = calloc<AudioFileInfo>();
    try {
      final success = getAudioFileInfo(_engine, infoPtr);
      if (success) {
        return AudioFileInfoData.fromPointer(infoPtr.ref);
      } else {
        return null;
      }
    } finally {
      calloc.free(infoPtr);
    }
  }

  List<WaveformPointData>? getOverview(int expectedPoints) {
    if (_engine == ffi.nullptr) return null;

    final bufferPtr = calloc<WaveformPoint>(expectedPoints);
    try {
      final pointsCopied = getWaveformOverview(_engine, bufferPtr, expectedPoints);
      if (pointsCopied > 0) {
        final List<WaveformPointData> points = [];
        for (int i = 0; i < pointsCopied; i++) {
          points.add(WaveformPointData.fromPointer(bufferPtr[i]));
        }
        return points;
      } else {
        return []; // Return empty list if no points or error
      }
    } finally {
      calloc.free(bufferPtr);
    }
  }

  double getBpm() {
    if (_engine == ffi.nullptr) return 0.0;
    return getBPM(_engine);
  }

  List<double>? getBeats(int maxBeats) {
     if (_engine == ffi.nullptr) return null;
    final bufferPtr = calloc<ffi.Double>(maxBeats);
    try {
      final beatsCopied = getBeatPositions(_engine, bufferPtr, maxBeats);
      if (beatsCopied > 0) {
        final List<double> beats = [];
        for (int i = 0; i < beatsCopied; i++) {
          beats.add(bufferPtr[i]);
        }
        return beats;
      } else {
        return [];
      }
    } finally {
      calloc.free(bufferPtr);
    }
  }

  void playAudio() {
    if (_engine == ffi.nullptr) return;
    play(_engine);
  }

  void pauseAudio() {
    if (_engine == ffi.nullptr) return;
    pause(_engine);
  }

  void stopAudio() {
    if (_engine == ffi.nullptr) return;
    stop(_engine);
  }

  bool checkIsPlaying() {
    if (_engine == ffi.nullptr) return false;
    return isPlaying(_engine);
  }

  double getCurrentPosition() {
    if (_engine == ffi.nullptr) return 0.0;
    return getCurrentPlaybackPosition(_engine);
  }

  void setPlaybackPosition(double seconds) {
    if (_engine == ffi.nullptr) return;
    setPositionSeconds(_engine, seconds);
  }
}

// --- Dart Data Classes (to copy data from FFI structs) ---
// It's good practice to copy data from FFI-allocated memory into Dart objects.

class AudioFileInfoData {
  final double sampleRate;
  final int totalSamples;
  final int numChannels;
  final double durationSeconds;

  AudioFileInfoData({
    required this.sampleRate,
    required this.totalSamples,
    required this.numChannels,
    required this.durationSeconds,
  });

  factory AudioFileInfoData.fromPointer(AudioFileInfo ref) {
    return AudioFileInfoData(
      sampleRate: ref.sampleRate,
      totalSamples: ref.totalSamples,
      numChannels: ref.numChannels,
      durationSeconds: ref.durationSeconds,
    );
  }

  @override
  String toString() {
    return 'AudioFileInfoData(sampleRate: $sampleRate, totalSamples: $totalSamples, numChannels: $numChannels, durationSeconds: $durationSeconds)';
  }
}

class WaveformPointData {
  final double minValue;
  final double maxValue;
  final int r, g, b;

  WaveformPointData({
    required this.minValue,
    required this.maxValue,
    required this.r,
    required this.g,
    required this.b,
  });

  factory WaveformPointData.fromPointer(WaveformPoint ref) {
    return WaveformPointData(
      minValue: ref.minValue,
      maxValue: ref.maxValue,
      r: ref.r,
      g: ref.g,
      b: ref.b,
    );
  }
   @override
  String toString() {
    return 'WaveformPointData(min: $minValue, max: $maxValue, color: ($r, $g, $b))';
  }
}
