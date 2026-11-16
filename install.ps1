# Installs the risk-router agents into the global OpenCode config.
# Copies agents/*.md to ~/.config/opencode/agents/. Existing files with the
# same name are backed up first. Nothing else in your OpenCode config is touched.
$ErrorActionPreference = 'Stop'

$src = Join-Path $PSScriptRoot 'agents'
$dest = Join-Path $HOME '.config/opencode/agents'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

if (-not (Test-Path $src)) { throw "agents folder not found: $src" }
New-Item -ItemType Directory -Force -Path $dest | Out-Null

foreach ($file in Get-ChildItem -Path $src -Filter '*.md') {
    $target = Join-Path $dest $file.Name
    if (Test-Path $target) {
        $backup = "$target.bak-$stamp"
        Copy-Item -LiteralPath $target -Destination $backup
        Write-Host "backup  $backup"
    }
    Copy-Item -LiteralPath $file.FullName -Destination $target -Force
    Write-Host "install $target"
}

if (Get-Command opencode -ErrorAction SilentlyContinue) {
    $ids = (opencode debug agents | ConvertFrom-Json).id
    foreach ($name in 'orchestrator', 'high-class', 'low-class') {
        if ($ids -contains $name) { Write-Host "ok      agent '$name' loaded" }
        else { Write-Warning "agent '$name' not loaded; check 'opencode debug agents'" }
    }
} else {
    Write-Warning 'opencode not found on PATH; skipped load check'
}
