import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.nextgen.aura.dating"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.nextgen.aura.dating"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keyAliasProp = keystoreProperties.getProperty("keyAlias")
            val keyPasswordProp = keystoreProperties.getProperty("keyPassword")
            val storeFileProp = keystoreProperties.getProperty("storeFile")
            val storePasswordProp = keystoreProperties.getProperty("storePassword")

            val cmKeystore = System.getenv("CM_KEYSTORE_PATH")
            val effectiveStoreFile = if (!cmKeystore.isNullOrBlank() && file(cmKeystore).exists()) cmKeystore else storeFileProp

            if (!keyAliasProp.isNullOrBlank() &&
                !keyPasswordProp.isNullOrBlank() &&
                !effectiveStoreFile.isNullOrBlank() &&
                !storePasswordProp.isNullOrBlank() &&
                file(effectiveStoreFile).exists()
            ) {
                keyAlias = keyAliasProp
                keyPassword = keyPasswordProp
                storeFile = file(effectiveStoreFile)
                storePassword = storePasswordProp
            } else {
                val isCI = System.getenv("CI") != null || System.getenv("CM_BUILD_ID") != null
                val wantsRelease = gradle.startParameter.taskNames.any {
                    it.contains("release", ignoreCase = true) ||
                        it.contains("bundle", ignoreCase = true)
                }
                if (wantsRelease && !isCI) {
                    throw GradleException(
                        "Release signing not configured: create android/key.properties " +
                            "(keyAlias, keyPassword, storeFile, storePassword) pointing to an existing keystore."
                    )
                } else if (isCI) {
                    val debugSigning = signingConfigs.getByName("debug")
                    keyAlias = debugSigning.keyAlias
                    keyPassword = debugSigning.keyPassword
                    storeFile = debugSigning.storeFile
                    storePassword = debugSigning.storePassword
                }
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
	implementation(platform("com.google.firebase:firebase-bom:34.19.0"))
	implementation("com.google.firebase:firebase-analytics")
}
