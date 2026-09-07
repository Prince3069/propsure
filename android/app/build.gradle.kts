import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load key.properties from the android/ folder
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.princedevlabs.propsure"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias      = keystoreProperties["keyAlias"]      as? String
            keyPassword   = keystoreProperties["keyPassword"]   as? String
            storeFile     = keystoreProperties["storeFile"]?.let {
                rootProject.file(it.toString())
            }
            storePassword = keystoreProperties["storePassword"] as? String
        }
    }

    defaultConfig {
        applicationId = "com.princedevlabs.propsure"
        minSdk        = 21
        targetSdk     = 36
        versionCode   = 4   // ← Changed from 3 to 4
        versionName   = "1.0.3"   // ← Changed from 1.0.2 to 1.0.3
    }

    buildTypes {
        release {
            signingConfig     = signingConfigs.getByName("release")
            isMinifyEnabled   = false
            isShrinkResources = false
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}