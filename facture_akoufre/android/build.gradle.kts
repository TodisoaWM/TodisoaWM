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

// Force compileSdk 35 for all Android plugin subprojects (fixes android:attr/lStar)
subprojects {
    // Some projects are already evaluated before this block runs (Gradle lifecycle quirk)
    if (state.executed) {
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.compileSdkVersion(35)
    } else {
        afterEvaluate {
            extensions.findByType<com.android.build.gradle.BaseExtension>()?.compileSdkVersion(35)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
