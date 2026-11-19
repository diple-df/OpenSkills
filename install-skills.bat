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
call :install_skill ppt-design-skill              sunchaokun/PPT-Design-Skill      skill
call :install_skill typeui-fundamentals           bergside/typeui                  skills/fundamentals
call :install_skill modern-web-guidance           GoogleChrome/modern-web-guidance skills/modern-web-guidance
call :install_skill ponytail                      DietrichGebert/ponytail          skills/ponytail
call :install_skill ascii-art-diagrams            jasnell/opencode-skill-ascii-art-diagrams
call :install_skill karpathy-guidelines           multica-ai/andrej-karpathy-skills skills/karpathy-guidelines
call :install_skill reverse-engineer-anything     morluto/rea                      .agents/skills/reverse-engineer-anything
call :install_skill rea-analysis-optimization     morluto/rea                      .agents/skills/rea-analysis-optimization
call :install_skill rea-changelog-update          morluto/rea                      .agents/skills/rea-changelog-update
call :install_skill rea-ci-tests-audit            morluto/rea                      .agents/skills/rea-ci-tests-audit
call :install_skill rea-tool-design               morluto/rea                      .agents/skills/rea-tool-design

rem --- plugins ---
call :install_plugins

rem --- ai-memory is no longer installed by this pack ---

rem --- shell non-interactive strategy (merged into AGENTS.md) ---
call :install_shell_strategy

echo.
echo ============================================
echo   Summary
echo ============================================
if defined INSTALLED echo   Installed:!INSTALLED!
if defined SKIPPED  echo   Skipped  :!SKIPPED!
if defined FAILED   echo   Failed   :!FAILED!
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
rem :install_plugins
rem   Installs the superpowers package locally, then registers
rem   plugins through the OpenCode V2 CLI. The CLI accepts only
rem   npm/Git specs, so the local superpowers path is registered
rem   separately by :ensure_superpowers_plugin. Fails gracefully.
rem ============================================================
:install_plugins
call :fix_bom

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

rem --- core ---
call :plugin_add "@tarquinen/opencode-dcp"
call :plugin_add "opencode-wakatime"

rem --- sidebar / TUI ---
call :plugin_add "opencode-skills-tui"
call :plugin_add "opencode-dir-tree-tui"
call :install_cache_stats

rem --- context and search ---
call :plugin_add "@atonev/opencode-short-term-memory"
call :plugin_add "@firecrawl/opencode"
call :plugin_add "opencode-see-image"

rem --- installed but disabled on purpose ---
rem   These six export a bare async function as their default, which OpenCode 2
rem   rejects: "Plugin must export a default definition with an id and an effect
rem   or setup function". Installing them keeps the package on disk and a "-"
rem   entry in opencode.json, so they never load. Re-check with
rem   "opencode plugin check" or by reading the upstream READMEs; once a release
rem   ships a V2 definition, delete the "-" prefix here and re-run this script.
call :plugin_add_disabled "opencode-pty"
call :plugin_add_disabled "opencode-mermaid-renderer"
call :plugin_add_disabled "@franlol/opencode-md-table-formatter"
call :plugin_add_disabled "@spoons-and-mirrors/subtask2"
call :plugin_add_disabled "opencode-zellij-namer"
call :plugin_add_disabled "opencode-websearch-cited"

exit /b 0

rem ============================================================
rem :fix_bom
rem   OpenCode writes its JSON with a UTF-8 BOM and then refuses
rem   to parse a config that starts with one: "Invalid global
rem   configuration". Rewrite opencode.json and cli.json without
rem   the BOM so "opencode plugin add" works. Content is kept
rem   byte-for-byte apart from the leading mark.
rem ============================================================
:fix_bom
powershell -NoProfile -Command "$enc=New-Object System.Text.UTF8Encoding($false); foreach($n in @('opencode.json','cli.json')){ $p=Join-Path '%OC_DIR%' $n; if(-not (Test-Path -LiteralPath $p)){ continue }; $b=[System.IO.File]::ReadAllBytes($p); if($b.Length -ge 3 -and $b[0] -eq 239 -and $b[1] -eq 187 -and $b[2] -eq 191){ $t=$enc.GetString($b,3,$b.Length-3); [System.IO.File]::WriteAllText($p,$t,$enc); Write-Output ('STRIPPED ' + $n) } }"
if errorlevel 1 (
    echo   [WARN] could not normalise BOM in OpenCode config files
    exit /b 1
)
exit /b 0

rem ============================================================
rem :install_cache_stats
rem   nmdra/opencode-cache-stats is not published to npm, so the
rem   V2 plugin directory is copied verbatim into the global
rem   plugins folder and enabled through cli.json.
rem ============================================================
:install_cache_stats
set "CS_SRC=%OC_DIR%\plugins\cache-stats"
if exist "%CS_SRC%\stats.ts" (
    echo   [SKIP] cache-stats already installed
    set "SKIPPED=!SKIPPED! cache-stats"
    goto :cs_enable
)

