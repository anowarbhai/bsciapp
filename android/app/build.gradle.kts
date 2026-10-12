import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val ciKeystorePath = System.getenv("CM_KEYSTORE_PATH")
val hasCiSigning = !ciKeystorePath.isNullOrBlank()
val produceUnsignedRelease = System.getenv("CM_PRODUCTION_UNSIGNED") == "true"

android {
    namespace = "com.bscibd.bsciapp"
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
        applicationId = "com.bscibd.bsciapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasCiSigning || keystorePropertiesFile.exists()) {
            create("release") {
                if (hasCiSigning) {
                    keyAlias = System.getenv("CM_KEY_ALIAS")
                    keyPassword = System.getenv("CM_KEY_PASSWORD")
                    storeFile = file(ciKeystorePath!!)
                    storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
                } else {
                    keyAlias = keystoreProperties["keyAlias"] as String
                    keyPassword = keystoreProperties["keyPassword"] as String
                    storeFile = file(keystoreProperties["storeFile"] as String)
                    storePassword = keystoreProperties["storePassword"] as String
                }
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (produceUnsignedRelease) {
                null
            } else if (hasCiSigning || keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // Local device builds remain installable until the private Play upload key is supplied.
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
