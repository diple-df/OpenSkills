@echo off
setlocal EnableDelayedExpansion
title opencode Skills Installer

set "OC_DIR=%USERPROFILE%\.config\opencode"
set "SKILLS=%OC_DIR%\skills"
set "WORK=%TEMP%\opencode-skills-install"

set "INSTALLED="
set "SKIPPED="
set "FAILED="
set "EXITCODE=0"

echo.
echo ============================================
echo   opencode Skills Installer
echo ============================================
echo.
echo   Target: %SKILLS%
echo.

rem --- prerequisites ---
where curl.exe >nul 2>nul
if errorlevel 1 (
    echo   [ERROR] curl.exe not found. Windows 10 1803+ required.
    set "EXITCODE=1"
    goto :end
)

where opencode >nul 2>nul
if errorlevel 1 (
    echo   [WARN] opencode not found in PATH. Skills will still be installed.
    echo.
)

where npm >nul 2>nul
if errorlevel 1 (
    echo   [WARN] npm not found in PATH. Plugin installs may be limited.
    echo.
)

if not exist "%OC_DIR%" mkdir "%OC_DIR%"
if not exist "%SKILLS%" mkdir "%SKILLS%"
if not exist "%WORK%" mkdir "%WORK%"
if errorlevel 1 (
    echo   [ERROR] could not create OpenCode directories
    set "EXITCODE=1"
    goto :end
)

call :install_policy
if errorlevel 1 goto :end

rem --- skills ---
call :install_raw firecrawl-research            glebis/claude-skills             firecrawl-research            ".claude-plugin/plugin.json .env.example SKILL.md assets/references.bib assets/templates/myst-scientific-paper.md assets/templates/pandoc-scholarly-paper.md requirements.txt scripts/convert_academic.py scripts/firecrawl_research.py scripts/generate_bibliography.py"
call :install_skill skill-creator               anthropics/skills                skills/skill-creator
call :install_skill webapp-testing              anthropics/skills                skills/webapp-testing
call :install_skill cloudflare                  cloudflare/skills                skills/cloudflare
call :install_skill stop-slop                   hardikpandya/stop-slop
call :install_skill vercel-react-best-practices koesnuj/vercel-react-best-practices
call :install_skill understand                  Egonex-AI/Understand-Anything    understand-anything-plugin/skills/understand
call :install_skill design-taste-frontend        Leonxlnx/taste-skill             skills/taste-skill
call :install_skill caveman                      JuliusBrussee/caveman            skills/caveman
call :install_skill context-compression          muratcankoylan/Agent-Skills-for-Context-Engineering skills/context-compression
call :install_skill prompt-engineering-patterns  wshobson/agents                  plugins/llm-application-dev/skills/prompt-engineering-patterns
call :install_skill frontend-design              anthropics/skills                skills/frontend-design
call :install_skill docx                         anthropics/skills                skills/docx
call :install_skill pdf                          anthropics/skills                skills/pdf
call :install_skill pptx                         anthropics/skills                skills/pptx
call :install_skill xlsx                         anthropics/skills                skills/xlsx
call :install_skill doc-coauthoring               anthropics/skills                skills/doc-coauthoring
call :install_skill security-audit                cloudflare/security-audit-skill  skills/security-audit
call :install_skill unslop                        heydamir/unslop                  skills/unslop

rem --- extra instruction packs (merged into AGENTS.md) ---
call :install_karpathy_instructions
call :install_rea_instructions

rem --- plugins ---
call :install_plugins

rem --- optional: ai-memory (memory server + MCP + hooks + skills) ---
rem   Skipped unless --with-ai-memory is passed or the prompt is answered "y".
set "AIM_STATUS=skipped"
if /i "%~1"=="--with-ai-memory" goto :ai_memory_yes
call :print_ai_memory_info
choice /c yn /n /t 15 /d n /m "  Install ai-memory (memory server, MCP, hooks, skills)? [y/N] "
if errorlevel 2 goto :ai_memory_no
:ai_memory_yes
call :install_ai_memory
if errorlevel 1 (set "AIM_STATUS=failed") else (set "AIM_STATUS=installed")
:ai_memory_no

