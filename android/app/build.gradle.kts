import java.io.FileInputStream
import java.net.URI
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.vero.app.vero"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.vero.app.vero"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"]?.toString()
                keyPassword = keystoreProperties["keyPassword"]?.toString()
                storeFile = file(keystoreProperties["storeFile"]?.toString() ?: "")
                storePassword = keystoreProperties["storePassword"]?.toString()
            }
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// The account configuration must reach the Dart compiler, not just exist on disk.
val encodedDartDefines = providers.gradleProperty("dart-defines").orElse("")
val verifyAccountConfiguration = tasks.register("verifyAccountConfiguration") {
    doLast {
        val defines = encodedDartDefines.get().split(',').filter { it.isNotBlank() }.associate {
            val decoded = String(Base64.getDecoder().decode(it), Charsets.UTF_8)
            val parts = decoded.split('=', limit = 2)
            parts[0] to parts.getOrElse(1) { "" }
        }
        val url = defines["SUPABASE_URL"].orEmpty()
        val key = defines["SUPABASE_ANON_KEY"].orEmpty()
        val uri = runCatching { URI(url) }.getOrNull()
        if (uri?.scheme != "https" || uri?.host.isNullOrBlank() ||
            url.contains("YOUR_PROJECT") || key.length < 20 ||
            key.contains("YOUR_PUBLIC") || key.contains("service_role", ignoreCase = true) ||
            key.startsWith("sb_secret_", ignoreCase = true)
        ) {
            throw GradleException(
                "Vero: configuracao de conta ausente ou invalida no build. " +
                    "Use --dart-define-from-file=config/supabase.json " +
                    "(ou config/release.json para publicacao)."
            )
        }
    }
}
tasks.configureEach {
    if (name.startsWith("compileFlutterBuild")) {
        dependsOn(verifyAccountConfiguration)
    }
}
