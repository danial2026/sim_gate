# Myket Release Guide for SimGate

## Problem

Myket rejects APKs signed with the debug keystore:

> فایل APK با کلید دیباگ امضا شده است. لطفا نسخه‌ای با کلید انتشار بارگذاری کنید.

> *"The APK file is signed with a debug key. Please upload a version signed with a release key."*

The release build in `android/app/build.gradle.kts` was falling back to the debug signing config:

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

## Solution: Sign the APK with a proper release keystore

---

### Step 1 — Generate a release keystore

Run `keytool` (bundled with Android Studio's JBR):

```bash
KEYTOOL="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"

$KEYTOOL -genkey -v \
  -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload \
  -storepass YOUR_STORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD \
  -dname "CN=Your Name, OU=YourOrg, O=YourOrg, L=City, S=State, C=IR"
```

**Important notes:**
- Choose strong passwords and **save them securely** — you cannot recover them.
- `-validity 10000` = ~27 years of validity.
- `C=IR` is the country code for Iran. Change as needed.
- The keystore file (`upload-keystore.jks`) is ignored by git (`android/.gitignore`).
- After generating, run to verify:
  ```bash
  $KEYTOOL -list -v -keystore android/app/upload-keystore.jks -storepass YOUR_STORE_PASSWORD
  ```

---

### Step 2 — Create `android/key.properties`

This file stores the keystore credentials used by Gradle. It is **not committed** to git (listed in `android/.gitignore`).

File: `android/key.properties`

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=app/upload-keystore.jks
```

The `storeFile` path is **relative to the `android/` root project directory**.

---

### Step 3 — Update `android/app/build.gradle.kts`

The Gradle build script must:
1. Load `key.properties` at the top
2. Define a `signingConfigs { release { ... } }` block
3. Reference it in `buildTypes { release { signingConfig = ... } }`

Final file (`android/app/build.gradle.kts`):

```kotlin
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.danials.sim_gate"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.danials.sim_gate"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }

    applicationVariants.all {
        val variant = this
        variant.outputs.all {
            (this as com.android.build.gradle.internal.api.BaseVariantOutputImpl)
                .outputFileName = "sim_gate-v${variant.versionName}-${name}.apk"
        }
    }
}

flutter {
    source = "../.."
}
```

**Key points:**
- `rootProject.file(...)` resolves paths relative to `android/`, matching the `storeFile` value in `key.properties`.
- If `key.properties` is missing (e.g. CI without secrets), the build falls back to debug signing — this prevents CI breakage but **never upload that APK to stores**.

---

### Step 4 — Build the release APK

**Option A:** Using Flutter CLI (recommended for Flutter-managed builds):
```bash
flutter build apk --release
```

**Option B:** Using Gradle directly (bypasses Flutter's pub-get step, useful when pub.dev is unreachable):
```bash
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  ./gradlew assembleRelease
# Run from the android/ directory
```

The signed APK is output to:
```
build/app/outputs/apk/release/sim_gate-v0.0.8-release.apk
```

---

### Step 5 — Verify the APK is signed with the release key

```bash
APKSIGNER="$HOME/Library/Android/sdk/build-tools/36.1.0/apksigner"
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  $APKSIGNER verify --print-certs \
  build/app/outputs/apk/release/sim_gate-v0.0.8-release.apk
```

Expected output (non-debug certificate):
```
Signer #1 certificate DN: CN=Danial, OU=SimGate, O=SimGate, L=Unknown, ST=Unknown, C=IR
Signer #1 certificate SHA-256 digest: ee39e05668ca92ee1f61b382c02fd03e6ceaa29d74a8c0e5f53b3702d92e4219
Signer #1 certificate SHA-1 digest: 4ab3e088a28fd512c426b51bef13aefd43693a01
Signer #1 certificate MD5 digest: 6b086888ec78742e42c09954315caf07
```

**Do NOT upload** if you see `CN=Android Debug` — that means the debug keystore was used.

---

### Step 6 — Upload to Myket

1. Go to [Myket Developer Panel](https://myket.ir/developer/panel)
2. Select your app
3. Upload `sim_gate-v0.0.8-release.apk`
4. Fill in version changelog (Persian)
5. Submit for review

---

## Troubleshooting

### "pub.dev 403 Forbidden" during `flutter build apk`

If you're in Iran or a sanctioned country, pub.dev may block unauthenticated requests:

```
Authentication error (403)
HTTP response 403 Forbidden for GET https://pub.dev/api/packages/http/advisories
```

**Workaround:** Build with Gradle directly (Option B above) — the dependencies are already locked in `pubspec.lock`.

To permanently fix, authenticate with pub.dev:
```bash
dart pub token add https://pub.dev
```
Then paste a valid token from your pub.dev account settings.

### "Unable to locate a Java Runtime"

Gradle needs Java. Set `JAVA_HOME`:
```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
```
Add this to your `~/.zshrc` or `~/.bashrc` for persistence.

---

## File Summary

| File | Purpose | Git-tracked? |
|------|---------|--------------|
| `android/app/upload-keystore.jks` | Release signing key | No (`.gitignore`) |
| `android/key.properties` | Keystore credentials for Gradle | No (`.gitignore`) |
| `android/app/build.gradle.kts` | Signing config + build logic | Yes |
| `build/app/outputs/apk/release/sim_gate-v*.apk` | Signed release APK | No (`build/`) |

---

## Updating `scripts/dev.sh`

Add a `release` command for convenience:

```bash
  release)
    echo "==> flutter build apk --release"
    flutter build apk --release
    ;;
```