rem --- shell non-interactive strategy (merged into AGENTS.md) ---
call :install_shell_strategy

echo.
echo ============================================
echo   Summary
echo ============================================
if defined INSTALLED echo   Installed:!INSTALLED!
if defined SKIPPED  echo   Skipped  :!SKIPPED!
if defined FAILED   echo   Failed   :!FAILED!
echo   ai-memory: !AIM_STATUS!  ^(enable with: install-skills.bat --with-ai-memory^)
echo.
echo   Restart opencode to load the new skills and plugins.
echo   Verify plugins with: opencode plugin list
echo   Check config: %OC_DIR%\opencode.json

rd /s /q "%WORK%" 2>nul

:end
endlocal & exit /b %EXITCODE%

rem ============================================================
rem :install_policy
rem   Add the managed global policy without replacing user rules.
rem ============================================================
:install_policy
setlocal DisableDelayedExpansion
set "POLICY=%OC_DIR%\AGENTS.md"
powershell -NoProfile -Command "$p='%POLICY%'; $c=if(Test-Path -LiteralPath $p){Get-Content -LiteralPath $p -Raw}else{''}; if($c -match 'OPENCODE-MANAGED-POLICY:START'){Write-Output 'SKIP'; exit 0}; $b=@('','<!-- OPENCODE-MANAGED-POLICY:START -->','## Global OpenCode Policy','','### GitHub and remote actions','- Do not run git push, create pull requests, issues, releases, or publish artifacts without direct user request.','- Do not suggest GitHub remote actions as an automatic next step.','- Local workflow commits are allowed when part of the task.','','### Efficient context usage','- Keep ordinary responses concise, while keeping plans, code, errors, verification results, and required process steps complete.','- Do not reread already established context unless new evidence or the current task requires it.','- Read only files relevant to the current task.','- Delegate broad, independent exploration when that reduces context usage.','- Do not start research workflows unless relevant to the request.','','### Quality workflow','- Keep the full Superpowers workflow active, including brainstorming, planning, TDD, debugging, review, verification, and justified subagent use.','- Direct user instructions take precedence over these defaults.','<!-- OPENCODE-MANAGED-POLICY:END -->'); Add-Content -LiteralPath $p -Value $b -Encoding UTF8; exit 0"
if errorlevel 1 (
    echo   [ERROR] could not write global AGENTS.md policy
    endlocal & set "EXITCODE=1" & exit /b 1
)
if exist "%POLICY%" (
    findstr /c:"OPENCODE-MANAGED-POLICY:START" "%POLICY%" >nul 2>nul
    if not errorlevel 1 echo   [OK] global AGENTS.md policy checked
)
endlocal & exit /b 0

rem ============================================================
rem :install_raw  "name" "owner/repo" "subpath" "file file ..."
rem   Download listed files via raw.githubusercontent. Used for
rem   repos whose zips contain entries with invalid characters.
rem ============================================================
:install_raw
set "SKILL=%~1"
set "REPO=%~2"
set "SUBPATH=%~3"
set "FILES=%~4"

if exist "%SKILLS%\%SKILL%\SKILL.md" (
    echo   [SKIP] %SKILL% already installed
    set "SKIPPED=!SKIPPED! %SKILL%"
    exit /b 0
)

