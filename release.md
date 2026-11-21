# World Navigation — release form

Prepared November 20, 2026. Current package **0.1.0-beta.5**. Files are prepared locally; no submission, approval, remote workflow run or live-client certification is claimed.

## Project fields

| Field | Value |
| --- | --- |
| Game | World of Warcraft |
| Project name | World Navigation |
| Proposed slug | worldnavigation (use the existing project's slug when updating) |
| Summary | Public road-preferred image-weight routing for Flight Path Finder guidance. |
| Class | Addons |
| Main / additional categories | Map & Minimap; Libraries; Travel — select matching labels available in the form |
| License | MIT, matching bundled source LICENSE notices; retain third-party asset notices |
| Logo/avatar | Select an original project PNG (minimum 400×400); no project avatar has been selected by this preparation. |
| Allow comments | Enabled |
| Listing visibility | Public; do not enable experimental/unlisted unless deliberately desired |
| Description format | Markdown; paste the description below |
| Author / members | Your actual CurseForge publishing account and actual contributors |
| Project ID | Use this addon's assigned numeric CurseForge ID; not available from local source |
| Source URL | Not configured/published locally; fill this after publishing the repository. |
| Issues / wiki | Use actual published URLs; otherwise leave blank and use CurseForge comments |
| Donation / social links | Optional; leave blank unless you supply real links |
| Screenshots | Add real addon screenshots; no new screenshots are included in this handoff |

## Description — copy/paste

World Navigation supplies route planning to Flight Path Finder using native-georeferenced map-image weight grids. Roads are preferred over ordinary traversable ground, and remembered no-pass and hazard data can affect route cost. Cross-zone routing combines aligned image coverage. Map artwork is a 2D estimate: painted hills do not provide measured heights or collision. Dungeon image templates require a matching native map/floor binding before routing. This public library has no route recorder, combat import, automatic movement or compiled helper. Combat World Navigation is a separate private addon.

Built for **Forever WoW 1.60.1 / Interface 16001**. Open `/wnav`. Other Retail/Classic clients are not certified by this release. Native game restrictions and unavailable APIs still apply.

## File upload fields

| Field | Value |
| --- | --- |
| Upload file | `WorldNavigation-0.1.0-beta.5.zip` — upload this ZIP alone |
| Display name | World Navigation 0.1.0-beta.5 |
| Release type | Beta |
| Release options | Release after moderation approval, or choose manual scheduling in your account |
| Supported client / version | Forever WoW 1.60.1, Interface 16001. Select its actual supported entry if offered; do not relabel it as another client. Confirm with CurseForge support if this client is not listed. |
| Related projects | None required. Intended consumer: Flight Path Finder. Optional terrain providers are not required for available image routes. |
| SHA-256 | `adcaf110c837b81462ebcbb7cf033550d29c11002c247089cc612e0eb65198d2` |
| ZIP root addon folders (1) | `WorldNavigation` |

### Changelog — copy/paste

Current image-weight and cross-zone planner packaged. Public guidance-only scope and unknown height/collision limits documented.

Packaging verified direct addon-root layout, manifest-declared files, matching generic/Camelot manifests, ZIP decompression/CRC and SHA-256. No gameplay or test suites were run for this packaging pass. Runtime limits are described above and in bundled READMEs.

## GitHub commit packaging

The repository's `.github/workflows/release.yml` builds an artifact on pushes. In GitHub Settings → Secrets and variables → Actions, set secret `CF_API_TOKEN`, variable `CF_PROJECT_ID`, and variable `CF_GAME_VERSION_IDS` with real supported numeric version IDs. No account tokens are stored in this document. Default-branch commits upload Alpha files when configured; a tag `v0.1.0-beta.5` uploads this Beta version. Generated ZIPs remain local build artifacts; commit source/configuration instead. Do not use duplicate CurseForge webhooks and Actions upload for the same commit.

Remote publication/configuration has not been performed. Missing logo, project ID, real supported-version selection or unpublished source URLs are author/account fields to complete before submitting. Private toolkit/helpers/recorders and private development reports are excluded.

## Official field references

- [Creating and submitting a project](https://support.curseforge.com/support/solutions/articles/9000197241)
- [Submission fields, original logo and project links](https://support.curseforge.com/support/solutions/articles/9000199552-project-submission-guide-and-tips)
- [Upload API](https://support.curseforge.com/support/solutions/articles/9000197321)
