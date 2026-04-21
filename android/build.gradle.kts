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
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            if (android.namespace == null) {
                // Try to find package from AndroidManifest.xml
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val xml = manifestFile.readText()
                    val packageMatch = Regex("package=\"([^\"]*)\"").find(xml)
                    if (packageMatch != null) {
                        android.namespace = packageMatch.groupValues[1]
                    } else {
                        // Fallback if no package attribute found
                        android.namespace = "generated.namespace.${project.name.replace(":", ".")}"
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
