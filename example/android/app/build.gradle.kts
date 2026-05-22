import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load key.properties into project ext so project.property() can resolve them.
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    Properties().also { it.load(keyPropertiesFile.inputStream()) }
        .forEach { k, v -> ext.set(k.toString(), v.toString()) }
}

android {
    namespace = "com.cmc.c_shield_sdk_example"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("debug-build") {
            storeFile = file("../keystore/flutter-cshield-debug.jks")
            storePassword = project.property("DEBUG_KEYSTORE_PASSWORD") as String
            keyAlias = project.property("DEBUG_KEY_ALIAS") as String
            keyPassword = project.property("DEBUG_KEYSTORE_PASSWORD") as String
        }

        create("release-build") {
            storeFile = file("../keystore/flutter-cshield-release.jks")
            storePassword = project.property("RELEASE_KEYSTORE_PASSWORD") as String
            keyAlias = project.property("RELEASE_KEY_ALIAS") as String
            keyPassword = project.property("RELEASE_KEYSTORE_PASSWORD") as String
        }
    }

    defaultConfig {
        applicationId = "com.cmc.c_shield_sdk_example"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
      
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug-build")
        }
        release {
            signingConfig = signingConfigs.getByName("release-build")
        }
    }
}

dependencies {
    // c-shield-sdk AAR must be placed in android/app/libs/ by the consumer.
    // The plugin uses compileOnly — this implementation provides the runtime classes.
    // Use the matching variant so the AAR's signing-certificate check passes.
    debugImplementation(files("libs/c-shield-sdk-debug.aar"))
    releaseImplementation(files("libs/c-shield-sdk-release.aar"))

    // Transitive deps of c-shield-sdk — not auto-resolved when using files().
    // The AAR's ThreatDetectedActivity uses Jetpack Compose internally.
    implementation(platform("androidx.compose:compose-bom:2024.09.00"))
    implementation("androidx.compose.runtime:runtime")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.11.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
}

flutter {
    source = "../.."
}
