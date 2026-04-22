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

// PRO FIX: Use AGP finalizeDsl to safely inject settings before they are locked
subprojects {
    val androidComponents = extensions.findByType<com.android.build.api.variant.AndroidComponentsExtension<*, *, *>>()
    if (androidComponents != null) {
        androidComponents.finalizeDsl { dsl ->
            // 1. Force minSdk 21
            if ((dsl.defaultConfig.minSdk ?: 0) < 21) {
                dsl.defaultConfig.minSdk = 21
            }

            // 2. Force Java 1.8 compatibility
            dsl.compileOptions.sourceCompatibility = JavaVersion.VERSION_1_8
            dsl.compileOptions.targetCompatibility = JavaVersion.VERSION_1_8

            // 3. Force namespace if missing
            if (dsl.namespace == null) {
                dsl.namespace = "com.fix.namespace.${name.replace("-", ".").replace("_", ".")}"
            }
        }
    }

    // 4. Force Kotlin JVM Target 1.8
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions.jvmTarget = "1.8"
    }

    // 5. Fallback for non-component plugins (Ensures Java 1.8 everywhere)
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "1.8"
        targetCompatibility = "1.8"
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}