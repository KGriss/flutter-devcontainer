#!/usr/bin/env bash
set -uo pipefail

export PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/opt/android-sdk/emulator:${PATH}

echo "[post-create] Fix permissions"
sudo mkdir -p /home/vscode/.pub-cache /home/vscode/.gradle /home/vscode/.android
sudo chown -R "$(id -u):$(id -g)" /home/vscode/.pub-cache /home/vscode/.gradle /home/vscode/.android || true
sudo chown -R "$(id -u):$(id -g)" /workspace || true

echo "[post-create] Git safe directory"
git config --global --add safe.directory /workspace || true

ADB_BIN="/opt/android-sdk/platform-tools/adb"
ADB_REAL="${ADB_BIN}.real"

echo "[post-create] Configuration du pont ADB dynamique vers Windows"

if [ -x "$ADB_BIN" ] && [ ! -f "$ADB_REAL" ]; then
  sudo mv "$ADB_BIN" "$ADB_REAL"
fi

if [ -f "$ADB_REAL" ]; then
  sudo tee "$ADB_BIN" >/dev/null << 'EOF'
#!/usr/bin/env bash
# Méthode 1 : route par défaut (fonctionne avec network_mode: host)
HOST_IP=$(ip route show default 2>/dev/null | awk '{print $3}' | head -1)

# Méthode 2 : fallback sur resolv.conf (si network_mode host)
if [ -z "$HOST_IP" ] || [ "$HOST_IP" = "127.0.0.11" ]; then
  HOST_IP=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | tr -d '\r')
fi

# Méthode 3 : fallback sur host.docker.internal
if [ -z "$HOST_IP" ] || [ "$HOST_IP" = "127.0.0.11" ]; then
  HOST_IP="host.docker.internal"
fi

exec /opt/android-sdk/platform-tools/adb.real -H "$HOST_IP" -P 5037 "$@"
EOF
  sudo chmod +x "$ADB_BIN"
  echo "[post-create] Pont ADB configuré."
else
  echo "[post-create] WARNING: adb.real introuvable !"
fi

echo "[post-create] Configuration Flutter"
/opt/flutter/bin/flutter config --no-analytics || true
[ -f pubspec.yaml ] && /opt/flutter/bin/flutter pub get || true
yes | /opt/flutter/bin/flutter doctor --android-licenses > /dev/null 2>&1 || true
/opt/flutter/bin/flutter doctor -v || true
echo "[post-create] Terminé !"
