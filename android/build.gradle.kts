// Top-level build file where you can add configuration options common to all sub-projects/modules.
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Ajouter les dépendances nécessaires pour le support du desugaring
        classpath("com.android.tools.build:gradle:8.1.0")
        // Use the kotlin_version from gradle.properties
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:${rootProject.property("kotlin_version")}")
        // classpath("com.google.gms:google-services:4.4.1") // Commented out
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    if (project.name == "image_picker_android") {
        project.tasks.withType<Test>().configureEach {
            enabled = false
        }
    }
    if (project.name == "speech_to_text") {
        project.tasks.matching { it.name.startsWith("lint") }.configureEach {
            enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
