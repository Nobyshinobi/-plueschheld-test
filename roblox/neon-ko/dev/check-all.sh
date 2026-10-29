#!/usr/bin/env sh
# Führt alle automatischen Prüfungen aus (ohne Roblox Studio).
# Benötigt: rojo, lune, selene, stylua (mit Luau-Unterstützung), python3.
# API-Dump: API_DUMP=/pfad/Full-API-Dump.json oder er wird nach dev/.cache geladen.
set -eu
cd "$(dirname "$0")/.."

API_DUMP="${API_DUMP:-dev/.cache/Full-API-Dump.json}"
if [ ! -f "$API_DUMP" ]; then
	mkdir -p "$(dirname "$API_DUMP")"
	curl -sSfL -o "$API_DUMP" https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json
fi

echo "== Modelle bauen (Rojo)"
for part in ReplicatedStorage ServerScriptService StarterPlayerScripts; do
	rojo build "dev/projects/$part.project.json" -o "build/NEON_KO_$part.rbxm"
done
echo "== Syntax + Modellstruktur (Lune)"
lune run dev/check.luau
echo "== Formatierung (StyLua)"
stylua --check src tests studio-tools dev/check.luau
echo "== Lint (selene)"
selene src studio-tools tests dev/check.luau
echo "== Roblox-API-Abgleich"
python3 dev/api_check.py "$API_DUMP" src studio-tools
echo "== Unit-Tests + Balancing"
lune run tests/run.luau
echo "== Integrationstest (Fake-Engine)"
lune run tests/integration.luau