echo   [INSTALL] %SKILL%
for %%f in (%FILES%) do (
    curl -L -s --fail --create-dirs -o "%SKILLS%\%SKILL%\%%f" "https://raw.githubusercontent.com/%REPO%/main/%SUBPATH%/%%f"
    if errorlevel 1 (
        echo   [ERROR] download failed for %SKILL%: %%f
        set "FAILED=!FAILED! %SKILL%"
        set "EXITCODE=1"
        del "%SKILLS%\%SKILL%\SKILL.md" >nul 2>nul
        exit /b 1
    )
)
if not exist "%SKILLS%\%SKILL%\SKILL.md" (
    echo   [ERROR] download failed for %SKILL%
    set "FAILED=!FAILED! %SKILL%"
    set "EXITCODE=1"
    exit /b 1
)
echo   [OK] %SKILL%
set "INSTALLED=!INSTALLED! %SKILL%"
exit /b 0

rem ============================================================
rem :install_skill  "name" "owner/repo" ["subpath/inside/zip"]
rem ============================================================
:install_skill
set "SKILL=%~1"
set "REPO=%~2"
set "SUBPATH=%~3"

if exist "%SKILLS%\%SKILL%\SKILL.md" (
    echo   [SKIP] %SKILL% already installed
    set "SKIPPED=!SKIPPED! %SKILL%"
    exit /b 0
)

echo   [INSTALL] %SKILL%
curl -L -s --fail -o "%WORK%\%SKILL%.zip" "https://github.com/%REPO%/archive/refs/heads/main.zip"
if errorlevel 1 (
    echo   [ERROR] download failed for %SKILL%
    set "FAILED=!FAILED! %SKILL%"
    set "EXITCODE=1"
    exit /b 1
)

powershell -NoProfile -Command "Expand-Archive -LiteralPath '%WORK%\%SKILL%.zip' -DestinationPath '%WORK%\%SKILL%' -Force"
if errorlevel 1 (
    echo   [ERROR] extract failed for %SKILL%
    set "FAILED=!FAILED! %SKILL%"
    set "EXITCODE=1"
    exit /b 1
)

set "ROOT="
for /d %%d in ("%WORK%\%SKILL%\*") do set "ROOT=%%d"
if "%ROOT%"=="" (
    echo   [ERROR] no extracted folder for %SKILL%
    set "FAILED=!FAILED! %SKILL%"
    set "EXITCODE=1"
    exit /b 1
)

set "SRC=%ROOT%"
if not "%SUBPATH%"=="" set "SRC=%ROOT%\%SUBPATH%"

if not exist "%SRC%\SKILL.md" (
    echo   [ERROR] SKILL.md not found for %SKILL%
    set "FAILED=!FAILED! %SKILL%"
    set "EXITCODE=1"
    exit /b 1
)

robocopy "%SRC%" "%SKILLS%\%SKILL%" /E /NFL /NDL /NJH /NJS >nul
if errorlevel 8 (
    echo   [ERROR] copy failed for %SKILL%
    set "FAILED=!FAILED! %SKILL%"
    set "EXITCODE=1"
    exit /b 1
)

echo   [OK] %SKILL%
set "INSTALLED=!INSTALLED! %SKILL%"
exit /b 0

rem ============================================================
rem :install_karpathy_instructions
rem   Download Andrej Karpathy inspired guidelines and merge into AGENTS.md
rem ============================================================
:install_karpathy_instructions
setlocal DisableDelayedExpansion
set "K_URL=https://raw.githubusercontent.com/forrestchang/andrej-karpathy-skills/main/CLAUDE.md"
set "K_FILE=%WORK%\karpathy-claude.md"
curl -L -s --fail -o "%K_FILE%" "%K_URL%"
if errorlevel 1 (
    echo   [WARN] download failed: andrej-karpathy-skills
    endlocal & exit /b 0
)

