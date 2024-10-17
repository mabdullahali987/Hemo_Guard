# ML Kit text recognition ships optional script recognizers (Chinese, Japanese,
# Korean, Devanagari) that we don't bundle. R8 must not fail on their absence —
# we only use the Latin recognizer.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-keep class com.google.mlkit.vision.text.** { *; }
