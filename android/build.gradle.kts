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

// Global fix for AGP 8.0+ / JVM Target / NDK compatibility
subprojects {
    val fixProject: Project.() -> Unit = {
        if (hasProperty("android")) {
            val androidObject = extensions.getByName("android")
            if (androidObject is com.android.build.gradle.BaseExtension) {
                // 1. Force minSdk to 21 for all plugins to satisfy NDK [CXX1110]
                if ((androidObject.defaultConfig.minSdk ?: 0) < 21) {
                    androidObject.defaultConfig.minSdk = 21
                }

                // 2. Force JVM Target 1.8 (Most compatible with plugins)
                tasks.withType<org.gradle.api.tasks.compile.JavaCompile>().configureEach {
                    sourceCompatibility = JavaVersion.VERSION_1_8.toString()
                    targetCompatibility = JavaVersion.VERSION_1_8.toString()
                }

                // 3. Fix missing namespaces for AGP 8.0+
                // Many older plugins like 'agora_uikit' don't have a namespace set
                if (androidObject.namespace == null) {
                    val manifestFile = file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val xml = manifestFile.readText()
                        // Extract package name from AndrodManifest.xml
                        val packageMatch = Regex("package=\"([^\"]*)\"").find(xml)
                        if (packageMatch != null) {
                            androidObject.namespace = packageMatch.groupValues[1]
                        } else {
                            // Fallback if no package found
                            androidObject.namespace = "generated.namespace.${name.replace(":", ".")}"
                        }
                    }
                }
            }
        }
    }

    // Trigger the fix safely at the right time
    if (state.executed) {
        fixProject()
    } else {
        beforeEvaluate { fixProject() }
    }

    // 4. Force Kotlin JVM Target 1.8 for all subprojects
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions.jvmTarget = "1.8"
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}