powershell -NoProfile -Command "$a='%OC_DIR%\AGENTS.md'; $f='%K_FILE%'; $c=if(Test-Path -LiteralPath $a){Get-Content -LiteralPath $a -Raw -Encoding UTF8}else{''}; if($c -match 'OPENCODE-MANAGED:karpathy-skills:START'){Write-Output 'SKIP'; exit 0}; $body=Get-Content -LiteralPath $f -Raw -Encoding UTF8; $b=@('','<!-- OPENCODE-MANAGED:karpathy-skills:START -->','## Andrej Karpathy Inspired Guidelines','',$body,'','<!-- OPENCODE-MANAGED:karpathy-skills:END -->'); Add-Content -LiteralPath $a -Value $b -Encoding UTF8; Write-Output 'ADDED'"
if errorlevel 1 (
    echo   [WARN] could not append andrej-karpathy-skills to AGENTS.md
    endlocal & exit /b 0
)
echo   [OK] andrej-karpathy-skills merged into AGENTS.md
endlocal & exit /b 0

rem ============================================================
rem :install_rea_instructions
rem   Download REA reverse engineering agent docs/README guidance
rem ============================================================
:install_rea_instructions
setlocal DisableDelayedExpansion
set "REA_URL=https://raw.githubusercontent.com/morluto/rea/main/README.md"
set "REA_FILE=%WORK%\rea-readme.md"
curl -L -s --fail -o "%REA_FILE%" "%REA_URL%"
if errorlevel 1 (
    echo   [WARN] download failed: rea
    endlocal & exit /b 0
)

powershell -NoProfile -Command "$a='%OC_DIR%\AGENTS.md'; $f='%REA_FILE%'; $c=if(Test-Path -LiteralPath $a){Get-Content -LiteralPath $a -Raw -Encoding UTF8}else{''}; if($c -match 'OPENCODE-MANAGED:rea:START'){Write-Output 'SKIP'; exit 0}; $body=Get-Content -LiteralPath $f -Raw -Encoding UTF8; $b=@('','<!-- OPENCODE-MANAGED:rea:START -->','## REA - Reverse Engineer Anything','',$body,'','<!-- OPENCODE-MANAGED:rea:END -->'); Add-Content -LiteralPath $a -Value $b -Encoding UTF8; Write-Output 'ADDED'"
if errorlevel 1 (
    echo   [WARN] could not append rea to AGENTS.md
    endlocal & exit /b 0
)
echo   [OK] rea merged into AGENTS.md
endlocal & exit /b 0

rem ============================================================
rem :install_plugins
rem   Installs the superpowers package locally, then registers
rem   plugins through the OpenCode V2 CLI. The CLI accepts only
rem   npm/Git specs, so the local superpowers path is registered
rem   separately by :ensure_superpowers_plugin. Fails gracefully.
rem ============================================================
:install_plugins
where npm >nul 2>nul
if errorlevel 1 (
    echo   [WARN] npm not found - skipping superpowers package install
) else (
    echo   [INSTALL] superpowers package ^(npm^)
    pushd "%OC_DIR%" 2>nul
    if errorlevel 1 (
        echo   [WARN] cannot access %OC_DIR% for npm install
    ) else (
        call npm install --no-fund --no-audit "@opencode-ai/plugin@1.18.13" "superpowers@https://codeload.github.com/obra/superpowers/tar.gz/refs/heads/main"
        set "NPMRC=!errorlevel!"
        if not exist "%OC_DIR%\node_modules\superpowers\package.json" (
            echo   [WARN] superpowers package missing - retrying npm install
            call npm install --no-fund --no-audit "superpowers@https://codeload.github.com/obra/superpowers/tar.gz/refs/heads/main"
            set "NPMRC=!errorlevel!"
        )
        if not exist "%OC_DIR%\node_modules\superpowers\package.json" (
            echo   [ERROR] superpowers package not installed - plugin will fail to load
            set "EXITCODE=1"
        ) else (
            echo   [OK] superpowers package
        )
        popd
    )
)

call :ensure_superpowers_plugin

call :plugin_add "@tarquinen/opencode-dcp"
call :plugin_add "opencode-wakatime"
call :plugin_add "opencode-openrouter-auth"

exit /b 0

