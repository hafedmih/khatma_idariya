import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase Cloud Messaging — يُطبَّق فقط عند وجود google-services.json
// (حتى يبقى البناء ناجحاً قبل إعداد Firebase)
if (project.file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// إعدادات التوقيع للإصدار (من android/key.properties — غير مضمّن في Git)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.hafedmih.khatma"
    // AndroidX core 1.17.0 (transitive) requires compileSdk 36
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // مطلوب لـ flutter_local_notifications (Java 8+ APIs)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.hafedmih.khatma"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias      = keystoreProperties["keyAlias"] as String?
            keyPassword   = keystoreProperties["keyPassword"] as String?
            storeFile     = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // عطّل تصغير/تشويش الشيفرة: R8 كان يحذف معلومات أنواع Gson
            // التي يحتاجها flutter_local_notifications (خطأ "Missing type parameter")
            isMinifyEnabled = false
            isShrinkResources = false
        }
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
