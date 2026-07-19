allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// file_picker 8.x (pinned — see pubspec) hardcodes compileSdk 34, but
// flutter_plugin_android_lifecycle's AAR metadata demands >= 36. Lift every
// plugin module to the app's compileSdk.
subprojects {
    fun liftCompileSdk() {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
            ?.compileSdkVersion(36)
    }
    // evaluationDependsOn(":app") above means some subprojects are already
    // evaluated by the time this runs.
    if (state.executed) liftCompileSdk() else afterEvaluate { liftCompileSdk() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
