# 🐦 Flutter Android DevContainer

(_🇫🇷 French version available_)

This `.devcontainer` has been designed by **Qwen3.8-Max** in order to run on a **Windows 10** host with **WSL2**, and **Docker CE** installed on it.

It supports **Android** development, with testing on an **emulator** running on the Windows host or on a **physical device** via ADB over USB or Wi-Fi.

---

## 📑 Table of Contents

- [What This DevContainer Does](#-what-this-devcontainer-does)
- [Architecture](#️-architecture)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Daily Usage](#-daily-usage)
- [Project Structure](#-project-structure)
- [Useful Commands](#️-useful-commands)
- [Diagnostics](#-diagnostics)
- [Troubleshooting](#-troubleshooting)
- [Customization](#️-customization)
- [Known Limitations](#-known-limitations)

---

## 🎯 What This DevContainer Does

| Feature | Supported |
|---|---|
| Flutter Android development | ✅ |
| Build APK / AAB | ✅ |
| Hot reload / Hot restart | ✅ |
| Testing on physical Android device (USB) | ✅ |
| Testing on physical Android device (Wi-Fi) | ✅ |
| Testing on Android emulator (launched from Windows) | ✅ |
| Unit tests (`flutter test`) | ✅ |
| Static analysis (`flutter analyze`) | ✅ |
| Flutter Web (interactive debugging) | ❌ |
| Flutter Desktop (Linux / Windows / macOS) | ❌ |
| Flutter iOS | ❌ |

---

## 🏗️ Architecture

```
┌────────────────────────────────────────────────────────┐
│                   DOCKER CONTAINER                     │
│                                                        │
│  ┌───────────┐   ┌──────────────┐   ┌───────────────┐  │
│  │  Flutter  │   │ Android SDK  │   │  ADB client   │  │
│  │   (Dart)  │   │ (compilation)│   │  (wrapper)    │  │
│  └─────┬─────┘   └──────────────┘   └───────┬───────┘  │
│        │                                    │          │
│        │  APK Compilation                   │          │
│        └────────────────────────────────────┘          │
└────────────────────────┬───────────────────────────────┘
                         │  ADB Bridge (port 5037)
                         │  network_mode: host
┌────────────────────────▼────────────────────────────────┐
│                    WSL2 (Debian)                        │
│           Network shared with the container             │
└────────────────────────┬────────────────────────────────┘
                         │  Hyper-V Virtual Network
┌────────────────────────▼────────────────────────────────┐
│                      WINDOWS                            │
│   ┌─────────────────────────────────────────────────┐   │
│   │          ADB Server (0.0.0.0:5037)              │   │
│   └──────────┬──────────────────────┬───────────────┘   │
│              │                      │                   │
│      ┌───────▼────────┐    ┌───────▼────────┐           │
│      │   Emulator     │    │  Phone via USB │           │
│      │(Android Studio)│    │  or Wi-Fi      │           │
│      └────────────────┘    └────────────────┘           │
└─────────────────────────────────────────────────────────┘
```

**Key principle:** the container compiles the Flutter code and produces an APK. Deployment to the device (emulator or phone) is done via an **ADB bridge** to the ADB server running on Windows. The container does not need direct access to USB or GPU.

---

## ✅ Prerequisites

### On Windows

| Software | Minimum Version | Verification |
|---|---|---|
| Windows 10 21H2+ or Windows 11 | Build 19045+ | `winver` |
| WSL2 | Enabled | `wsl -l -v` |
| Docker Engine (inside WSL) | 24+ | `docker version` in WSL |
| Android Studio | 2023+ | For managing AVDs |
| Android SDK Platform-Tools | 34+ | Bundled with Android Studio |
| VS Code | Latest version | `code --version` |

### VS Code Extensions (on Windows)

Install these extensions from the VS Code Marketplace:

- **WSL** (Microsoft)
- **Dev Containers** (Microsoft)
- **Flutter** (Dart Code)
- **Dart** (Dart Code)

### Inside WSL

| Element | Verification |
|---|---|
| WSL2 distribution | `wsl -l -v` → VERSION must be `2` |
| Docker Engine working | `docker ps` without errors |
| User in the `docker` group | `docker ps` without `sudo` |

---

## 📦 Installation

### 1. Windows Host Configuration

#### 1.1. Verify Android Studio and AVDs are ready

Open **Android Studio** → **Device Manager** → verify that at least one AVD exists. If not, create one (e.g., Pixel 7, API 34).

#### 1.2. Configure the ADB server for global listening

The ADB server must listen on **all network interfaces** (not just localhost) so the container can connect to it.

Open **PowerShell** (not WSL):

```powershell
# Navigate to the platform-tools directory
cd $env:LOCALAPPDATA\Android\Sdk\platform-tools

# Kill the existing server
.\adb.exe kill-server

# Start with global listening
.\adb.exe -a -P 5037 start-server

# Verify it's listening on 0.0.0.0
netstat -an | findstr "5037"
```

✅ Expected output:

```
TCP    0.0.0.0:5037    0.0.0.0:0    LISTENING
```

> ⚠️ If you see `127.0.0.1:5037` instead of `0.0.0.0:5037`, the server is only listening on localhost. Restart with `.\adb.exe -a start-server`.

#### 1.3. Allow port 5037 through the Windows Firewall

```powershell
# PowerShell in Administrator mode
New-NetFirewallRule -DisplayName "WSL ADB Bridge" `
  -Direction Inbound `
  -Profile Any `
  -Protocol TCP `
  -LocalPort 5037 `
  -Action Allow
```

#### 1.4. Verify the device is connected

```powershell
# Phone plugged in via USB
.\adb.exe devices
```

✅ Expected output:

```
List of devices attached
XXXXXXXXXXXX    device
```

If you see `unauthorized`, unlock your phone and accept the "Allow USB debugging" prompt.

---

### 2. WSL Configuration

#### 2.1. Verify Docker works without sudo

```bash
docker ps
```

If you get `permission denied`, add your user to the `docker` group:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

#### 2.2. (Optional) Limit WSL RAM usage

If your machine has 8 GB of RAM or less, create a `.wslconfig` file to prevent WSL from consuming all available memory.

On Windows, create the file `C:\Users\<your_username>\.wslconfig`:

```ini
[wsl2]
memory=4GB
processors=2
swap=2GB
```

Then in PowerShell:

```powershell
wsl --shutdown
```

---

### 3. Project Configuration

#### 3.1. Create or open the project inside WSL

> ⚠️ **The project MUST be inside the Linux filesystem** (`~/`), not on the Windows drive (`/mnt/c/`). Performance would be degraded by a factor of 5 to 10.

```bash
cd ~/dev
mkdir my_flutter_project
cd my_flutter_project
```

#### 3.2. Verify the `.devcontainer` folder is present

The `.devcontainer` folder must contain:

```
.devcontainer/
├── devcontainer.json       # VS Code / DevContainer config
├── docker-compose.yml      # Docker Compose config (network_mode: host)
├── Dockerfile              # Image: Flutter + Android SDK + JDK
└── post-create.sh          # Post-creation script (ADB bridge, permissions)
```

#### 3.3. Open in VS Code

```bash
code .
```

VS Code opens connected to WSL (indicator `WSL: Debian` in the bottom-left corner).

#### 3.4. Build the container

In VS Code:

1. `Ctrl + Shift + P`
2. **`Dev Containers: Rebuild Container`**

The first build takes **15 to 30 minutes** (downloading Flutter, Android SDK, JDK, Gradle, etc.). Subsequent builds use the Docker cache.

---

## 🚀 Daily Usage

### Start the container

```bash
# In WSL
cd ~/dev/my_flutter_project
code .
```

Then in VS Code: `Ctrl+Shift+P` → **`Dev Containers: Reopen in Container`**.

### Verify everything works

In the container terminal:

```bash
# Check Flutter
flutter doctor -v

# Check the ADB bridge
adb devices
```

✅ `flutter doctor` should show Flutter, Android SDK, and JDK without errors.
✅ `adb devices` should list your connected devices (emulator and/or phone).

### Run on Android emulator

1. On Windows, open **Android Studio** → **Device Manager** → launch an AVD.
2. Verify the Windows ADB server is running:
   ```powershell
   cd $env:LOCALAPPDATA\Android\Sdk\platform-tools
   .\adb.exe devices
   ```
3. In the container:
   ```bash
   flutter devices          # the emulator should appear
   flutter run              # launch the app on the emulator
   ```

### Run on physical device (USB)

1. Plug your phone into the Windows PC via USB.
2. Accept the "Allow USB debugging" prompt on the phone.
3. Verify on Windows:
   ```powershell
   .\adb.exe devices
   ```
4. In the container:
   ```bash
   flutter devices
   flutter run
   ```

### Run on physical device (Wi-Fi)

#### Android 11 and above

1. On the phone: **Settings → Developer options → Wireless debugging**.
2. Enable wireless debugging.
3. Tap **"Pair device with pairing code"**.
4. Note the IP address, port, and code displayed.
5. In the container:
   ```bash
   adb pair PHONE_IP:PAIRING_PORT
   # Enter the pairing code
   adb connect PHONE_IP:CONNECTION_PORT
   adb devices
   flutter run
   ```

#### Android 10 and below

Android 10 does not have native "Wireless debugging". An initial USB connection is required:

1. Plug the phone in via USB.
2. In the container:
   ```bash
   adb tcpip 5555
   ```
3. Unplug the USB cable.
4. Find the phone's IP address (**Settings → About phone → Status → IP address**).
5. In the container:
   ```bash
   adb connect PHONE_IP:5555
   adb devices
   flutter run
   ```

### Stop the container

- Simply close the VS Code window, or
- `Ctrl+Shift+P` → **`Dev Containers: Close Remote Connection`**

The container is stopped automatically (`shutdownAction: stopCompose`).

---

## 📁 Project Structure

```
my_flutter_project/
├── .devcontainer/
│   ├── devcontainer.json       # VS Code / DevContainer config
│   ├── docker-compose.yml      # Docker Compose (network_mode: host)
│   ├── Dockerfile              # Linux image (Flutter + SDK + JDK)
│   └── post-create.sh          # Post-creation script (ADB bridge)
├── lib/
│   └── main.dart               # Application entry point
├── android/
│   ├── app/                    # Native Android code
│   ├── gradle/                 # Gradle configuration
│   └── gradle.properties       # Gradle JVM arguments
├── test/                       # Unit tests
├── pubspec.yaml                # Flutter dependencies
└── README.md                   # This file
```

### Role of `.devcontainer` files

| File | Role |
|---|---|
| `devcontainer.json` | Defines the container name, VS Code extensions, settings, and post-creation script |
| `docker-compose.yml` | Defines the Docker service, `network_mode: host`, and persistent volumes |
| `Dockerfile` | Builds the Linux image: Flutter stable, Android SDK 34/35, JDK 17, ADB tools |
| `post-create.sh` | Executed after container creation: configures the ADB bridge, accepts licenses, fixes permissions |

---

## 🛠️ Useful Commands

### Flutter

```bash
flutter create --platforms=android .   # Initialize a Flutter project
flutter pub get                        # Download dependencies
flutter run                            # Launch the app
flutter run -d <device_id>             # Launch on a specific device
flutter run --release                  # Launch in release mode
flutter build apk --debug              # Build a debug APK
flutter build apk --release            # Build a release APK
flutter build appbundle --release      # Build an AAB (Play Store)
flutter clean                          # Clean build artifacts
flutter analyze                        # Analyze the code
flutter test                           # Run unit tests
flutter doctor -v                      # Full diagnostics
flutter upgrade                        # Update Flutter
```

### ADB (inside the container)

```bash
adb devices                            # List devices
adb devices -l                         # List with details
adb install my_app.apk                 # Install an APK
adb logcat                             # Real-time logs
adb logcat -s flutter                  # Filter Flutter logs
adb shell                              # Shell on the device
adb reboot                             # Reboot the device
adb connect IP:PORT                    # Wi-Fi connection
adb pair IP:PORT                       # Pairing (Android 11+)
```

### Docker

```bash
docker ps                              # Running containers
docker ps -a                           # All containers
docker logs <id>                       # Container logs
docker system prune                    # Clean up unused resources
docker system df                       # Disk usage
```

### WSL

```bash
wsl -l -v                              # List distributions
wsl --shutdown                         # Shut down WSL
wsl --status                           # Global status
```

---

## 🔍 Diagnostics

### Full diagnostic script

Inside the container:

```bash
echo "=== DEFAULT ROUTE ==="
ip route show default

echo ""
echo "=== RESOLV.CONF ==="
cat /etc/resolv.conf

echo ""
echo "=== GATEWAY TEST ==="
GW=$(ip route show default | awk '{print $3}' | head -1)
echo "Detected gateway: $GW"
timeout 3 bash -c "echo > /dev/tcp/$GW/5037" 2>/dev/null \
  && echo "✅ Port 5037 reachable on $GW" \
  || echo "❌ Port 5037 UNREACHABLE on $GW"

echo ""
echo "=== ADB WRAPPER ==="
cat /opt/android-sdk/platform-tools/adb 2>/dev/null || echo "Wrapper missing"

echo ""
echo "=== ADB DEVICES ==="
adb devices 2>&1

echo ""
echo "=== FLUTTER DOCTOR ==="
flutter doctor -v 2>&1
```

On Windows (PowerShell):

```powershell
echo "=== NETSTAT ==="
netstat -an | findstr "5037"

echo ""
echo "=== ADB DEVICES ==="
cd $env:LOCALAPPDATA\Android\Sdk\platform-tools
.\adb.exe devices

echo ""
echo "=== FIREWALL ==="
Get-NetFirewallRule -DisplayName "*WSL*" -ErrorAction SilentlyContinue |
  Format-Table DisplayName, Enabled, Direction, Action
```

---

## 🔧 Troubleshooting

### `cannot connect to daemon at tcp:127.0.0.11:5037`

**Cause:** the ADB wrapper is reading Docker's internal DNS (`127.0.0.11`) instead of the Windows IP.

**Solution:** verify that `network_mode: host` is present in `docker-compose.yml` and that `post-create.sh` uses `ip route show default` to detect the gateway.

```yaml
# docker-compose.yml
services:
  flutter:
    network_mode: host    # ← This line is essential
```

Perform a **Rebuild Container** after any modification.

---

### `adb devices` returns an empty list inside the container

Check in this order:

1. The Windows ADB server is running with the `-a` flag:
   ```powershell
   netstat -an | findstr "5037"
   # Should show: TCP  0.0.0.0:5037  ...  LISTENING
   ```

2. The device is connected on Windows:
   ```powershell
   .\adb.exe devices
   ```

3. The Windows Firewall allows port 5037:
   ```powershell
   Get-NetFirewallRule -DisplayName "*WSL*"
   ```

4. The gateway is reachable from the container:
   ```bash
   GW=$(ip route show default | awk '{print $3}' | head -1)
   timeout 3 bash -c "echo > /dev/tcp/$GW/5037" 2>/dev/null && echo "OK" || echo "FAIL"
   ```

---

### Build is very slow

- Verify the project is inside `~/` (Linux filesystem), **not** inside `/mnt/c/`.
- The first Gradle build is always slow. Subsequent builds use the cache.
- Verify Docker has enough resources: `docker info | grep -i memory`.

---

### `flutter doctor` reports missing licenses

```bash
flutter doctor --android-licenses
```

Accept all licenses by typing `y`.

---

### Container does not start after modification

```
Ctrl+Shift+P → Dev Containers: Rebuild Container
```

Do not just "Reopen": a **Rebuild** is required after modifying the `Dockerfile` or `docker-compose.yml`.

---

### `unauthorized` on the phone

- Unlock the phone screen.
- A "Allow USB debugging" prompt should appear. Accept it.
- If the prompt does not appear, unplug/replug the USB cable.
- On Windows, verify: `.\adb.exe devices` → the device should change from `unauthorized` to `device`.

---

## ⚙️ Customization

### Change the Flutter version

In the `Dockerfile`, modify the `FLUTTER_CHANNEL` argument:

```dockerfile
ARG FLUTTER_CHANNEL=stable    # or beta, or master
```

For a specific version, replace the clone with:

```dockerfile
RUN git clone --branch 3.24.0 https://github.com/flutter/flutter.git ${FLUTTER_HOME}
```

### Change the Android SDK version

In the `Dockerfile`, modify the `sdkmanager` line:

```dockerfile
RUN sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0" "emulator"
```

### Add Flutter Web support

Add to the `Dockerfile`:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium fonts-liberation libasound2 libatk-bridge2.0-0 \
    libatk1.0-0 libcups2 libdrm2 libgbm1 libgtk-3-0 libnspr4 \
    libnss3 libx11-xcb1 libxcomposite1 libxdamage1 libxrandr2 \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

ENV CHROME_EXECUTABLE=/usr/bin/chromium
```

Then: `flutter run -d chrome`

### Use this devcontainer for a new project

Copy the `.devcontainer` folder into the new project:

```bash
cd ~/dev
mkdir new_project
cp -r ~/dev/my_flutter_project/.devcontainer new_project/
cd new_project
code .
```

Then: `Dev Containers: Reopen in Container` → `flutter create --platforms=android .`

---

## 📌 Known Limitations

| Limitation | Explanation |
|---|---|
| No GPU inside the container | The container does not have access to the graphics card. The emulator uses the GPU via Windows. |
| No KVM inside WSL | The emulator cannot run inside the container. It must be launched from Windows. |
| x86_64 architecture only | Android SDK images and emulator are for x86_64. |
| Flutter Web not configured | No browser inside the container. Web build works (`flutter build web`), but interactive debugging does not. |
| Flutter Desktop / iOS not supported | Requires native tools (GTK, Xcode) not available in this container. |
| Dependency on the Windows ADB server | The container depends on the ADB server running on Windows. If Windows restarts, the ADB server must be restarted with `-a`. |