rem ============================================================
rem :print_ai_memory_info
rem   Plain-language explanation shown before the optional prompt.
rem ============================================================
:print_ai_memory_info
echo.
echo   ai-memory - long-term memory for coding agents
echo   ---------------------------------------------
echo   A small local server that remembers what your agents learned
echo   about each project: decisions, failed approaches, open questions.
echo   Memory is kept as readable markdown pages plus a local index.
echo.
echo   Useful if you:
echo     - restart often and hate re-explaining the same context
echo     - switch agents or machines, or share a repo with a team
echo     - want handoffs that say exactly where work stopped
echo.
echo   What it costs:
echo     - runs a background service on this machine
echo     - session notes are stored locally; nothing leaves the machine
echo       unless you configure an LLM provider
echo     - adds MCP tools and hooks to your agents, which use some context
echo     - zero LLM calls by default; semantic search and summaries are
echo       optional and need an API key
echo.
echo   Skip it for short one-off sessions. Remove later with:
echo     ai-memory uninstall --apply
echo   ---------------------------------------------
echo.
exit /b 0

rem ============================================================
rem :install_ai_memory
rem   Official ai-memory install: release binary via install.ps1,
rem   then "setup --yes --agent opencode", which probes the host
rem   and wires MCP, hooks and agent skills. Idempotent.
rem ============================================================
:install_ai_memory
setlocal DisableDelayedExpansion
set "AIM="
if exist "%LOCALAPPDATA%\Programs\ai-memory\ai-memory.exe" set "AIM=%LOCALAPPDATA%\Programs\ai-memory\ai-memory.exe"
if not defined AIM for /f "delims=" %%i in ('where ai-memory 2^>nul') do if not defined AIM set "AIM=%%i"

if defined AIM goto :aim_setup

echo   [INSTALL] ai-memory ^(release binary^)
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://github.com/akitaonrails/ai-memory/releases/latest/download/install.ps1 | iex"
if errorlevel 1 goto :aim_fail
set "AIM=%LOCALAPPDATA%\Programs\ai-memory\ai-memory.exe"
if not exist "%AIM%" goto :aim_fail

:aim_setup
echo   [SETUP] ai-memory setup --yes --agent opencode
call "%AIM%" setup --yes --agent opencode
if errorlevel 1 goto :aim_fail
echo   [OK] ai-memory ^(MCP server, hooks, skills^)
endlocal & exit /b 0

:aim_fail
echo   [ERROR] ai-memory install/setup failed - see problem: lines above
endlocal & set "EXITCODE=1" & exit /b 1

rem ============================================================
rem :plugin_add  "spec"
rem   Register one npm/Git plugin with the OpenCode V2 CLI.
rem   Falls back to writing opencode.json if CLI unavailable/fails.
rem ============================================================
:plugin_add
set "PSPEC=%~1"
where opencode >nul 2>nul
if not errorlevel 1 (
    call opencode plugin add "%PSPEC%" 2>nul
    if not errorlevel 1 (
        echo   [OK] plugin registered via CLI: %PSPEC%
        exit /b 0
    )
)
rem fallback: ensure in opencode.json
powershell -NoProfile -Command "$spec='%PSPEC%'; $dir='%OC_DIR%'; $files=@((Join-Path $dir 'opencode.json'),(Join-Path $dir 'opencode.jsonc')); foreach($f in $files){ if((Test-Path -LiteralPath $f) -and ((Get-Content -LiteralPath $f -Raw) -match [regex]::Escape($spec))){ Write-Output 'SKIP'; exit 0 } }; $p=Join-Path $dir 'opencode.json'; if(Test-Path -LiteralPath $p){ try { $raw=Get-Content -LiteralPath $p -Raw; $c=$raw | ConvertFrom-Json } catch { $c=[pscustomobject]@{ '$schema'='https://opencode.ai/config.json' } } } else { $c=[pscustomobject]@{ '$schema'='https://opencode.ai/config.json' } }; if(-not $c.PSObject.Properties['plugins']){ $c | Add-Member -NotePropertyName plugins -NotePropertyValue @() -Force }; $list=@($c.plugins); if($list -notcontains $spec){ $list += $spec }; $c.plugins=$list; $c | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $p -Encoding UTF8; Write-Output 'ADDED'"
if errorlevel 1 (
    echo   [WARN] could not register plugin %PSPEC% in opencode.json
    set "EXITCODE=1"
    exit /b 1
)
echo   [OK] plugin added to opencode.json: %PSPEC%
exit /b 0

