# DJKU Agent Skeleton

This repository contains skeleton code inspired by the architecture described in
`AGENTS.md`. The system is split into multiple agents, each handling a specific
aspect of audio playback and visualization.

## Agents

- **FileManagerAgent** – loads audio files and metadata.
- **WaveformAgent** – generates waveform data for visualization.
- **BeatDetectionAgent** – performs BPM analysis and detects beat positions.
- **SpectrumAgent** – computes real-time FFT data.
- **RenderingAgent** – combines waveform and beat data to render frames.
- **PlaybackAgent** – controls playback operations.
- **BridgeAgent** – communicates between Flutter and native code.
- **StateAgent** – optional agent for global state synchronization.

The files under `src/agents/` provide minimal C++ class stubs that can be
expanded to implement the full functionality described in `AGENTS.md`.
