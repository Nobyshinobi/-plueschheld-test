# Videos (HyperFrames)

HTML-basierte Videos mit [HyperFrames](https://github.com/heygen-com/hyperframes) von HeyGen.

## Einrichtung

- CLI: `hyperframes` als devDependency im Root-`package.json` → `npx hyperframes …`
- Agent-Skills (Core-Set) projektbezogen für Claude Code unter `.claude/skills/`
  (installiert mit `npx skills add heygen-com/hyperframes -a claude-code --copy`, Stand in `skills-lock.json`).
  Workflow-Skills (z. B. `motion-graphics`) werden bei Bedarf nachinstalliert:
  `npx hyperframes skills update <name>`.
- Voraussetzungen: Node.js ≥ 22, FFmpeg/FFprobe, Chrome Headless Shell
  (`npx hyperframes browser ensure`). Status prüfen mit `npx hyperframes doctor`.

## Testprojekt

`hyperframes-test/` ist ein 4-Sekunden-Beispiel (1920×1080, 30 fps):

```bash
cd videos/hyperframes-test
npx hyperframes check                                   # Lint, Runtime, Layout, Kontrast
npx hyperframes render -o renders/hyperframes-test.mp4  # MP4 rendern
```

## Hinweis

GSAP liegt lokal unter `hyperframes-test/assets/gsap.min.js`, weil die headless
Chrome-Instanz in der Cloud-Umgebung keine CDN-Skripte laden kann. Lokal
eingebundene Bibliotheken machen den Render außerdem reproduzierbar.
