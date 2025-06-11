import 'package:flutter/material.dart';
import 'juce_ffi.dart'; // Assuming WaveformPointData is here
import 'dart:math' as math;

class WaveformPainter extends CustomPainter {
  final List<WaveformPointData> waveformData;
  final Color defaultColor;
  final double zoomLevel; // 1.0 = full overview, > 1.0 is zoomed in
  final double panOffset; // 0.0 (leftmost) to 1.0 (rightmost) of the *visible* data window if fully panned
  final double playbackPositionSeconds; // Current playback time in seconds
  final double totalDurationSeconds;    // Total duration of the audio in seconds

  WaveformPainter({
    required this.waveformData,
    this.defaultColor = Colors.blueGrey,
    this.zoomLevel = 1.0,
    this.panOffset = 0.0,
    this.playbackPositionSeconds = 0.0,
    this.totalDurationSeconds = 1.0, // Avoid division by zero if no duration
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) {
      // ... (placeholder drawing remains the same) ...
      finalPaint.color = defaultColor;
      TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: 'No waveform data loaded',
          style: TextStyle(color: defaultColor, fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(minWidth: 0, maxWidth: size.width);
      textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));
      return;
    }

    final Paint fillPaint = Paint();
    final Paint playheadPaint = Paint()
      ..color = Colors.redAccent // Or any distinct color
      ..strokeWidth = 2.0;

    // --- Waveform Drawing Logic (mostly same as before) ---
    int totalDataPoints = waveformData.length;
    int visibleDataPoints = (totalDataPoints / zoomLevel).round().clamp(1, totalDataPoints);

    double maxPannableDataPoints = (totalDataPoints - visibleDataPoints).toDouble();
    if (maxPannableDataPoints < 0) maxPannableDataPoints = 0;

    int startIndex = (panOffset * maxPannableDataPoints).round().clamp(0, totalDataPoints - visibleDataPoints);

    double barWidth = size.width / visibleDataPoints;
    if (visibleDataPoints == 0) barWidth = size.width; // Should not happen if visibleDataPoints is clamped to 1

    for (int i = 0; i < visibleDataPoints; i++) {
      int dataIndex = startIndex + i;
      if (dataIndex >= totalDataPoints) break;

      final point = waveformData[dataIndex];
      // ... (bar drawing logic remains the same) ...
      final double yMin = (point.minValue * -0.5 + 0.5) * size.height;
      final double yMax = (point.maxValue * -0.5 + 0.5) * size.height;

      final double top = math.min(yMin, yMax);
      final double bottom = math.max(yMin, yMax);
      final double barHeight = bottom - top;
      final double x = i * barWidth;

      fillPaint.color = Color.fromRGBO(point.r, point.g, point.b, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(x, top, barWidth, barHeight.isFinite && barHeight > 0 ? barHeight : 1.0),
        fillPaint,
      );
    }

    // --- Playhead Drawing Logic ---
    if (totalDurationSeconds > 0 && playbackPositionSeconds >= 0) {
      // Calculate the progress of playback as a fraction (0.0 to 1.0)
      double playbackProgressRatio = (playbackPositionSeconds / totalDurationSeconds).clamp(0.0, 1.0);

      // Determine the x-coordinate of the playhead within the *entire* waveform's span
      // double playheadXInTotalWaveform = playbackProgressRatio * totalDataPoints * barWidth * zoomLevel; // This is x if all data was rendered at current barWidth

      // Convert this to the x-coordinate within the *currently visible window*
      // First, find the x-coordinate of the start of the visible window
      // double visibleWindowStartX = startIndex * barWidth * zoomLevel; // This logic was a bit off, simplified below

      // Playhead position relative to the start of the visible data segment, scaled by current barWidth
      // The playhead position in terms of data index:
      double playheadDataIndexEquivalent = playbackProgressRatio * totalDataPoints;

      // X position on the canvas: (playheadDataIndexEquivalent - startIndex) * barWidth
      double playheadX = (playheadDataIndexEquivalent - startIndex) * barWidth;

      // Draw the playhead only if it's within the visible part of the canvas
      if (playheadX >= 0 && playheadX <= size.width) {
        canvas.drawLine(
          Offset(playheadX, 0),
          Offset(playheadX, size.height),
          playheadPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData ||
           oldDelegate.defaultColor != defaultColor ||
           oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.panOffset != panOffset ||
           oldDelegate.playbackPositionSeconds != playbackPositionSeconds ||
           oldDelegate.totalDurationSeconds != totalDurationSeconds;
  }
}

// Helper Paint instance for placeholder text, if not already defined elsewhere
final Paint finalPaint = Paint();
