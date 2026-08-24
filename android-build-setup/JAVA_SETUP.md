# Java 21 Setup Instructions

## Why Java 21?

The project requires Java 21 because:
- Gradle 8.12 requires Java 17 or higher
- Java 24 (and newer) are not yet fully supported by Gradle
- Java 21 is the current LTS (Long Term Support) version

## Installation Methods

### Method 1: Download and Extract (Recommended - No Admin Required)

```bash
# Create directory for JDK
mkdir -p ~/jdk
cd ~/jdk

# Download Java 21 (macOS ARM64)
curl -L -o jdk21.tar.gz "https://api.adoptium.net/v3/binary/latest/21/ga/mac/aarch64/jdk/hotspot/normal/eclipse"

# Extract
tar -xzf jdk21.tar.gz

# Verify installation
~/jdk/jdk-21.0.9+10/Contents/Home/bin/java -version
```

**Expected output:**
```
openjdk version "21.0.9" 2024-04-16
OpenJDK Runtime Environment Temurin-21.0.9+10 (build 21.0.9+10)
OpenJDK 64-Bit Server VM Temurin-21.0.9+10 (build 21.0.9+10, mixed mode, sharing)
```

### Method 2: Using Homebrew (Requires Admin)

```bash
brew install --cask temurin@21
```

### Method 3: Using SDKMAN

```bash
curl -s "https://get.sdkman.io" | bash
sdk install java 21.0.9-tem
```

## Configure Gradle to Use Java 21

After installing Java 21, update `android/gradle.properties`:

```properties
org.gradle.java.home=/Users/YOUR_USERNAME/jdk/jdk-21.0.9+10/Contents/Home
```

**For Linux:**
```properties
org.gradle.java.home=/home/YOUR_USERNAME/jdk/jdk-21.0.9+10
```

**For Windows:**
```properties
org.gradle.java.home=C:\\Users\\YOUR_USERNAME\\jdk\\jdk-21.0.9+10
```

## Verify Java Setup

```bash
cd /path/to/cognify-flutter
flutter doctor -v
```

Look for the Java version in the output - it should show Java 21.

## Alternative: Use Android Studio's Bundled JDK

If Android Studio is installed, you can use its bundled JDK:

```properties
org.gradle.java.home=/Applications/Android Studio.app/Contents/jbr/Contents/Home
```

**Note:** Check the actual path on your system as it may vary.



