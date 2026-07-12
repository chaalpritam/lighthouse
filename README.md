# Lighthouse

SwiftUI iOS app (iOS 17+).

## Requirements

- [Xcode 16+](https://developer.apple.com/xcode/) (full Xcode app, not only Command Line Tools)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Setup

```bash
xcodegen generate
open Lighthouse.xcodeproj
```

Select an iPhone simulator and press **Run** (⌘R).

## Project layout

```
Lighthouse/
  LighthouseApp.swift   # App entry point
  ContentView.swift     # Root UI
  Assets.xcassets/      # Icons & colors
project.yml             # XcodeGen project definition
```

Regenerate the Xcode project after editing `project.yml`:

```bash
xcodegen generate
```
