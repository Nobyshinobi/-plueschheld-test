#!/usr/bin/env python3
"""Statische Plausibilitätsprüfung der Luau-Quellen gegen den aktuellen Roblox-API-Dump.

Prüft (heuristisch, ohne vollständigen Typchecker):
  * Enum.<Typ>.<Wert>                         existiert
  * Instance.new("Klasse")                    existiert und ist erstellbar
  * game:GetService("Dienst")                 existiert
  * Eigenschaften/Methoden/Events an Variablen mit bekannter Klasse
    (Instance.new, GetService, `:: Klasse`, Parameter-Annotationen, FindFirstChildOfClass, UI.new)
  * veraltete (Deprecated) Mitglieder inkl. empfohlenem Ersatz

Aufruf:  python3 dev/api_check.py <Full-API-Dump.json> [Verzeichnisse...]
Dump:    https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Full-API-Dump.json
"""
import json
import os
import re
import sys

dump_path = sys.argv[1]
roots = sys.argv[2:] or ["src", "studio-tools"]
api = json.load(open(dump_path, encoding="utf-8"))

classes = {c["Name"]: c for c in api["Classes"]}
enums = {e["Name"]: {i["Name"] for i in e["Items"]} for e in api["Enums"]}


def tags(m):
    return m.get("Tags") or []


def member(cls, name):
    while cls and cls in classes:
        for m in classes[cls]["Members"]:
            if m["Name"] == name:
                return cls, m
        sup = classes[cls]["Superclass"]
        cls = None if sup == "<<<ROOT>>>" else sup
    return None


def preferred(m):
    for t in tags(m):
        if isinstance(t, dict) and t.get("PreferredDescriptorName"):
            return t["PreferredDescriptorName"]
    return None


problems = []
warnings = []


def report(kind, path, line, msg):
    (problems if kind == "E" else warnings).append(f"{path}:{line}: {msg}")


ENUM_RE = re.compile(r"\bEnum\.(\w+)\.(\w+)")
NEW_RE = re.compile(r"Instance\.new\(\"(\w+)\"\)")
SVC_RE = re.compile(r"(?:game|DataModel):GetService\(\"(\w+)\"\)")
ASSIGN_NEW = re.compile(r"(?:local\s+)?(\w+)(?:\s*:\s*\w+\??)?\s*=\s*Instance\.new\(\"(\w+)\"\)")
ASSIGN_SVC = re.compile(r"local\s+(\w+)\s*=\s*game:GetService\(\"(\w+)\"\)")
ASSIGN_UI = re.compile(r"(?:local\s+)?(\w+)\s*=\s*UI\.new\(\"(\w+)\"")
ASSIGN_CAST = re.compile(r"local\s+(\w+)(?:\s*:\s*[\w?]+)?\s*=\s*[^\n]*?::\s*(\w+)\b")
ASSIGN_FFCOC = re.compile(r"local\s+(\w+)\s*=\s*[\w.:\s]*FindFirstChildOfClass\(\"(\w+)\"\)")
ANNOT = re.compile(r"\b(\w+)\s*:\s*(\w+)\??\s*[,)=]")
USE_RE = re.compile(r"\b(\w+)([.:])([A-Z]\w*)\b(\s*\()?")
UI_NEW_BLOCK = re.compile(r"UI\.new\(\"(\w+)\",\s*\{")

LUA_GLOBAL_TYPES = {"string", "number", "boolean", "any", "nil", "table"}


def table_keys(text, start):
    """Schlüssel der obersten Ebene eines Tabellen-Literals ab Index start ('{')."""
    depth = 0
    keys = []
    i = start
    token = ""
    while i < len(text):
        ch = text[i]
        if ch in "{([":
            depth += 1
        elif ch in "})]":
            depth -= 1
            if depth == 0:
                break
        if depth == 1:
            m = re.match(r"\s*([A-Z]\w*)\s*=(?!=)", text[i + 1 :]) if ch in "{,\n" else None
            if m:
                keys.append(m.group(1))
        i += 1
    return keys


