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

// ارفع compileSdk لكل وحدات الإضافات (مكتبات) لأن تبعية exifinterface 1.4.1
// (التي يجرّها pdfx) تتطلب أن تُبنى الوحدات على compileSdk 34+
subprojects {
    val bumpCompileSdk = {
        (extensions.findByName("android") as? com.android.build.api.dsl.LibraryExtension)
            ?.let { it.compileSdk = 36 }
    }
    if (state.executed) bumpCompileSdk() else afterEvaluate { bumpCompileSdk() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
