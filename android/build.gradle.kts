// android/build.gradle.kts
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.1.1") // Plugin Android
        classpath("com.google.gms:google-services:4.4.4")  // Plugin Google Services (FCM)
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.10") // Kotlin plugin
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Optionnel : définir un build directory commun
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}