import org.gradle.api.tasks.Delete

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Gradle plugin versi stabil untuk Flutter + Android SDK 36
        classpath("com.android.tools.build:gradle:8.3.2")

        // Kotlin versi aman dan kompatibel
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.24")

        // Google services plugin terbaru
        classpath("com.google.gms:google-services:4.4.2")
    }
}

// Atur direktori build agar seragam
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Paksa semua modul pakai compileSdk 36
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            project.extensions.configure<com.android.build.gradle.BaseExtension> {
                compileSdkVersion(36)
            }
        }
    }
}

// Task clean
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
