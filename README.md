# HemoGuard

HemoGuard is a Flutter application that scans a Complete Blood Count (CBC)
report, extracts the blood indices with on-device OCR, and runs an on-device
machine-learning model to screen for Thalassemia — no network connection or
backend required.

## How it works

1. **Capture / pick** a CBC report image (camera or gallery).
2. **Preprocess** the image for better legibility (`image_preprocessor.dart`).
3. **OCR** the report text with Google ML Kit text recognition.
4. **Parse** the recognised text into structured CBC values (`cbc_parser.dart`).
5. **Predict** using a pure-Dart re-implementation of an XGBoost binary-logistic
   model (`thalassemia_predictor.dart`, weights in `assets/xgboast.json`).

The parser and predictor are pure Dart with no Flutter dependency, so they run
in host unit tests and in an offline benchmark harness (`tool/ocr_bench.dart`).

## Tech stack

- Flutter + [GetX](https://pub.dev/packages/get) for state management and routing
- `google_mlkit_text_recognition` for OCR
- `camera` / `image_picker` for capture
- `image` for preprocessing

## Getting started

```bash
flutter pub get
flutter run
```

## Testing

```bash
flutter test                   # CBC parser + predictor unit tests
dart run tool/ocr_bench.dart   # offline parser/OCR benchmark
```

## Project layout

```
lib/app/
  data/        CBC parser + Thalassemia predictor (pure Dart)
  modules/     home and scanner GetX modules
  routes/      route + page definitions
  theme/       colors and typography
```