echo   [INSTALL] cache-stats
if not exist "%OC_DIR%\plugins" mkdir "%OC_DIR%\plugins"
curl -L -s --fail -o "%WORK%\cache-stats.zip" "https://github.com/nmdra/opencode-cache-stats/archive/refs/heads/main.zip"
if errorlevel 1 (
    echo   [ERROR] download failed for cache-stats
    set "FAILED=!FAILED! cache-stats"
    set "EXITCODE=1"
    exit /b 1
)

powershell -NoProfile -Command "Expand-Archive -LiteralPath '%WORK%\cache-stats.zip' -DestinationPath '%WORK%\cache-stats' -Force"
if errorlevel 1 (
    echo   [ERROR] extract failed for cache-stats
    set "FAILED=!FAILED! cache-stats"
    set "EXITCODE=1"
    exit /b 1
)

set "CS_ROOT="
for /d %%d in ("%WORK%\cache-stats\*") do set "CS_ROOT=%%d"
if not exist "%CS_ROOT%\plugins\cache-stats\stats.ts" (
    echo   [ERROR] cache-stats plugin directory not found in archive
    set "FAILED=!FAILED! cache-stats"
    set "EXITCODE=1"
    exit /b 1
)

robocopy "%CS_ROOT%\plugins\cache-stats" "%CS_SRC%" /E /NFL /NDL /NJH /NJS >nul
if errorlevel 8 (
    echo   [ERROR] copy failed for cache-stats
    set "FAILED=!FAILED! cache-stats"
    set "EXITCODE=1"
    exit /b 1
)
echo   [OK] cache-stats
set "INSTALLED=!INSTALLED! cache-stats"

:cs_enable
set "CS_ENABLE_PS=%WORK%\cs-enable.ps1"
> "%CS_ENABLE_PS%" echo $p = Join-Path '%OC_DIR%' 'cli.json';
>>"%CS_ENABLE_PS%" echo $want = @('./plugins/cache-stats','@streetturtle/opencode-current-model','@streetturtle/opencode-current-prompt');
>>"%CS_ENABLE_PS%" echo if (Test-Path -LiteralPath $p) { $c = Get-Content -LiteralPath $p -Raw ^| ConvertFrom-Json } else { $c = [pscustomobject]@{ '$schema' = 'https://opencode.ai/v2/cli.json' } };
>>"%CS_ENABLE_PS%" echo if (-not $c.PSObject.Properties['plugins']) { $c ^| Add-Member -NotePropertyName plugins -NotePropertyValue @() -Force };
>>"%CS_ENABLE_PS%" echo $added = @();
>>"%CS_ENABLE_PS%" echo foreach ($spec in $want) {
>>"%CS_ENABLE_PS%" echo   $listed = @($c.plugins ^| ForEach-Object { if ($_ -is [string]) { $_ } else { $_.package } });
>>"%CS_ENABLE_PS%" echo   if ($listed -contains $spec) { Write-Output ('SKIP ' + $spec); continue };
>>"%CS_ENABLE_PS%" echo   $c.plugins = @($c.plugins) + $spec;
>>"%CS_ENABLE_PS%" echo   $added += $spec;
>>"%CS_ENABLE_PS%" echo   Write-Output ('ADDED ' + $spec);
>>"%CS_ENABLE_PS%" echo }
>>"%CS_ENABLE_PS%" echo if ($added.Count -gt 0) {
>>"%CS_ENABLE_PS%" echo   $enc = New-Object System.Text.UTF8Encoding($false);
>>"%CS_ENABLE_PS%" echo   [System.IO.File]::WriteAllText($p, ($c ^| ConvertTo-Json -Depth 20), $enc);
>>"%CS_ENABLE_PS%" echo }
powershell -NoProfile -ExecutionPolicy Bypass -File "%CS_ENABLE_PS%"
if errorlevel 1 (
    echo   [WARN] could not enable the TUI plugins in cli.json
    set "EXITCODE=1"
)
exit /b 0

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
powershell -NoProfile -Command "$spec='%PSPEC%'; $dir='%OC_DIR%'; $files=@((Join-Path $dir 'opencode.json'),(Join-Path $dir 'opencode.jsonc')); foreach($f in $files){ if((Test-Path -LiteralPath $f) -and ((Get-Content -LiteralPath $f -Raw) -match [regex]::Escape($spec))){ Write-Output 'SKIP'; exit 0 } }; $p=Join-Path $dir 'opencode.json'; if(Test-Path -LiteralPath $p){ try { $raw=Get-Content -LiteralPath $p -Raw; $c=$raw | ConvertFrom-Json } catch { $c=[pscustomobject]@{ '$schema'='https://opencode.ai/config.json' } } } else { $c=[pscustomobject]@{ '$schema'='https://opencode.ai/config.json' } }; if(-not $c.PSObject.Properties['plugins']){ $c | Add-Member -NotePropertyName plugins -NotePropertyValue @() -Force }; $list=@($c.plugins); if($list -notcontains $spec){ $list += $spec }; $c.plugins=$list; $enc=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($p,($c | ConvertTo-Json -Depth 20),$enc); Write-Output 'ADDED'"
if errorlevel 1 (
    echo   [WARN] could not register plugin %PSPEC% in opencode.json
    set "EXITCODE=1"
    exit /b 1
)
echo   [OK] plugin added to opencode.json: %PSPEC%
exit /b 0

