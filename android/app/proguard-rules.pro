# ML Kit Text Recognition — les recognizers de langues optionnels (chinois,
# japonais, coréen, devanagari) sont référencés mais pas embarqués si on
# n'utilise que la reconnaissance latine. On dit à R8 de les ignorer.
-keep class com.google.mlkit.vision.text.** { *; }
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
