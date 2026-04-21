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

// Global fix for AGP 8.0+ namespace requirement in old plugins
subprojects {
    val fixNamespace: Project.() -> Unit = {
        if (hasProperty("android")) {
            val androidObject = extensions.getByName("android")
            if (androidObject is com.android.build.gradle.BaseExtension) {
                if (androidObject.namespace == null) {
                    val manifestFile = file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val xml = manifestFile.readText()
                        val packageMatch = Regex("package=\"([^\"]*)\"").find(xml)
                        if (packageMatch != null) {
                            androidObject.namespace = packageMatch.groupValues[1]
                        } else {
                            androidObject.namespace = "generated.namespace.${name.replace(":", ".")}"
                        }
                    }
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
