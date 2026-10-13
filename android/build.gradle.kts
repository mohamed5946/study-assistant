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

// home_widget compiles its Kotlin at JVM target 1.8 but inlines a
// dependency built for JVM 11+, which fails release compilation.
// Raise this module (and only this one) to JVM 11 after all projects
// are evaluated, so its own 1.8 defaults don't win.
gradle.projectsEvaluated {
    val hw = project(":home_widget")
    hw.tasks
        .withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
        .configureEach {
            compilerOptions {
                jvmTarget.set(
                    org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
            }
        }
    hw.tasks
        .withType<org.gradle.api.tasks.compile.JavaCompile>()
        .configureEach {
            sourceCompatibility = "11"
            targetCompatibility = "11"
        }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
