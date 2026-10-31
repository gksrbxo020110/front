# ── WorkManager (ML Kit 자세 인식이 사용) — 릴리스에서 DB 클래스가 지워져 앱이 꺼지는 문제 방지 ──
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# ── TFLite (보호구 감지 모델) ──
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# ── ML Kit ──
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**