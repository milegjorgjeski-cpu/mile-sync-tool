# Mile Sync Tool

**Offline Balkan backing track & karaoke preparation tool for live performers.**

Optimized for: Balkan singers, arranger keyboard users, Ketron workflow, MobileSheets, karaoke prep.

---

## Features

| Feature | Description |
|---|---|
| **Import** | MP3/WAV/FLAC audio + TXT/LRC lyrics + stems (vocals/drums/bass/other) |
| **Auto Sync** | Whisper/WhisperX alignment of lyrics to vocal stem |
| **Manual Sync** | Tap-to-sync while playing, ms-level fine editing |
| **Transpose** | ±12 semitones — **drums NEVER transposed** |
| **Trim** | Visual waveform editor with drag handles |
| **Fades** | Fade in/out, configurable ms |
| **Export** | MP3 + embedded SYLT/USLT ID3 tags + LRC + optional Ketron folder |

---

## Build Instructions

### Requirements

- Flutter SDK 3.16+
- Android SDK 33+
- Java 17

### Install

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Run (debug)

```bash
flutter run
```

### Build APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Build AAB (Play Store)

```bash
flutter build appbundle --release
```

---

## Project Structure

```
lib/
├── core/
│   ├── constants/      # App constants
│   ├── theme/          # Dark theme, colors, typography
│   └── utils/          # AudioService, LyricsService, ExportService
├── data/
│   ├── models/         # Project, LyricLine, StemSet, Settings
│   └── repositories/   # Hive persistence
├── features/
│   ├── home/           # Project list
│   ├── import/         # Audio + lyrics + stems import
│   ├── lyrics_sync/    # Auto-sync + manual timing editor
│   ├── transpose/      # Pitch shift (drum-safe)
│   ├── cut_trim/       # Waveform trim editor
│   ├── crossfade/      # Fade in/out
│   └── export/         # ID3/SYLT/LRC export
└── shared/
    └── widgets/        # Reusable UI components
```

---

## Whisper Integration Notes

Auto-sync uses Whisper alignment. On Android, this requires one of:
- **whisper.cpp** compiled as native library (recommended for on-device)
- **WhisperX** via local Python server companion app
- **Aeneas** forced alignment library

The `LyricsService.autoAlignLyrics()` method is the integration point.

---

## Export Formats

| Format | Use case |
|---|---|
| MP3 + SYLT | Karaoke systems, Ketron, Android players with lyrics |
| MP3 + USLT | Standard players with lyrics display |
| LRC | MobileSheets, karaoke players |
| TXT | Generic use |
| Ketron folder | `audio/` + `lyrics/` subfolder structure |

---

*Mile Sync Tool — Made for Balkan live performers.*