rem ============================================================
rem :ensure_superpowers_plugin
rem   Ensures the local superpowers path is registered in a
rem   global config file. The CLI cannot register local paths, so
rem   opencode.json is edited only if neither config has it yet.
rem ============================================================
:ensure_superpowers_plugin
powershell -NoProfile -Command "$spec='~/.config/opencode/node_modules/superpowers'; $dir='%OC_DIR%'; $files=@((Join-Path $dir 'opencode.json'),(Join-Path $dir 'opencode.jsonc')); foreach($f in $files){ if((Test-Path -LiteralPath $f) -and ((Get-Content -LiteralPath $f -Raw) -match [regex]::Escape($spec))){ Write-Output 'SKIP'; exit 0 } }; $p=Join-Path $dir 'opencode.json'; if(Test-Path -LiteralPath $p){ $c=Get-Content -LiteralPath $p -Raw | ConvertFrom-Json } else { $c=[pscustomobject]@{ '$schema'='https://opencode.ai/config.json' } }; if(-not $c.PSObject.Properties['plugins']){ $c | Add-Member -NotePropertyName plugins -NotePropertyValue @() -Force }; $list=@($c.plugins); if($list -notcontains $spec){ $list += $spec }; $c.plugins=$list; $c | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $p -Encoding UTF8; Write-Output 'ADDED'"
if errorlevel 1 (
    echo   [WARN] could not register superpowers plugin entry
    set "EXITCODE=1"
    exit /b 1
)
echo   [OK] superpowers plugin registered
exit /b 0

rem ============================================================
rem :install_shell_strategy
rem   Downloads the shell non-interactive strategy and merges it
rem   into the global AGENTS.md. V2 ignores the "instructions"
rem   config field, but always loads AGENTS.md.
rem ============================================================
:install_shell_strategy
setlocal DisableDelayedExpansion
set "SS_URL=https://raw.githubusercontent.com/JRedeker/opencode-shell-strategy/master/shell_strategy.md"
set "SS_DIR=%OC_DIR%\instructions"
set "SS_FILE=%SS_DIR%\shell-strategy.md"

if not exist "%SS_DIR%" mkdir "%SS_DIR%"
curl -L -s --fail -o "%SS_FILE%" "%SS_URL%"
if errorlevel 1 (
    echo   [WARN] download failed: shell-strategy
    endlocal & set "EXITCODE=1" & exit /b 1
)

powershell -NoProfile -Command "$a='%OC_DIR%\AGENTS.md'; $f='%SS_FILE%'; $c=if(Test-Path -LiteralPath $a){Get-Content -LiteralPath $a -Raw -Encoding UTF8}else{''}; if($c -match 'OPENCODE-MANAGED:shell-strategy:START'){Write-Output 'SKIP'; exit 0}; $body=Get-Content -LiteralPath $f -Raw -Encoding UTF8; $b=@('','<!-- OPENCODE-MANAGED:shell-strategy:START -->','',$body,'','<!-- OPENCODE-MANAGED:shell-strategy:END -->'); Add-Content -LiteralPath $a -Value $b -Encoding UTF8; Write-Output 'ADDED'"
if errorlevel 1 (
    echo   [WARN] could not append shell-strategy to AGENTS.md
    endlocal & set "EXITCODE=1" & exit /b 1
)
echo   [OK] shell-strategy merged into AGENTS.md
endlocal & exit /b 0
