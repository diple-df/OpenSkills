# OpenSkills

Windows installer that sets up [OpenCode](https://opencode.ai) with a curated
skill pack, instruction policies, and plugins.

Run it once on a fresh machine, and re-run it later to pick up updates. Existing
skills are skipped, so it is safe to run repeatedly.

## Quick start

```bat
git clone https://github.com/diple-df/OpenSkills.git
cd OpenSkills
install-skills.bat
```

Restart OpenCode afterward to load the new skills and plugins.

Requirements:

- Windows 10 1803+ (`curl.exe` is used for downloads)
- OpenCode in `PATH` (skills still install if it is missing)
- Node.js and `npm` for the plugin step

## What gets installed

### Skills

Installed into `%USERPROFILE%\.config\opencode\skills\<name>`.

| Skill | Upstream |
|-------|----------|
| `skill-creator` | anthropics/skills |
| `webapp-testing` | anthropics/skills |
| `cloudflare` | cloudflare/skills |
| `stop-slop` | hardikpandya/stop-slop |
| `vercel-react-best-practices` | koesnuj/vercel-react-best-practices |
| `understand` | Egonex-AI/Understand-Anything |
| `design-taste-frontend` | Leonxlnx/taste-skill |
| `caveman` | JuliusBrussee/caveman |
| `context-compression` | muratcankoylan/Agent-Skills-for-Context-Engineering |
| `prompt-engineering-patterns` | wshobson/agents |
| `frontend-design` | anthropics/skills |
| `docx` | anthropics/skills |
| `pdf` | anthropics/skills |
| `pptx` | anthropics/skills |
| `xlsx` | anthropics/skills |
| `doc-coauthoring` | anthropics/skills |
| `security-audit` | cloudflare/security-audit-skill |
| `unslop` | heydamir/unslop |
| `ppt-design-skill` | sunchaokun/PPT-Design-Skill |
| `typeui-fundamentals` | bergside/typeui |
| `modern-web-guidance` | GoogleChrome/modern-web-guidance |
| `ponytail` | DietrichGebert/ponytail |
| `ascii-art-diagrams` | jasnell/opencode-skill-ascii-art-diagrams |
| `karpathy-guidelines` | multica-ai/andrej-karpathy-skills |
| `reverse-engineer-anything` | morluto/rea |
| `rea-analysis-optimization` | morluto/rea |
| `rea-changelog-update` | morluto/rea |
| `rea-ci-tests-audit` | morluto/rea |
| `rea-tool-design` | morluto/rea |

Each skill is fetched from the upstream `main` branch, and the installer verifies
that `SKILL.md` is present before copying it into place.

`modern-web-guidance` runs `npx modern-web-guidance` at query time, so the skill
body is small but the guides are fetched on demand. `ascii-art-diagrams` needs
Python 3 for its `scripts/grid.py` and `scripts/verify.py` helpers.
The `rea-*` skills drive REA's MCP server, so they need REA registered with the
agent and a native analysis provider for anything beyond static inspection.

### Instruction packs

Appended to the global `AGENTS.md` as managed blocks that are replaced on every
run, leaving your own rules untouched:

- Global OpenCode policy (GitHub and remote-action rules, context usage)
- Non-interactive shell strategy for headless agent sessions

Karpathy guidelines and REA guidance used to be merged into `AGENTS.md`; both
are now proper skills (`karpathy-guidelines` and the `rea-*` set) that load only
when relevant instead of sitting in every session's context.

### Plugins

Registered through `opencode plugin add`, which writes the global
`opencode.json`:

| Plugin | Purpose |
|--------|---------|
| `superpowers` | planning, TDD, debugging, and review workflow skills (local path) |
| `@tarquinen/opencode-dcp` | dynamic context pruning |
| `opencode-wakatime` | WakaTime activity tracking |
| `opencode-skills-tui` | skills sidebar with loaded state, `SKILL.md` preview, `@` insert |
| `opencode-dir-tree-tui` | file tree sidebar with Git status and ignore rules |
| `@atonev/opencode-short-term-memory` | structured session memory that survives compaction |
| `opencode-websearch-cited` | web search with inline citations |
| `@firecrawl/opencode` | Firecrawl developer index, Alexandria data, CLI skills |
| `opencode-see-image` | routes images to a vision model for non-vision models |
| `opencode-pty` | real PTY background processes with interactive input |
| `opencode-mermaid-renderer` | renders mermaid blocks as ASCII art |
| `@franlol/opencode-md-table-formatter` | aligns markdown tables after generation |
| `@spoons-and-mirrors/subtask2` | chains, loops, and relays subagent results |
| `opencode-zellij-namer` | AI-driven Zellij session naming |

Two plugins install differently:

- `superpowers` is an npm package installed into
  `%USERPROFILE%\.config\opencode\node_modules` and registered by path, because
  the CLI only accepts npm and Git specs.
- `cache-stats` (nmdra/opencode-cache-stats) is not published to npm. The
  installer copies its plugin directory to
  `%USERPROFILE%\.config\opencode\plugins\cache-stats` and enables it in
  `cli.json`, which is where TUI-only plugins must live.

`opencode-websearch-cited` needs one `websearch_cited` model per provider in your
config, and it must stay last in the plugin list so it does not interfere with
provider authentication. `opencode-zellij-namer` degrades to pattern-based naming
without `GEMINI_API_KEY`. `opencode-see-image` is a no-op once the active model
can already accept image input.

### Config file encoding

OpenCode writes `opencode.json` with a UTF-8 BOM and then refuses to parse a
config that begins with one, reporting `Invalid global configuration`. The
installer strips the BOM from `opencode.json` and `cli.json` before registering
plugins, and every file it writes itself is BOM-free.

## How it works

- `:install_skill` downloads `https://github.com/<repo>/archive/refs/heads/main.zip`,
  expands it into `%TEMP%\opencode-skills-install`, and copies the skill
  subdirectory into the OpenCode skills folder.
- Managed `AGENTS.md` sections are wrapped in
  `<!-- OPENCODE-MANAGED:<name>:START -->` / `:END` markers.
- `:plugin_add` prefers `opencode plugin add` and falls back to editing
  `opencode.json` directly when the CLI is missing or fails.
- `:fix_bom` normalises config encoding before the plugin step.
- A summary at the end lists what was installed, skipped, and failed, and the
  script exits with `0` on success or `1` when a step failed.

## Uninstall

- Delete the skill folders under `%USERPROFILE%\.config\opencode\skills`.
- Remove the `OPENCODE-MANAGED` blocks from `%USERPROFILE%\.config\opencode\AGENTS.md`.
- Remove the plugin entries with `opencode plugin remove <package>`.
- Delete `%USERPROFILE%\.config\opencode\plugins\cache-stats` and its `cli.json`
  entry.
- Delete `%USERPROFILE%\.config\opencode\node_modules\superpowers` and its
  `opencode.json` entry.
