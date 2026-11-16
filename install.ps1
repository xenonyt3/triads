param([switch]$Uninstall)

# Isolate preferences from an Invoke-Expression caller.
& {
    param($ScriptDir, $FileRun, $Remove)
    $ErrorActionPreference = 'Stop'
    $WarningPreference = 'Continue'
    $PSNativeCommandUseErrorActionPreference = $false
    $tempDir = $null
    $failure = $null
    $names = @('helios', 'gaia', 'selene')
    try {
        $config = if ($env:OPENCODE_CONFIG_DIR) { $env:OPENCODE_CONFIG_DIR } else { Join-Path $HOME '.config/opencode' }
        $dest = Join-Path $config 'agents'
        if ($Remove) {
            foreach ($name in $names) {
                $target = Join-Path $dest "$name.md"
                $backups = @(if (Test-Path -LiteralPath $dest) {
                    Get-ChildItem -LiteralPath $dest -File | Where-Object { $_.Name -cmatch "^$name\.md\.bak-\d{8}-\d{6}$" } | Sort-Object Name -Descending
                })
                if (Test-Path -LiteralPath $target) {
                    Remove-Item -LiteralPath $target
                    Write-Host "remove  $target"
                }
                if ($backups.Count) {
                    Move-Item -LiteralPath $backups[0].FullName -Destination $target
                    Write-Host "restore $($backups[0].FullName) -> $target"
                }
            }
            $global:LASTEXITCODE = 0
            return
        }
        $src = if ($FileRun -and $ScriptDir) { Join-Path $ScriptDir 'agents' } else { $null }
        $local = $null -ne $src
        foreach ($name in $names) {
            if (-not $src -or -not (Test-Path -LiteralPath (Join-Path $src "$name.md") -PathType Leaf)) { $local = $false }
        }
        if (-not $local) {
            $tempDir = Join-Path ([IO.Path]::GetTempPath()) ('triads-' + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $tempDir | Out-Null
            $src = $tempDir
            foreach ($name in $names) {
                try {
                    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/xenonyt3/triads/main/agents/$name.md" -OutFile (Join-Path $src "$name.md") -ErrorAction Stop
                } catch { throw "download $name.md failed: $($_.Exception.Message)" }
            }
        }
        foreach ($name in $names) {
            $reader = [IO.File]::OpenText((Join-Path $src "$name.md"))
            try { $first = $reader.ReadLine() } finally { $reader.Dispose() }
            if ($first -cne '---') { throw "invalid $name.md: first line must be exactly --- (not HTML or empty)" }
        }
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        foreach ($old in 'orchestrator.md', 'high-class.md', 'low-class.md') {
            if (Test-Path -LiteralPath (Join-Path $dest $old)) { Write-Warning "$old is from an older version; remove it manually if no longer needed" }
        }
        foreach ($name in $names) {
            $file = Join-Path $src "$name.md"
            $target = Join-Path $dest "$name.md"
            if (Test-Path -LiteralPath $target) {
                if ((Get-FileHash -LiteralPath $file).Hash -eq (Get-FileHash -LiteralPath $target).Hash) {
                    Write-Host "same    $target"
                    continue
                }
                # Do not overwrite a backup when installs share a timestamp.
                $time = Get-Date
                do {
                    $backup = "$target.bak-$($time.ToString('yyyyMMdd-HHmmss'))"
                    $time = $time.AddSeconds(1)
                } while (Test-Path -LiteralPath $backup)
                [IO.File]::Copy($target, $backup, $false)
                Write-Host "backup  $backup"
            }
            Copy-Item -LiteralPath $file -Destination $target -Force
            Write-Host "install $target"
        }
        # Diagnostics must not turn a successful install into a failure.
        try {
            if (Get-Command opencode -ErrorAction SilentlyContinue) {
                $flags = @()
                $helpText = (& opencode --help 2>&1) -join "`n"
                if ($helpText -match '--standalone') { $flags = @('--standalone') }
                try {
                    $output = & opencode @flags debug agents 2>&1
                    if ($LASTEXITCODE -ne 0) { throw 'command failed' }
                    $agents = ($output -join "`n") | ConvertFrom-Json -ErrorAction Stop
                    foreach ($name in $names) {
                        if (@($agents.id) -contains $name -or @($agents.name) -contains $name) { Write-Host "ok      agent '$name' loaded" }
                        else { Write-Warning "agent '$name' not loaded; check 'opencode debug agents'" }
                    }
                } catch { Write-Warning "agent load check failed: $($_.Exception.Message)" }
                try {
                    $models = (& opencode @flags models 2>&1) -join "`n"
                    if ($LASTEXITCODE -ne 0) { throw 'opencode models failed' }
                    foreach ($name in $names) {
                        $text = Get-Content -LiteralPath (Join-Path $dest "$name.md") -Raw
                        if ($text -match '(?m)^model:\s*([^/\s]+)/') {
                            $provider = $Matches[1]
                            if (-not $models.Contains("$provider/")) { Write-Warning "provider '$provider' not found in your OpenCode setup; see README `"Choose your models`"" }
                        } else { Write-Warning "no model provider found in $name.md" }
                    }
                } catch { Write-Warning "provider check failed: $($_.Exception.Message)" }
            } else { Write-Warning 'opencode not found on PATH; skipped checks' }
        } catch { Write-Warning "post-install checks failed: $($_.Exception.Message)" }
        Write-Host 'done'
    } catch { $failure = $_ }
    finally {
        if ($tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
    }
    if ($failure) {
        if ($FileRun) { Write-Error $failure -ErrorAction Continue; exit 1 }
        throw $failure
    }
    $global:LASTEXITCODE = 0
} $PSScriptRoot ([bool]$MyInvocation.MyCommand.Path) $Uninstall
