# Lighthouse (iOS)

Offline-first emergency assistant — SwiftUI port of [lighthouse-android](../lighthouse-android).

> **Help when you need it. Works offline.**

## Features

Parity with the Android app:

- **5-step onboarding** → quick start from GPS (or presets)
- **Home** — MapKit map, guidance card, quick reports, voice dock (mic / hands-free / photo+OCR)
- **Agents** — SOS to Ambulance, Police, Fire, Disaster, Child Protection with country numbers
- **Guide** — field console, agent loop, stats, judge demo
- **Activity** — full chat history
- **Settings** — agent brain status, export/import JSON peer sync, reset

Agent loop (on-device rules engine): **Sense → Decide → Act → Verify → Recover**

## Design

Built for Apple’s latest system look:

- iOS 18+ `Tab` API and large titles
- Liquid Glass–inspired materials (`.ultraThinMaterial`, specular strokes, capsule docks)
- System blue / priority colors matching the Android iOS-style palette
- When built with **Xcode 26 / iOS 26**, standard controls pick up **Liquid Glass** automatically

## Requirements

- Xcode 16+ (Xcode 26 recommended for Liquid Glass)
- iOS 18.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Setup

```bash
xcodegen generate
open Lighthouse.xcodeproj
```

## Notes

- **Gemma 4 LiteRT** is Android-specific. iOS ships the full **rules engine** (same parser, planner, SOS, contradictions). Settings keeps variant UI for cross-platform parity.
- SOS **simulates** unit dispatch and shows emergency numbers — it does not place phone calls automatically (tap the number link to dial).
- Mission JSON export/import matches the Android snapshot schema (v1).
