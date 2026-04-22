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
                androidObject.compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_1_8
                    targetCompatibility = JavaVersion.VERSION_1_8
                }

                // 3. NUCLEAR NAMESPACE FIX: Force a namespace if missing
                if (androidObject.namespace == null) {
                    androidObject.namespace = "com.fix.namespace.${name.replace("-", ".").replace("_", ".")}"
                }
            }
        }

        // 4. Force Kotlin JVM Target 1.8 for all subprojects
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions.jvmTarget = "1.8"
        }
    }

    if (state.executed) {
        fixProject()
    } else {
        afterEvaluate { fixProject() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}