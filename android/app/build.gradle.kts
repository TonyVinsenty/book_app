import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing key and passwords live outside the repository. Gradle reads
// the path to a properties file with them from the BOOKAPP_KEYSTORE_PROPERTIES
// environment variable (docs/how-to-android-release.md).
val keystorePropertiesPath: String? = System.getenv("BOOKAPP_KEYSTORE_PROPERTIES")
val keystoreProperties = Properties()
var hasKeystoreProperties = false
if (keystorePropertiesPath != null) {
    val propertiesFile = File(keystorePropertiesPath)
    if (propertiesFile.exists()) {
        try {
            FileInputStream(propertiesFile).use { keystoreProperties.load(it) }
            hasKeystoreProperties = true
        } catch (e: Exception) {
            hasKeystoreProperties = false
        }
    }
}

android {
    namespace = "com.tonyvinsenty.bookapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.tonyvinsenty.bookapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystoreProperties) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasKeystoreProperties) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

// A release build signed with anything but our key is useless: an update would
// not install over the previous version. So release builds stop with a clear
// message; debug and profile builds keep working without the variable.
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { task ->
        task.name.contains("Release") &&
            (task.name.startsWith("assemble") ||
                task.name.startsWith("bundle") ||
                task.name.startsWith("package"))
    }
    if (buildingRelease && !hasKeystoreProperties) {
        throw GradleException(
            "Ключ подписи не найден: задайте переменную окружения " +
                "BOOKAPP_KEYSTORE_PROPERTIES, см. docs/how-to-android-release.md"
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
