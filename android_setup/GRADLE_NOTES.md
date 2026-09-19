# Android Gradle tweaks (do these after `flutter create .`)

`flutter_local_notifications` needs Java 8+ desugaring, and Firebase needs the
Google Services plugin. Recent Flutter projects use the **Kotlin DSL**
(`build.gradle.kts`); older ones use Groovy (`build.gradle`). Snippets for both.

---

## 1. android/app/build.gradle(.kts)

### Set SDK + enable desugaring

**Groovy (`build.gradle`)** — inside `android { }`:
```groovy
android {
    compileSdk 34
    defaultConfig {
        applicationId "com.khurram.dailyhub"
        minSdk 23           // Firebase Auth needs >= 23
        targetSdk 34
        multiDexEnabled true
    }
    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}
dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.2'
}
```

**Kotlin DSL (`build.gradle.kts`)** — inside `android { }`:
```kotlin
android {
    compileSdk = 34
    defaultConfig {
        applicationId = "com.khurram.dailyhub"
        minSdk = 23
        targetSdk = 34
        multiDexEnabled = true
    }
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
}
```

### Apply the Google Services plugin (bottom of the app-level file)
Groovy: `apply plugin: 'com.google.gms.google-services'`
Kotlin DSL: add `id("com.google.gms.google-services")` to the `plugins { }` block.

---

## 2. Register the Google Services plugin at project level

**Newer Flutter (settings.gradle / settings.gradle.kts) — plugins block:**
```
id "com.google.gms.google-services" version "4.4.2" apply false
```

**Older Flutter (android/build.gradle) — buildscript dependencies:**
```groovy
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.2'
    }
}
```

---

## 3. Drop in google-services.json
Place your downloaded `google-services.json` at:
`android/app/google-services.json`
(See README step 3 for how to get it.)

---

## 4. iOS (only if you build for iPhone)
- Run `flutterfire configure` (easiest) — it writes GoogleService-Info.plist.
- In `ios/Runner/Info.plist` add the reversed client ID URL scheme for Google Sign-In.
- Minimum iOS 13.