rem ============================================================
rem :plugin_add_disabled  "spec"
rem   Install a plugin, then record it as "-spec" so the server skips it.
rem   The "-" form still names the package, which keeps the install and the
rem   descriptor in place for a future V2 release.
rem ============================================================
:plugin_add_disabled
call :plugin_add "%~1"
set "PDS_STATUS=!errorlevel!"
call :plugin_disable "%~1"
if "!PDS_STATUS!"=="0" exit /b 0
exit /b 1

rem ============================================================
rem :plugin_disable  "spec"
rem   Turn "spec" into the disabled "-spec" entry in opencode.json.
rem   The PowerShell body lives in a file: a "-Command" string reaches
rem   PowerShell with quotes eaten by cmd, which breaks the syntax.
rem ============================================================
:plugin_disable
set "DSPEC=%~1"
set "DPS_FILE=%WORK%\plugin-disable.ps1"
> "%DPS_FILE%" echo param([string]$Target)
>>"%DPS_FILE%" echo $ErrorActionPreference = 'Stop'
>>"%DPS_FILE%" echo $spec = '-' + $Target
>>"%DPS_FILE%" echo $p = Join-Path '%OC_DIR%' 'opencode.json'
>>"%DPS_FILE%" echo if (-not (Test-Path -LiteralPath $p)) { Write-Output 'ABSENT'; exit 0 }
>>"%DPS_FILE%" echo $c = Get-Content -LiteralPath $p -Raw ^| ConvertFrom-Json
>>"%DPS_FILE%" echo $entries = @($c.plugins)
>>"%DPS_FILE%" echo $keep = @($entries ^| Where-Object { $n = if ($_ -is [string]) { $_ } else { $_.package }; $n -ne $Target -and $n -ne $spec })
>>"%DPS_FILE%" echo $names = @($keep ^| ForEach-Object { if ($_ -is [string]) { $_ } else { $_.package } })
>>"%DPS_FILE%" echo if ($names -contains $spec) { Write-Output 'SKIP'; exit 0 }
>>"%DPS_FILE%" echo $c.plugins = @($keep) + $spec
>>"%DPS_FILE%" echo $enc = New-Object System.Text.UTF8Encoding($false)
>>"%DPS_FILE%" echo [System.IO.File]::WriteAllText($p, ($c ^| ConvertTo-Json -Depth 32), $enc)
>>"%DPS_FILE%" echo Write-Output 'DISABLED'
set "DPS_OUT="
for /f "usebackq delims=" %%a in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%DPS_FILE%" -Target "%DSPEC%" 2^>nul`) do set "DPS_OUT=%%a"
if not defined DPS_OUT (
    echo   [WARN] could not mark %DSPEC% as disabled in opencode.json
    set "EXITCODE=1"
    exit /b 0
)
echo   [OK] %DSPEC%: !DPS_OUT!
exit /b 0

rem ============================================================
rem :ensure_superpowers_plugin
rem   Ensures the local superpowers path is registered in a
rem   global config file. The CLI cannot register local paths, so
rem   opencode.json is edited only if neither config has it yet.
rem ============================================================
:ensure_superpowers_plugin
powershell -NoProfile -Command "$spec='~/.config/opencode/node_modules/superpowers'; $dir='%OC_DIR%'; $p=Join-Path $dir 'opencode.json'; $files=@($p,(Join-Path $dir 'opencode.jsonc')); $found=$false; foreach($f in $files){ if((Test-Path -LiteralPath $f) -and ((Get-Content -LiteralPath $f -Raw) -match [regex]::Escape($spec))){ $found=$true } }; if($found){ Write-Output 'SKIP'; exit 0 }; if(Test-Path -LiteralPath $p){ $c=Get-Content -LiteralPath $p -Raw | ConvertFrom-Json } else { $c=[pscustomobject]@{ '$schema'='https://opencode.ai/config.json' } }; if(-not $c.PSObject.Properties['plugins']){ $c | Add-Member -NotePropertyName plugins -NotePropertyValue @() -Force }; $list=@($c.plugins); if($list -notcontains $spec){ $list += $spec }; $c.plugins=$list; $enc=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($p,($c | ConvertTo-Json -Depth 20),$enc); Write-Output 'ADDED'"
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
