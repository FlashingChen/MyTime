import java.util.Properties
import java.io.ByteArrayOutputStream

fun keychainPassword(service: String): String {
    val output = ByteArrayOutputStream()
    val process = ProcessBuilder(
        "security",
        "find-generic-password",
        "-a",
        "MyTime Android Release",
        "-s",
        service,
        "-w",
    ).redirectErrorStream(true).start()
    process.inputStream.copyTo(output)
    if (process.waitFor() != 0) {
        throw GradleException("Missing Keychain password for $service")
    }
    return output.toString().trim()
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

// CI (GitHub Actions / CNB) 通过环境变量注入签名材料;本地 macOS 回退 key.properties + Keychain。
val env = System.getenv()
val keystoreFileFromEnv = env["ANDROID_KEYSTORE_FILE"]?.takeIf { it.isNotBlank() }
val keystorePasswordFromEnv = env["ANDROID_KEYSTORE_PASSWORD"]?.takeIf { it.isNotBlank() }
val keyPasswordFromEnv = env["ANDROID_KEY_PASSWORD"]?.takeIf { it.isNotBlank() }
val keyAliasFromEnv = env["ANDROID_KEY_ALIAS"]?.takeIf { it.isNotBlank() }

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mytime.mytime"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications needs java.time backported to pre-26
        // devices for scheduled notifications.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mytime.mytime"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists() || keystoreFileFromEnv != null) {
            create("release") {
                keyAlias = keyAliasFromEnv ?: keystoreProperties.getProperty("keyAlias")
                storeFile = file(keystoreFileFromEnv ?: keystoreProperties.getProperty("storeFile"))
                storePassword = keystorePasswordFromEnv ?: keychainPassword(
                    "com.mytime.mytime.android.release.store-password",
                )
                keyPassword = keyPasswordFromEnv ?: keychainPassword(
                    "com.mytime.mytime.android.release.key-password",
                )
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
