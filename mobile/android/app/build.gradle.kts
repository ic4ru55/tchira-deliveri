import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { stream ->
        localProperties.load(stream)
    }
}

android {
    namespace = "com.tchira.tchira_delivery"
    compileSdk = 34 // Version fixe pour plus de stabilité
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ✅ Requis pour flutter_local_notifications (APIs Java 8+ sur anciens Android)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.tchira.tchira_delivery"
        minSdk = 23 // Version minimale augmentée pour la compatibilité
        targetSdk = 34
        versionCode = 1 // À ajuster selon ton besoin
        versionName = "1.0.0" // À ajuster selon ton besoin

        // ✅ Récupération de la clé API Maps
        val mapsApiKey = localProperties.getProperty("MAPS_API_KEY", "")
        
        // ✅ Passage à AndroidManifest.xml
        manifestPlaceholders["mapsApiKey"] = mapsApiKey
        
        // ✅ Passage au code Dart via --dart-define
        resValue("string", "maps_api_key", mapsApiKey)
    }

    buildTypes {
        release {
            // TODO: Configurer la signature release plus tard
            signingConfig = signingConfigs.getByName("debug")
            
            // ✅ Optimisations pour la release
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        
        debug {
            // ✅ Config debug explicite
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    
    // ✅ Gestion des variantes
    flavorDimensions += "default"
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Requis pour le core library desugaring (flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    // ✅ Dépendances Firebase (optionnel mais recommandé)
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-analytics")
}

// ✅ Application du plugin Google Services en fin de fichier
apply(plugin = "com.google.gms.google-services")