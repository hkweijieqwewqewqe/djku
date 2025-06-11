import 'dart:async'; // For Timer
import 'package:flutter/material.dart';
import 'juce_ffi.dart';
import 'waveform_painter.dart';
import 'dart:io';
import 'dart:math' as math; // For math.max

Future<String?> pickAudioFile() async {
  if (Platform.isMacOS) {
    return null;
  } else if (Platform.isAndroid || Platform.isIOS) {
    print("File picking not implemented for this platform in placeholder.");
    return null;
  }
  return null;
}


class WaveformDisplayWidget extends StatefulWidget {
  const WaveformDisplayWidget({Key? key}) : super(key: key);

  @override
  _WaveformDisplayWidgetState createState() => _WaveformDisplayWidgetState();
}

class _WaveformDisplayWidgetState extends State<WaveformDisplayWidget> {
  JuceAudioBridge? _audioBridge;
  bool _isEngineInitialized = false;
  AudioFileInfoData? _fileInfo;
  List<WaveformPointData> _waveformData = [];
  bool _isLoading = false;
  String _status = "Please load an audio file.";

  static const int _defaultOverviewResolution = 1024;

  double _zoomLevel = 1.0;
  double _panOffset = 0.0;

  double _initialZoomLevel = 1.0;
  double _initialPanOffset = 0.0;
  double _gestureStartFocalPointX = 0.0;
  Size _widgetSize = Size.zero;

  bool _isAudioPlaying = false;
  Timer? _playbackTimer;
  double _currentPlaybackPosition = 0.0;