for root in roots:
    for dirpath, _, files in os.walk(root):
        for fname in files:
            if not fname.endswith(".luau"):
                continue
            path = os.path.join(dirpath, fname)
            text = open(path, encoding="utf-8").read()
            lines = text.split("\n")

            def lineno(idx):
                return text.count("\n", 0, idx) + 1

            for m in ENUM_RE.finditer(text):
                e, item = m.groups()
                if e not in enums:
                    report("E", path, lineno(m.start()), f"Unbekannter Enum-Typ Enum.{e}")
                elif item not in enums[e] and item not in ("GetEnumItems", "FromName", "FromValue"):
                    report("E", path, lineno(m.start()), f"Unbekannter Enum-Wert Enum.{e}.{item}")
            for m in NEW_RE.finditer(text):
                c = m.group(1)
                if c not in classes:
                    report("E", path, lineno(m.start()), f"Unbekannte Klasse {c}")
                elif "NotCreatable" in tags(classes[c]) or "Service" in tags(classes[c]):
                    report("E", path, lineno(m.start()), f"Klasse {c} ist nicht per Instance.new erstellbar")
                elif "Deprecated" in tags(classes[c]):
                    report("W", path, lineno(m.start()), f"Klasse {c} ist veraltet")
            for m in SVC_RE.finditer(text):
                if m.group(1) not in classes:
                    report("E", path, lineno(m.start()), f"Unbekannter Dienst {m.group(1)}")

            # Variablen → Klasse (dateiweit, mehrere Klassen pro Name möglich)
            types = {}

            def bind(name, cls):
                if cls in classes:
                    types.setdefault(name, set()).add(cls)

            for rx in (ASSIGN_NEW, ASSIGN_SVC, ASSIGN_UI, ASSIGN_FFCOC, ASSIGN_CAST):
                for m in rx.finditer(text):
                    bind(m.group(1), m.group(2))
            for m in ANNOT.finditer(text):
                if m.group(2) not in LUA_GLOBAL_TYPES:
                    bind(m.group(1), m.group(2))

            for m in USE_RE.finditer(text):
                var, sep, name, call = m.groups()
                if sep == ":" and not call:
                    continue  # Typannotation wie `model: Model`, kein Methodenaufruf
                if var not in types or var in ("Enum", "Instance", "UI", "Config"):
                    continue
                # Zuweisung an Tabellenfeld mit Großbuchstaben, z. B. Config.Foo – nur für Instanzklassen prüfen
                found = [member(c, name) for c in types[var]]
                hits = [f for f in found if f]
                if not hits:
                    # Kindzugriff per Punkt (z. B. folder.Remotes) ist in Luau erlaubt – nur ':'-Aufrufe sind sicher falsch
                    if sep == ":":
                        report("E", path, lineno(m.start()), f"{var}:{name} – Methode existiert nicht in {sorted(types[var])}")
                    elif all(c not in ("Instance", "Folder", "Model") for c in types[var]):
                        report(
                            "W",
                            path,
                            lineno(m.start()),
                            f"{var}.{name} – kein Mitglied von {sorted(types[var])} (Kindobjekt?)",
                        )
                    continue
                for cls, mem in hits:
                    if "Deprecated" in tags(mem):
                        alt = preferred(mem)
                        report(
                            "E",
                            path,
                            lineno(m.start()),
                            f"{var}{sep}{name} ist veraltet ({cls})" + (f" → {alt}" if alt else ""),
                        )

            # Eigenschaften in UI.new("Klasse", { ... }) sowie UI.label/UI.button/UI.bar-Tabellen
            blocks = [(m.group(1), m) for m in UI_NEW_BLOCK.finditer(text)]
            blocks += [("TextLabel", m) for m in re.finditer(r"UI\.label\(\{", text)]
            blocks += [("TextButton", m) for m in re.finditer(r"UI\.button\([^{}()]*(?:\([^()]*\)[^{}()]*)*\{", text)]
            blocks += [("Frame", m) for m in re.finditer(r"UI\.bar\(\w+,\s*\{", text)]
            for cls, m in blocks:
                if cls not in classes:
                    report("E", path, lineno(m.start()), f"Unbekannte Klasse {cls}")
                    continue
                for key in table_keys(text, m.end() - 1):
                    if key == "Parent":
                        continue
                    found = member(cls, key)
                    if not found:
                        report("E", path, lineno(m.start()), f"UI.new {cls}: Eigenschaft {key} existiert nicht")
                    elif "Deprecated" in tags(found[1]):
                        report("E", path, lineno(m.start()), f"UI.new {cls}: {key} ist veraltet")

print(f"API-Dump: {api.get('Version', '?')} · {len(classes)} Klassen")
for w in warnings:
    print("WARNUNG ", w)
for p in problems:
    print("FEHLER  ", p)
print(f"Ergebnis: {len(problems)} Fehler, {len(warnings)} Warnungen")
sys.exit(1 if problems else 0)
