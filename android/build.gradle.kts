allprojects {
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral {
            content {
                includeGroupByRegex("org\\.jetbrains.*")
                includeGroupByRegex("org\\.jetbrains.kotlinx.*")
                includeGroupByRegex("com\\.squareup.*")
                includeGroupByRegex("io\\.coil-kt.*")
            }
        }
        // Add alternative repositories as fallback
        maven { url = uri("https://jcenter.bintray.com") }
        maven { url = uri("https://dl.google.com/dl/android/maven2") }
        maven { url = uri("https://repo.maven.apache.org/maven2") }
        maven { url = uri("https://oss.sonatype.org/content/repositories/snapshots") }
        
        // Configure repository timeouts and retry
        configurations.all {
            resolutionStrategy {
                cacheChangingModulesFor(0, "seconds")
                cacheDynamicVersionsFor(0, "seconds")
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
