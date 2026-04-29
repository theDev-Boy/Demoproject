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

// Standard build configuration
subprojects {
    project.evaluationDependsOn(":app")
}

// Global fix for AGP 8.0+ namespace requirement
subprojects {
    val fixNamespace: Project.() -> Unit = {
        if (hasProperty("android")) {
            val androidObject = extensions.getByName("android")
            if (androidObject is com.android.build.gradle.BaseExtension) {
                if (androidObject.namespace == null) {
                    androidObject.namespace = "com.fix.namespace.${name.replace("-", ".").replace("_", ".")}"
                }
            }
        }
    }

    if (state.executed) {
        fixNamespace()
    } else {
        afterEvaluate { fixNamespace() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}