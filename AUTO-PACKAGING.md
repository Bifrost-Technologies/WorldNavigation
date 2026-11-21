# Automatic packaging — World Navigation

Client: Forever WoW 1.60.1 / Interface 16001. Current source version: 0.1.0-beta.5.

GitHub website → repository Settings → Secrets and variables → Actions:

- Secret CF_API_TOKEN: your CurseForge author upload token.
- Variable CF_PROJECT_ID: this project's numeric ID.
- Variable CF_GAME_VERSION_IDS: actual supported CurseForge version IDs, comma-separated. No client version is guessed.

Pushes package an artifact. Default-branch pushes can upload Alpha files when configured. Tags matching v<TOC-version> use the version's Alpha/Beta/Release type. Missing credentials keep packaging local to Actions; missing/invalid game version IDs stop upload. Four newly initialized repositories may still need publishing and a remote. No remote setup or upload was performed here.

See release.md for the complete publishing form and runtime limitations. Do not upload source-repository ZIPs, private helpers or development reports.
