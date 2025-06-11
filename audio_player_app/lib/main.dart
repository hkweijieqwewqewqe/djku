import 'package:flutter/material.dart';
import 'waveform_display_widget.dart'; // Import the new widget

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter JUCE Audio Player',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        brightness: Brightness.dark, // Dark theme often suits audio apps
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter + JUCE Audio Player Demo'),
        ),
        body: const WaveformDisplayWidget(), // Use the waveform display widget
      ),
    );
  }
}
