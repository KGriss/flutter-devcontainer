# 🐦 Flutter Android DevContainer

Ce `.devcontainer` est conçu par **Qwen3.8-Max** pour fonctionner sur un hôte **Windows 10** avec **WSL2**, et **Docker CE** installé sur ce dernier.

Il permet de développer pour **Android**, avec des tests sur un **émulateur** exécuté sur l’hôte Windows, ou sur un **appareil physique** connecté via ADB en USB ou en Wi‑Fi.

---

## 📑 Sommaire

- [Ce que fait ce DevContainer](#-ce-que-fait-ce-devcontainer)
- [Architecture](#️-architecture)
- [Prérequis](#-prérequis)
- [Installation](#-installation)
- [Utilisation quotidienne](#-utilisation-quotidienne)
- [Structure du projet](#-structure-du-projet)
- [Commandes utiles](#️-commandes-utiles)
- [Diagnostic](#-diagnostic)
- [Dépannage](#-dépannage)
- [Personnalisation](#️-personnalisation)
- [Limites connues](#-limites-connues)

---

## 🎯 Ce que fait ce DevContainer

| Fonctionnalité | Supportée |
|---|---|
| Développement Flutter Android | ✅ |
| Build APK / AAB | ✅ |
| Hot reload / Hot restart | ✅ |
| Test sur téléphone physique Android (USB) | ✅ |
| Test sur téléphone physique Android (Wi-Fi) | ✅ |
| Test sur émulateur Android (lancé depuis Windows) | ✅ |
| Tests unitaires (`flutter test`) | ✅ |
| Analyse statique (`flutter analyze`) | ✅ |
| Flutter Web (debug interactif) | ❌ |
| Flutter Desktop (Linux / Windows / macOS) | ❌ |
| Flutter iOS | ❌ |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   CONTENEUR DOCKER                       │
│                                                         │
│  ┌───────────┐   ┌──────────────┐   ┌───────────────┐  │
│  │  Flutter  │   │ Android SDK  │   │  ADB client   │  │
│  │   (Dart)  │   │ (compilation)│   │  (wrapper)    │  │
│  └─────┬─────┘   └──────────────┘   └───────┬───────┘  │
│        │                                     │          │
│        │  Compilation APK                    │          │
│        └─────────────────────────────────────┘          │
└────────────────────────┬────────────────────────────────┘
                         │  Pont ADB (port 5037)
                         │  network_mode: host
┌────────────────────────▼────────────────────────────────┐
│                    WSL2 (Debian)                         │
│           Réseau partagé avec le conteneur               │
└────────────────────────┬────────────────────────────────┘
                         │  Réseau virtuel Hyper-V
┌────────────────────────▼────────────────────────────────┐
│                      WINDOWS                             │
│   ┌─────────────────────────────────────────────────┐   │
│   │          Serveur ADB (0.0.0.0:5037)             │   │
│   └──────────┬──────────────────────┬───────────────┘   │
│              │                      │                   │
│      ┌───────▼────────┐    ┌───────▼────────┐          │
│      │   Émulateur    │    │ Téléphone USB  │          │
│      │(Android Studio)│    │  ou Wi-Fi      │          │
│      └────────────────┘    └────────────────┘          │
└─────────────────────────────────────────────────────────┘
```

**Principe clé :** le conteneur compile le code Flutter et produit un APK. Le déploiement sur l'appareil (émulateur ou téléphone) se fait via un **pont ADB** vers le serveur ADB qui tourne sur Windows. Le conteneur n'a pas besoin d'accéder directement à l'USB ou au GPU.

---

## ✅ Prérequis

### Sur Windows

| Logiciel | Version minimale | Vérification |
|---|---|---|
| Windows 10 21H2+ ou Windows 11 | Build 19045+ | `winver` |
| WSL2 | Activé | `wsl -l -v` |
| Docker Engine (dans WSL) | 24+ | `docker version` dans WSL |
| Android Studio | 2023+ | Pour gérer les AVD |
| Android SDK Platform-Tools | 34+ | Inclus avec Android Studio |
| VS Code | Dernière version | `code --version` |

### Extensions VS Code (sur Windows)

Installez ces extensions depuis le Marketplace VS Code :

- **WSL** (Microsoft)
- **Dev Containers** (Microsoft)
- **Flutter** (Dart Code)
- **Dart** (Dart Code)

### Sur WSL

| Élément | Vérification |
|---|---|
| Distribution WSL2 | `wsl -l -v` → VERSION doit être `2` |
| Docker Engine fonctionnel | `docker ps` sans erreur |
| Utilisateur dans le groupe `docker` | `docker ps` sans `sudo` |

---

## 📦 Installation

### 1. Configuration de l'hôte Windows

#### 1.1. Vérifier qu'Android Studio et les AVD sont prêts

Ouvrez **Android Studio** → **Device Manager** → vérifiez qu'au moins un AVD existe. Si ce n'est pas le cas, créez-en un (ex : Pixel 7, API 34).

#### 1.2. Configurer le serveur ADB en écoute globale

Le serveur ADB doit écouter sur **toutes les interfaces réseau** (pas uniquement localhost) pour que le conteneur puisse s'y connecter.

Ouvrez **PowerShell** (pas WSL) :

```powershell
# Se rendre dans le dossier platform-tools
cd $env:LOCALAPPDATA\Android\Sdk\platform-tools

# Tuer le serveur existant
.\adb.exe kill-server

# Démarrer en écoute globale
.\adb.exe -a -P 5037 start-server

# Vérifier qu'il écoute bien sur 0.0.0.0
netstat -an | findstr "5037"
```

✅ Résultat attendu :

```
TCP    0.0.0.0:5037    0.0.0.0:0    LISTENING
```

> ⚠️ Si vous voyez `127.0.0.1:5037` au lieu de `0.0.0.0:5037`, le serveur n'écoute que sur localhost. Relancez avec `.\adb.exe -a start-server`.

#### 1.3. Autoriser le port 5037 dans le pare-feu Windows

```powershell
# PowerShell en mode Administrateur
New-NetFirewallRule -DisplayName "WSL ADB Bridge" `
  -Direction Inbound `
  -Profile Any `
  -Protocol TCP `
  -LocalPort 5037 `
  -Action Allow
```

#### 1.4. Vérifier que l'appareil est connecté

```powershell
# Téléphone branché en USB
.\adb.exe devices
```

✅ Résultat attendu :

```
List of devices attached
XXXXXXXXXXXX    device
```

Si vous voyez `unauthorized`, déverrouillez votre téléphone et acceptez l'invite « Autoriser le débogage USB ».

---

### 2. Configuration de WSL

#### 2.1. Vérifier que Docker fonctionne sans sudo

```bash
docker ps
```

Si vous obtenez `permission denied`, ajoutez votre utilisateur au groupe `docker` :

```bash
sudo usermod -aG docker $USER
newgrp docker
```

#### 2.2. (Optionnel) Limiter la RAM de WSL

Si votre machine a 8 Go de RAM ou moins, créez un fichier `.wslconfig` pour éviter que WSL ne consomme toute la mémoire.

Sur Windows, créez le fichier `C:\Users\<votre_utilisateur>\.wslconfig` :

```ini
[wsl2]
memory=4GB
processors=2
swap=2GB
```

Puis dans PowerShell :

```powershell
wsl --shutdown
```

---

### 3. Configuration du projet

#### 3.1. Créer ou ouvrir le projet dans WSL

> ⚠️ **Le projet DOIT être dans le système de fichiers Linux** (`~/`), pas sur le disque Windows (`/mnt/c/`). Les performances seraient dégradées par un facteur 5 à 10.

```bash
cd ~/dev
mkdir mon_projet_flutter
cd mon_projet_flutter
```

#### 3.2. Vérifier la présence du dossier `.devcontainer`

Le dossier `.devcontainer` doit contenir :

```
.devcontainer/
├── devcontainer.json       # Config VS Code / DevContainer
├── docker-compose.yml      # Config Docker Compose (network_mode: host)
├── Dockerfile              # Image : Flutter + Android SDK + JDK
└── post-create.sh          # Script post-création (pont ADB, permissions)
```

#### 3.3. Ouvrir dans VS Code

```bash
code .
```

VS Code s'ouvre connecté à WSL (indicateur `WSL: Debian` en bas à gauche).

#### 3.4. Construire le conteneur

Dans VS Code :

1. `Ctrl + Shift + P`
2. **`Dev Containers: Rebuild Container`**

Le premier build prend **15 à 30 minutes** (téléchargement de Flutter, Android SDK, JDK, Gradle, etc.). Les builds suivants utilisent le cache Docker.

---

## 🚀 Utilisation quotidienne

### Démarrer le conteneur

```bash
# Dans WSL
cd ~/dev/mon_projet_flutter
code .
```

Puis dans VS Code : `Ctrl+Shift+P` → **`Dev Containers: Reopen in Container`**.

### Vérifier que tout fonctionne

Dans le terminal du conteneur :

```bash
# Vérifier Flutter
flutter doctor -v

# Vérifier le pont ADB
adb devices
```

✅ `flutter doctor` doit montrer Flutter, Android SDK, et JDK sans erreur.
✅ `adb devices` doit lister vos appareils connectés (émulateur et/ou téléphone).

### Lancer sur émulateur Android

1. Sur Windows, ouvrez **Android Studio** → **Device Manager** → lancez un AVD.
2. Vérifiez que le serveur ADB Windows tourne :
   ```powershell
   cd $env:LOCALAPPDATA\Android\Sdk\platform-tools
   .\adb.exe devices
   ```
3. Dans le conteneur :
   ```bash
   flutter devices          # l'émulateur doit apparaître
   flutter run              # lance l'app sur l'émulateur
   ```

### Lancer sur téléphone physique (USB)

1. Branchez votre téléphone en USB sur le PC Windows.
2. Acceptez l'invite « Autoriser le débogage USB » sur le téléphone.
3. Vérifiez côté Windows :
   ```powershell
   .\adb.exe devices
   ```
4. Dans le conteneur :
   ```bash
   flutter devices
   flutter run
   ```

### Lancer sur téléphone physique (Wi-Fi)

#### Android 11 et supérieur

1. Sur le téléphone : **Paramètres → Options développeur → Débogage sans fil**.
2. Activez le débogage sans fil.
3. Appuyez sur **« Associer l'appareil avec un code d'association »**.
4. Notez l'IP, le port et le code affichés.
5. Dans le conteneur :
   ```bash
   adb pair IP_TELEPHONE:PORT_PAIRING
   # Entrez le code d'association
   adb connect IP_TELEPHONE:PORT_CONNEXION
   adb devices
   flutter run
   ```

#### Android 10 et inférieur

Android 10 n'a pas le « Débogage sans fil » natif. Il faut une première connexion USB :

1. Branchez le téléphone en USB.
2. Dans le conteneur :
   ```bash
   adb tcpip 5555
   ```
3. Débranchez le câble USB.
4. Trouvez l'IP du téléphone (**Paramètres → À propos → État → Adresse IP**).
5. Dans le conteneur :
   ```bash
   adb connect IP_TELEPHONE:5555
   adb devices
   flutter run
   ```

### Arrêter le conteneur

- Fermez simplement la fenêtre VS Code, ou
- `Ctrl+Shift+P` → **`Dev Containers: Close Remote Connection`**

Le conteneur est arrêté automatiquement (`shutdownAction: stopCompose`).

---

## 📁 Structure du projet

```
mon_projet_flutter/
├── .devcontainer/
│   ├── devcontainer.json       # Config VS Code / DevContainer
│   ├── docker-compose.yml      # Docker Compose (network_mode: host)
│   ├── Dockerfile              # Image Linux (Flutter + SDK + JDK)
│   └── post-create.sh          # Script post-création (pont ADB)
├── lib/
│   └── main.dart               # Point d'entrée de l'application
├── android/
│   ├── app/                    # Code natif Android
│   ├── gradle/                 # Config Gradle
│   └── gradle.properties       # Arguments JVM Gradle
├── test/                       # Tests unitaires
├── pubspec.yaml                # Dépendances Flutter
└── README.md                   # Ce fichier
```

### Rôle des fichiers `.devcontainer`

| Fichier | Rôle |
|---|---|
| `devcontainer.json` | Définit le nom du conteneur, les extensions VS Code, les paramètres, le script post-création |
| `docker-compose.yml` | Définit le service Docker, le `network_mode: host`, les volumes persistants |
| `Dockerfile` | Construit l'image Linux : Flutter stable, Android SDK 34/35, JDK 17, outils ADB |
| `post-create.sh` | Exécuté après la création du conteneur : configure le pont ADB, accepte les licences, fixe les permissions |

---

## 🛠️ Commandes utiles

### Flutter

```bash
flutter create --platforms=android .   # Initialiser un projet Flutter
flutter pub get                        # Télécharger les dépendances
flutter run                            # Lancer l'app
flutter run -d <device_id>             # Lancer sur un appareil précis
flutter run --release                  # Lancer en mode release
flutter build apk --debug              # Builder un APK debug
flutter build apk --release            # Builder un APK release
flutter build appbundle --release      # Builder un AAB (Play Store)
flutter clean                          # Nettoyer les artefacts de build
flutter analyze                        # Analyser le code
flutter test                           # Lancer les tests unitaires
flutter doctor -v                      # Diagnostic complet
flutter upgrade                        # Mettre à jour Flutter
```

### ADB (dans le conteneur)

```bash
adb devices                            # Lister les appareils
adb devices -l                         # Lister avec détails
adb install mon_app.apk                # Installer un APK
adb logcat                             # Logs en temps réel
adb logcat -s flutter                  # Filtrer les logs Flutter
adb shell                              # Shell sur l'appareil
adb reboot                             # Redémarrer l'appareil
adb connect IP:PORT                    # Connexion Wi-Fi
adb pair IP:PORT                       # Association (Android 11+)
```

### Docker

```bash
docker ps                              # Conteneurs en cours
docker ps -a                           # Tous les conteneurs
docker logs <id>                       # Logs d'un conteneur
docker system prune                    # Nettoyer les ressources
docker system df                       # Utilisation disque
```

### WSL

```bash
wsl -l -v                              # Lister les distributions
wsl --shutdown                         # Arrêter WSL
wsl --status                           # Statut global
```

---

## 🔍 Diagnostic

### Script de diagnostic complet

Dans le conteneur :

```bash
echo "=== ROUTE PAR DÉFAUT ==="
ip route show default

echo ""
echo "=== RESOLV.CONF ==="
cat /etc/resolv.conf

echo ""
echo "=== TEST PASSERELLE ==="
GW=$(ip route show default | awk '{print $3}' | head -1)
echo "Passerelle détectée : $GW"
timeout 3 bash -c "echo > /dev/tcp/$GW/5037" 2>/dev/null \
  && echo "✅ Port 5037 accessible sur $GW" \
  || echo "❌ Port 5037 INACCESSIBLE sur $GW"

echo ""
echo "=== WRAPPER ADB ==="
cat /opt/android-sdk/platform-tools/adb 2>/dev/null || echo "Wrapper absent"

echo ""
echo "=== ADB DEVICES ==="
adb devices 2>&1

echo ""
echo "=== FLUTTER DOCTOR ==="
flutter doctor -v 2>&1
```

Sur Windows (PowerShell) :

```powershell
echo "=== NETSTAT ==="
netstat -an | findstr "5037"

echo ""
echo "=== ADB DEVICES ==="
cd $env:LOCALAPPDATA\Android\Sdk\platform-tools
.\adb.exe devices

echo ""
echo "=== PARE-FEU ==="
Get-NetFirewallRule -DisplayName "*WSL*" -ErrorAction SilentlyContinue |
  Format-Table DisplayName, Enabled, Direction, Action
```

---

## 🔧 Dépannage

### `cannot connect to daemon at tcp:127.0.0.11:5037`

**Cause :** le wrapper ADB lit le DNS interne de Docker (`127.0.0.11`) au lieu de l'IP Windows.

**Solution :** vérifiez que `network_mode: host` est bien présent dans `docker-compose.yml` et que le `post-create.sh` utilise `ip route show default` pour détecter la passerelle.

```yaml
# docker-compose.yml
services:
  flutter:
    network_mode: host    # ← Cette ligne est indispensable
```

Faites un **Rebuild Container** après modification.

---

### `adb devices` retourne une liste vide dans le conteneur

Vérifiez dans cet ordre :

1. Le serveur ADB Windows tourne avec l'option `-a` :
   ```powershell
   netstat -an | findstr "5037"
   # Doit afficher : TCP  0.0.0.0:5037  ...  LISTENING
   ```

2. L'appareil est bien connecté côté Windows :
   ```powershell
   .\adb.exe devices
   ```

3. Le pare-feu Windows autorise le port 5037 :
   ```powershell
   Get-NetFirewallRule -DisplayName "*WSL*"
   ```

4. La passerelle est accessible depuis le conteneur :
   ```bash
   GW=$(ip route show default | awk '{print $3}' | head -1)
   timeout 3 bash -c "echo > /dev/tcp/$GW/5037" 2>/dev/null && echo "OK" || echo "ECHEC"
   ```

---

### Le build est très lent

- Vérifiez que le projet est dans `~/` (système Linux), **pas** dans `/mnt/c/`.
- Le premier build Gradle est toujours long. Les suivants utilisent le cache.
- Vérifiez que Docker a assez de ressources : `docker info | grep -i memory`.

---

### `flutter doctor` signale des licences manquantes

```bash
flutter doctor --android-licenses
```

Acceptez toutes les licences en tapant `y`.

---

### Le conteneur ne démarre pas après modification

```
Ctrl+Shift+P → Dev Containers: Rebuild Container
```

Ne faites pas juste « Reopen » : un **Rebuild** est nécessaire après modification du `Dockerfile` ou du `docker-compose.yml`.

---

### `unauthorized` sur le téléphone

- Déverrouillez l'écran du téléphone.
- Une invite « Autoriser le débogage USB » devrait apparaître. Acceptez-la.
- Si l'invite n'apparaît pas, débranchez/rebranchez le câble USB.
- Sur Windows, vérifiez : `.\adb.exe devices` → l'appareil doit passer de `unauthorized` à `device`.

---

## ⚙️ Personnalisation

### Changer la version de Flutter

Dans le `Dockerfile`, modifiez l'argument `FLUTTER_CHANNEL` :

```dockerfile
ARG FLUTTER_CHANNEL=stable    # ou beta, ou master
```

Pour une version précise, remplacez le clone par :

```dockerfile
RUN git clone --branch 3.24.0 https://github.com/flutter/flutter.git ${FLUTTER_HOME}
```

### Changer la version d'Android SDK

Dans le `Dockerfile`, modifiez la ligne `sdkmanager` :

```dockerfile
RUN sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0" "emulator"
```

### Ajouter le support Flutter Web

Ajoutez dans le `Dockerfile` :

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium fonts-liberation libasound2 libatk-bridge2.0-0 \
    libatk1.0-0 libcups2 libdrm2 libgbm1 libgtk-3-0 libnspr4 \
    libnss3 libx11-xcb1 libxcomposite1 libxdamage1 libxrandr2 \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

ENV CHROME_EXECUTABLE=/usr/bin/chromium
```

Puis : `flutter run -d chrome`

### Utiliser ce devcontainer pour un nouveau projet

Copiez le dossier `.devcontainer` dans le nouveau projet :

```bash
cd ~/dev
mkdir nouveau_projet
cp -r ~/dev/mon_projet_flutter/.devcontainer nouveau_projet/
cd nouveau_projet
code .
```

Puis : `Dev Containers: Reopen in Container` → `flutter create --platforms=android .`

---

## 📌 Limites connues

| Limite | Explication |
|---|---|
| Pas de GPU dans le conteneur | Le conteneur n'a pas accès à la carte graphique. L'émulateur utilise le GPU via Windows. |
| Pas de KVM dans WSL | L'émulateur ne peut pas tourner dans le conteneur. Il doit être lancé depuis Windows. |
| Architecture x86_64 uniquement | Les images Android SDK et émulateur sont pour x86_64. |
| Flutter Web non configuré | Pas de navigateur dans le conteneur. Le build web fonctionne (`flutter build web`), mais pas le debug interactif. |
| Flutter Desktop / iOS non supporté | Nécessite des outils natifs (GTK, Xcode) non disponibles dans ce conteneur. |
| Dépendance au serveur ADB Windows | Le conteneur dépend du serveur ADB qui tourne sur Windows. Si Windows redémarre, il faut relancer le serveur ADB avec `-a`. |
