# Keep generic signatures for Gson used by flutter_local_notifications
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Gson TypeToken
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# flutter_local_notifications scheduled notification models
-keep class com.dexterous.** { *; }
