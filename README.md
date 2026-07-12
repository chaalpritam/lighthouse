# Lighthouse

### Offline Emergency Assistant for iOS

> **Help when you need it. Works offline.**

---

# Overview

Lighthouse is an **offline-first emergency assistant** for anyone in a crisis — not just trained responders. Open the app, see where you are on a map, describe what's happening by voice or text, and get **clear guidance on what to do next**.

Under the hood it runs a **local agent** (on-device **rules engine**): it remembers incidents, geotags reports, routes SOS to the right teams, detects contradictions, and speaks responses aloud — **without cloud AI**.

Built for the **Google DeepMind Bangalore Hackathon – Best Use of Gemma 4: Local-First Agents**, and designed so **anyone** can use it in an emergency.

---

# The Problem

During disasters such as:

* Earthquakes
* Floods
* Landslides
* Cyclones
* Building collapses
* Forest fires

internet connectivity often disappears.

Cloud AI assistants stop working. Offline chatbots only answer questions — they do **not**:

* remember rescue operations
* coordinate multiple incidents
* recover from missing information
* keep mission state
* continuously plan

This is where Lighthouse comes in.

---

# Solution

Lighthouse is a **map-first emergency app** with an autonomous on-device agent.

1. **Home (map)** — your GPS, MapKit map, *What to do* guidance, quick reports, voice mic  
2. **Agents** — SOS to ambulance, police, fire, disaster, or child-protection teams by location + country  
3. **Guide** — full field console for power users and demos  
4. **Activity** — message history  
5. **Settings** — agent brain status, peer sync, reset  

It runs the full agent loop locally:

```
Sense → Decide → Act → Verify → Recover
```

**Offline:** agent inference (rules), voice, SwiftData, SOS routing, incident memory.  
**Online (optional):** MapKit map tiles / reverse geocoding when the network is available.

---

# Core Features

## Map-First Home Screen

The default tab is **Home** — built around where you are.

* **MapKit** with your location and priority-colored incident pins
* **What to do** card — latest agent guidance and next plan steps
* **Quick report chips** — *"There's a fire near me"*, *"People trapped"*, etc.
* **Voice dock** — mic, hands-free, photo + Vision OCR at the bottom of the home screen

## Emergency Agents (SOS)

The **Agents** tab routes SOS to specialized teams based on your input, GPS, and country:

| Agent | Examples |
| ----- | -------- |
| Ambulance | injured, chest pain, unconscious |
| Police | crime, attack, robbery |
| Fire & Rescue | fire, smoke, trapped |
| Disaster Response | flood, earthquake, storm |
| Child Protection | missing child, children in danger |

* **Auto SOS** — classifies your description and dispatches  
* **Per-agent SOS** buttons with available / assigned unit counts  
* **Country-aware numbers** — India (112/100/101/102/1098), US/CA (911), UK (999), AU (000), else 112  
* Dispatches local units (**simulated** on-device) and logs geotagged incidents  
* Tap the number link to dial — the app does **not** place calls automatically  

## Voice-First Reporting

* Tap the mic on **Home** or **Agents** and describe what's happening  
* Lighthouse responds **by voice** with what to do next  
* Uses on-device `SFSpeechRecognizer` + `AVSpeechSynthesizer`; the rules engine parses the report  

## Consumer Onboarding

A **5-step flow** ending with **Get started** — uses your GPS, no mission setup required.

1. Welcome  
2. How it helps (agent loop)  
3. Permissions (mic required, location recommended) + voice test  
4. Optional AI / brain status  
5. Ready — quick start, or advanced custom mission + presets  

**Presets:** Earthquake Chennai, Flood Kerala, Building Collapse Mumbai.

## Field Console (Guide Tab)

Power-user / demo view with:

* Agent loop bar (Sense → Decide → Act → Verify → Recover)  
* Mission stats grid  
* Agent briefing and plan steps  
* Incident cards and recent timeline  
* **Play** demo (scripted Chennai earthquake scenario)  

## Offline Mission Management

Missions, incidents, victims, resources, timeline, chat, and memory stored in **SwiftData** — survives app restarts and airplane mode.

## Intelligent Priority Engine

Incidents scored by severity, demographics, accessibility, and age. Priority recalculates when reports change (`critical` / `high` / `medium` / `low`).

## Local Error Recovery