  @override
  void initState() {
    super.initState();
    try {
      _audioBridge = JuceAudioBridge();
      _isEngineInitialized = true;
      _status = "Audio engine initialized. Load a file.";
    } catch (e) {
      _isEngineInitialized = false;
      print("Error initializing JuceAudioBridge: $e");
      _status = "Error: Could not load audio engine. Ensure native library is compiled and accessible.";
      _audioBridge = null;
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _audioBridge?.dispose();
    super.dispose();
  }

  Future<void> _loadAudioFile(String filePath) async {
    if (!_isEngineInitialized || _audioBridge == null || filePath.isEmpty) {
      if (_audioBridge == null && _isEngineInitialized) { // Check if bridge became null after init
         setState(() {
           _status = "Audio engine became unavailable. Please restart.";
           _isEngineInitialized = false; // Mark as not initialized
         });
      } else if (!_isEngineInitialized) {
         setState(() {
           _status = "Audio engine not initialized.";
         });
      }
      return;
    }

    if (_isAudioPlaying) {
      _stopPlayback();
    }

    setState(() {
      _isLoading = true;
      _status = "Loading '$filePath'...";
      _waveformData = [];
      _fileInfo = null;
      _zoomLevel = 1.0;
      _panOffset = 0.0;
      _currentPlaybackPosition = 0.0;
    });

    try {
      final success = _audioBridge!.loadFile(filePath);
      if (success) {
        _fileInfo = _audioBridge!.getFileInfo();
        _waveformData = _audioBridge!.getOverview(_defaultOverviewResolution) ?? [];

        final bpm = _audioBridge!.getBpm();
        final beats = _audioBridge!.getBeats(200);

        setState(() {
          _status = "Loaded: ${_fileInfo?.durationSeconds?.toStringAsFixed(2)}s, BPM: ${bpm.toStringAsFixed(1)}";
          if (_waveformData.isEmpty && _fileInfo != null) {
             _status += "
Note: Waveform data is empty but file info was read. Check analysis.";
          } else if (_waveformData.isEmpty) {
            _status += "
Warning: Could not load waveform data.";
          }
          if (beats != null && beats.isNotEmpty) {
            _status += "
Detected ${beats.length} beats.";
          }
        });
      } else {
        setState(() {
          _status = "Failed to load '$filePath'.";
        });
      }
    } catch (e) {
      print("Error during audio processing: $e");
      setState(() {
        _status = "Error processing file: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _togglePlayPause() {
    if (!_isEngineInitialized || _audioBridge == null || _fileInfo == null) return;

    if (_isAudioPlaying) {
      _audioBridge!.pauseAudio();
      _playbackTimer?.cancel();
      setState(() {
        _isAudioPlaying = false;
      });
    } else {
      // Before playing, ensure the current position is valid, or reset to start if at end
      if (_fileInfo != null && _currentPlaybackPosition >= _fileInfo!.durationSeconds) {
        _currentPlaybackPosition = 0.0;
        _audioBridge!.setPlaybackPosition(0.0);
      }
      _audioBridge!.playAudio();
      setState(() {
        _isAudioPlaying = true;
      });
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (!_isAudioPlaying || _audioBridge == null) {
          timer.cancel();
          return;
        }
        final newPosition = _audioBridge!.getCurrentPosition();
        final bool currentPlayingState = _audioBridge!.checkIsPlaying();

        setState(() {
          _currentPlaybackPosition = newPosition;
          if (!currentPlayingState && _isAudioPlaying) { // Native side stopped
            _isAudioPlaying = false;
            timer.cancel();
             // If it stopped because it reached the end, clamp position
            if (_fileInfo != null && newPosition >= _fileInfo!.durationSeconds) {
               _currentPlaybackPosition = _fileInfo!.durationSeconds;
            }
          }
        });
         // Additional check to stop if position exceeds duration (e.g. due to native side not stopping exactly at end)
        if (_fileInfo != null && newPosition >= _fileInfo!.durationSeconds && _isAudioPlaying) {
            _stopPlayback(); // Use our stop method to ensure UI consistency
        }
      });
    }
  }

  void _stopPlayback() {
    if (!_isEngineInitialized || _audioBridge == null) return;
    _audioBridge!.stopAudio();
    _playbackTimer?.cancel();
    setState(() {
      _isAudioPlaying = false;
      _currentPlaybackPosition = 0.0;
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_audioBridge == null || !_isEngineInitialized) return;
    _initialZoomLevel = _zoomLevel;
    _initialPanOffset = _panOffset;
    _gestureStartFocalPointX = details.localFocalPoint.dx;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_waveformData.isEmpty || _audioBridge == null || !_isEngineInitialized) return;

    double newZoomLevel = _initialZoomLevel * details.scale;
    newZoomLevel = newZoomLevel.clamp(1.0, math.max(1.0, _waveformData.length / 10.0));
    if (newZoomLevel < 1.0) newZoomLevel = 1.0;

    double dx = details.localFocalPoint.dx - _gestureStartFocalPointX;
    double panSensitivity = 1.0 / (_widgetSize.width * _zoomLevel);
    double panDelta = dx * panSensitivity;

    double newPanOffset = _initialPanOffset - panDelta;

    newPanOffset = newPanOffset.clamp(0.0, 1.0);

    if (newZoomLevel == 1.0) {
      newPanOffset = 0.0;
    }

    setState(() {
      _zoomLevel = newZoomLevel;
      _panOffset = newPanOffset;
    });
  }

  void _seekToPosition(double globalXPosition) {
    if (!_isEngineInitialized || _audioBridge == null || _fileInfo == null || _widgetSize.width == 0 || _waveformData.isEmpty) return;

    double fractionX = (globalXPosition / _widgetSize.width).clamp(0.0, 1.0);

    int totalDataPoints = _waveformData.length;
    int visibleDataPoints = (totalDataPoints / _zoomLevel).round().clamp(1, totalDataPoints);

    double maxPannableDataPoints = (totalDataPoints - visibleDataPoints).toDouble();
    if (maxPannableDataPoints < 0) maxPannableDataPoints = 0;
    int startIndex = (_panOffset * maxPannableDataPoints).round().clamp(0, totalDataPoints - visibleDataPoints);

    double tappedDataIndexInView = fractionX * visibleDataPoints;
    double actualDataIndex = startIndex + tappedDataIndexInView;

    double seekFraction = (actualDataIndex / totalDataPoints).clamp(0.0, 1.0);
    double seekTime = seekFraction * _fileInfo!.durationSeconds;

    _audioBridge!.setPlaybackPosition(seekTime);
    setState(() {
      _currentPlaybackPosition = seekTime;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
         Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            icon: _isLoading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(Icons.audiotrack),
            label: Text(_isLoading ? "Loading..." : "Load Audio File"),
            onPressed: (_isLoading || !_isEngineInitialized) ? null : () async {
              if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
                _showFilePathDialog();
              } else {
                 setState(() {
                    _status = "Automatic file picking not set up for this platform.";
                 });
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Text(_status, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        ),
         if (_isEngineInitialized && _fileInfo != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(_isAudioPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                  iconSize: 48.0,
                  onPressed: _togglePlayPause,
                  tooltip: _isAudioPlaying ? "Pause" : "Play",
                ),
                IconButton(
                  icon: Icon(Icons.stop_circle_outlined),
                  iconSize: 48.0,
                  onPressed: _stopPlayback,
                  tooltip: "Stop",
                ),
              ],
            ),
          ),
        if (_fileInfo != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "File: ${_fileInfo!.durationSeconds.toStringAsFixed(2)}s | Playback: ${_currentPlaybackPosition.toStringAsFixed(2)}s
"
              "Zoom: ${_zoomLevel.toStringAsFixed(2)}x | Pan: ${_panOffset.toStringAsFixed(2)}",
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _widgetSize = constraints.biggest;
              return GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onTapDown: (details) {
                  if (_fileInfo != null && _waveformData.isNotEmpty) {
                    _seekToPosition(details.localPosition.dx);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueGrey.shade200),
                    color: Colors.grey.shade800,
                  ),
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : CustomPaint(
                          painter: WaveformPainter(
                            waveformData: _waveformData,
                            defaultColor: Colors.tealAccent,
                            zoomLevel: _zoomLevel,
                            panOffset: _panOffset,
                            playbackPositionSeconds: _currentPlaybackPosition,
                            totalDurationSeconds: _fileInfo?.durationSeconds ?? 1.0,
                          ),
                          size: Size.infinite,
                        ),
                ),
              );
            }
          ),
        ),
      ],
    );
  }

  void _showFilePathDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Enter audio file path"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: "e.g., /path/to/your/audio.mp3"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Navigator.pop(context);
                  _loadAudioFile(controller.text);
                }
              },
              child: Text("Load"),
            ),
          ],
        );
      },
    );
  }
}
