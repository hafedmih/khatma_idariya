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
// (التي يجرّها pdfx) تتطلب أن تُبنى الوحدات على compileSdk 34+.
// وثبّت هدف JVM على 17 لتفادي تعارض Java/Kotlin (flutter_local_notifications).
subprojects {
    val configureAndroid = {
        (extensions.findByName("android") as? com.android.build.api.dsl.LibraryExtension)
            ?.let {
                it.compileSdk = 36
                it.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
                it.compileOptions.targetCompatibility = JavaVersion.VERSION_17
            }
    }
    if (state.executed) configureAndroid() else afterEvaluate { configureAndroid() }

    // وحّد هدف Kotlin على 17 لكل الوحدات
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
