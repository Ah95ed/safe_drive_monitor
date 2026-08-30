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
 // subprojects {
  //  project.evaluationDependsOn(":app")
 // }

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
subprojects {
    afterEvaluate {
        if (project.name == "camera_android_camerax") {
            project.dependencies.add(
                "implementation",
                "androidx.concurrent:concurrent-futures:1.2.0"
            )
        }
         
    }
}
subprojects {
    configurations.all {
        resolutionStrategy.dependencySubstitution {
            substitute(module("org.tensorflow:tensorflow-lite"))
                .using(module("com.google.ai.edge.litert:litert:1.4.0"))
            substitute(module("org.tensorflow:tensorflow-lite-gpu"))
                .using(module("com.google.ai.edge.litert:litert-gpu:1.4.0"))
        }
    }
}