Asks for clarification instead of guessing — e.g. *"There may be another child"* triggers confirm questions (age, conscious?, trapped?, injured?).

## Contradiction Detection

Detects conflicting victim counts and updates the mission after confirmation.

## Mission Timeline & Offline Search

Query by voice or text:

* *"How many critical incidents?"*  
* *"Where am I?"*  
* *"Show timeline."*  
* *"Nearest incident"*  

## Peer Sync

**Settings → Export / Import mission JSON** — offline mission snapshot schema **v1** for sharing between devices.

---

# Design

Built for Apple’s latest system look:

* iOS 18+ `Tab` API, large titles, and NavigationStack  
* **Liquid Glass–inspired** materials (`.ultraThinMaterial`, specular strokes, capsule voice dock)  
* System blue and priority colors for incident severity  
* When built with **Xcode 26 / iOS 26**, standard controls pick up **Liquid Glass** automatically  

---

# Tech Stack

| Layer | Technology |
| ----- | ---------- |
| Platform | Swift 5, iOS 18+ |
| UI | SwiftUI (Liquid Glass–ready) |
| Maps | MapKit |
| Architecture | `@Observable` ViewModel → Repository → SwiftData |
| Database | SwiftData |
| Location | Core Location + CLGeocoder (country-aware SOS) |
| Voice | SFSpeechRecognizer + AVSpeechSynthesizer |
| OCR | Vision (`VNRecognizeTextRequest`) |
| Agent | On-device rules engine (parser, planner, SOS, recovery) |
| Project | [XcodeGen](https://github.com/yonaskolb/XcodeGen) |

---

# Project Structure

```
lighthouse-ios/
├── Lighthouse/
│   ├── Agent/                 # Orchestrator, parser, SOS, planner, demo
│   ├── Data/                  # MissionRepository, JSON peer sync
│   ├── Models/                # SwiftData models
│   ├── Services/              # Location, voice, field capture / OCR
│   ├── Theme/                 # Design system (glass cards, colors)
│   ├── ViewModels/            # MissionViewModel
│   ├── Views/
│   │   ├── Onboarding/
│   │   ├── Home/              # Map-first home + voice dock
│   │   ├── Agents/            # SOS screen
│   │   ├── Guide/             # Field console
│   │   ├── Activity/          # Chat log
│   │   ├── Settings/
│   │   ├── Components/
│   │   ├── MainTabView.swift
│   │   └── RootView.swift
│   ├── Assets.xcassets/
│   └── LighthouseApp.swift
├── project.yml                # XcodeGen definition
├── Lighthouse.xcodeproj/
└── README.md
```

---

# Getting Started

## Prerequisites

* [Xcode](https://developer.apple.com/xcode/) 16+ (Xcode 26 recommended for Liquid Glass)
* iOS 18.0+ Simulator or device  
* [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)  
* Physical device recommended for microphone / speech recognition  

## Build & Run

```bash
# Generate the Xcode project (after editing project.yml)
xcodegen generate

# Open in Xcode
open Lighthouse.xcodeproj
```

Select an iPhone simulator or device, then press **Run** (⌘R).

### Permissions

On first launch the app requests:

| Permission | Why |
| ---------- | --- |
| Microphone | Voice reports |
| Speech Recognition | On-device STT |
| Location When In Use | Geotag incidents + country SOS numbers |
| Camera / Photos | Field photo capture + OCR |

---

# Onboarding Guide

1. **Welcome** — tagline and feature overview  
2. **How it helps** — Sense → Decide → Act → Verify → Recover  
3. **Permissions** — enable mic (required), location (recommended); optional voice test  
4. **Optional AI** — brain / variant status  
5. **Ready** — **Get started** creates an emergency mission at your GPS  

Advanced: custom mission name / disaster type / location, or pick a regional preset.

After **Reset** in Settings (clears SwiftData + `captures/`), onboarding appears again until a new active mission exists.

---

# Agent Brain

* Lighthouse runs an **offline rules engine** — parse, plan, SOS, contradictions, and queries all work without the network.  
* The bottom **status bar** shows the active brain mode.  

---

# Demo (Guide → Play)

Scripted walkthrough:

1. Critical collapse report (children trapped)  
2. Unconscious victim update  
3. Contradiction (victim count)  
4. Blocked road  
5. Rescue logged  
6. Critical-incident query  
