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
- Node.js and `npm` for the plugin step and for `ai-memory` skills

## What gets installed

### Skills

Installed into `%USERPROFILE%\.config\opencode\skills\<name>`.

| Skill | Upstream |
|-------|----------|
| `firecrawl-research` | glebis/claude-skills |
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

Each skill is fetched from the upstream `main` branch, and the installer verifies
that `SKILL.md` is present before copying it into place.

### Instruction packs

Appended to the global `AGENTS.md` as managed blocks that are replaced on every
run, leaving your own rules untouched:

- Global OpenCode policy (GitHub and remote-action rules, context usage)
- Andrej Karpathy inspired coding guidelines
- REA reverse-engineering guidance
- Non-interactive shell strategy for headless agent sessions

### Plugins

- `superpowers` - planning, TDD, debugging, and review workflow skills
- `@tarquinen/opencode-dcp` - dynamic context pruning
- `opencode-wakatime` - WakaTime activity tracking
- `opencode-openrouter-auth` - OpenRouter authentication

Existing plugin entries in `opencode.json` are left as they are.

### Optional: ai-memory

Long-term memory for coding agents: a local server that remembers decisions,
failed approaches, and open questions per project, with MCP tools, hooks, and
its own skills.

It is off by default. Enable it either way:

```bat
install-skills.bat --with-ai-memory
```

or answer `y` at the prompt. The script runs the official upstream installer and
then `ai-memory setup --yes --agent opencode`. Remove it later with
`ai-memory uninstall --apply`.

Skip it if you only work in short one-off sessions.

## How it works

- `:install_skill` downloads `https://github.com/<repo>/archive/refs/heads/main.zip`,
  expands it into `%TEMP%\opencode-skills-install`, and copies the skill
  subdirectory into the OpenCode skills folder.
- `:install_raw` downloads individual files via `raw.githubusercontent.com`, which
  is used for skills that need a fixed file list.
- Managed `AGENTS.md` sections are wrapped in
  `<!-- OPENCODE-MANAGED:<name>:START -->` / `:END` markers.
- A summary at the end lists what was installed, skipped, and failed, and the
  script exits with `0` on success or `1` when a step failed.

## Uninstall

- Delete the skill folders under `%USERPROFILE%\.config\opencode\skills`.
- Remove the `OPENCODE-MANAGED` blocks from `%USERPROFILE%\.config\opencode\AGENTS.md`.
- Remove the plugin entries from `%USERPROFILE%\.config\opencode\opencode.json`
  and the matching packages from `%USERPROFILE%\.config\opencode\node_modules`.
- If installed, run `ai-memory uninstall --apply`.
