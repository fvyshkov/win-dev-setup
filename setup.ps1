<#
    setup-dev-environment.ps1

    Sets up a developer machine on Windows:
        VS Code, Git, Python 3.12, Node.js LTS, Claude Code

    Also configures:
        - VS Code hotkey Ctrl+Alt+T  -> open a terminal as an editor tab
        - command  cc  -> claude --dangerously-skip-permissions
        - command  cc  (Cyrillic letters) -> the same, for the Russian layout

    Run it by double-clicking setup-dev-environment.bat

    This file is deliberately ASCII-only. A .ps1 that contains non-ASCII text
    and is saved without a BOM gets mis-decoded by Windows PowerShell 5.1 and
    fails to parse, so keep it that way.
#>

[CmdletBinding()]
param(
    [switch]$NoInstall,   # configure only, install nothing
    [switch]$Safe         # cc without --dangerously-skip-permissions
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

$BUILD = 'build 2026-08-30'

# ------------------------------------------------------------- output ---

function Line { Write-Host ('  ' + ('-' * 60)) -ForegroundColor DarkGray }

function Step([int]$n, [string]$title) {
    Write-Host ''
    Write-Host ("  [$n/7] $title") -ForegroundColor Cyan
}
function Say([string]$t)  { Write-Host ('        ' + $t) }
function Ok([string]$t)   { Write-Host ('        + ' + $t) -ForegroundColor Green }
function Skip([string]$t) { Write-Host ('        = ' + $t) -ForegroundColor DarkYellow }
function Bad([string]$t)  { Write-Host ('        ! ' + $t) -ForegroundColor Red }

# ------------------------------------------------------------ helpers ---

# Re-read PATH from the registry: a program installed a second ago is not
# visible in this window otherwise.
function Sync-Path {
    $m = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $u = [Environment]::GetEnvironmentVariable('Path', 'User')
    $extra = Join-Path $env:USERPROFILE '.local\bin'
    $env:Path = (@($m, $u, $extra) | Where-Object { $_ }) -join ';'
}

function Have([string]$name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

# "python" may resolve to the Microsoft Store stub, which is not a real Python.
function Have-Python {
    $c = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($c -and $c.Source -notlike '*\WindowsApps\*') { return $true }
    return [bool](Get-Command py.exe -ErrorAction SilentlyContinue)
}

function Install-Pkg([string]$id, [string]$label, [string]$why, [scriptblock]$probe) {
    Sync-Path
    if (& $probe) { Skip ($label + ' is already installed, skipping'); return $true }
    if ($NoInstall) { Skip ('install skipped: ' + $label); return $false }

    Say $why
    Say 'Downloading and installing, this takes 1-3 minutes ...'
    & winget install -e --id $id --accept-source-agreements --accept-package-agreements | Out-Host
    Sync-Path
    if (& $probe) { Ok ($label + ' installed'); return $true }

    Say 'Retrying as a per-user install ...'
    & winget install -e --id $id --scope user --accept-source-agreements --accept-package-agreements | Out-Host
    Sync-Path
    if (& $probe) { Ok ($label + ' installed'); return $true }

    Bad ($label + ' could not be installed. Continuing - the rest is unaffected.')
    return $false
}

# Append a folder to the user PATH. The value is read raw, without expanding
# variables, so that %USERPROFILE% is not baked into the text.
function Add-UserPath([string]$dir) {
    $key     = Get-Item -Path 'HKCU:\Environment'
    $current = $key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
    $parts   = @()
    if ($current) { $parts = @($current -split ';' | Where-Object { $_ -ne '' }) }

    if ($parts -contains $dir) {
        Skip 'folder is already on PATH'
    } else {
        Set-ItemProperty -Path 'HKCU:\Environment' -Name 'Path' -Value ((($parts + $dir) -join ';')) -Type ExpandString
        Ok 'the command now works from any folder'
    }
    if (($env:Path -split ';') -notcontains $dir) { $env:Path = $env:Path + ';' + $dir }
}

# ------------------------------------------------------------ splash ---

Write-Host ''
Line
Write-Host '   Developer environment setup' -ForegroundColor White
Write-Host ("   $BUILD") -ForegroundColor DarkGray
Line
Write-Host ''
Write-Host '   Here is what is about to happen:'
Write-Host ''
Write-Host '     - check that the system is ready'
Write-Host '     - install the VS Code editor'
Write-Host '     - install Git, Python and Node.js'
Write-Host '     - install Claude Code'
Write-Host '     - set up a hotkey and the short command  cc'
Write-Host ''
Write-Host '   Takes 5-15 minutes, mostly downloading.'
Write-Host '   Windows will ask for permission a few times - answer Yes.'
Write-Host '   Nothing else to click. Leave the window alone until it says Done.'
Write-Host ''
Line

# --------------------------------------------------------- 1. checks ---

Step 1 'Checking the system'

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Bad 'PowerShell 5 or newer is required. Update Windows.'
    exit 1
}
Ok ('PowerShell ' + $PSVersionTable.PSVersion.ToString() + ' - fine')

if (-not (Have 'winget')) {
    Bad 'winget not found - it is the built-in Microsoft package installer.'
    Write-Host ''
    Say 'It ships with Windows 11 and recent Windows 10 builds.'
    Say 'How to fix: install the free "App Installer" from the Microsoft'
    Say 'Store, then run this file again:'
    Say 'https://apps.microsoft.com/detail/9nblggh4nns1'
    Write-Host ''
    exit 1
}
Ok 'winget is present - programs will be installed through it'

# ---------------------------------------------------- 2..6 installing ---

Step 2 'VS Code editor'
$hasCode = Install-Pkg 'Microsoft.VisualStudioCode' 'VS Code' `
    'This is the program you write code in.' { Have 'code' }

Step 3 'Git'
Install-Pkg 'Git.Git' 'Git' `
    'Keeps a history of every change so you can always roll back.' { Have 'git' } | Out-Null

Step 4 'Python 3.12'
Install-Pkg 'Python.Python.3.12' 'Python' `
    'The programming language your code will run on.' { Have-Python } | Out-Null

Step 5 'Node.js'
Install-Pkg 'OpenJS.NodeJS.LTS' 'Node.js' `
    'Required by most web tooling.' { Have 'node' } | Out-Null

Step 6 'Claude Code'
Sync-Path
if (Have 'claude') {
    Skip 'Claude Code is already installed, skipping'
} elseif ($NoInstall) {
    Skip 'install skipped: Claude Code'
} else {
    Say 'An AI assistant that writes code right in the terminal.'
    Say 'Downloading from anthropic ...'
    try {
        Invoke-Expression (Invoke-RestMethod -Uri 'https://claude.ai/install.ps1')
        Sync-Path
        if (Have 'claude') { Ok 'Claude Code installed' }
        else { Skip 'installed, but it will only appear in a NEW terminal window' }
    } catch {
        Bad ('Claude Code install failed: ' + $_.Exception.Message)
        Say 'Check your internet connection and run this file again.'
    }
}

# -------------------------------------------------------- 7. settings ---

Step 7 'Setting up conveniences'

# --- the cc command ---

$shimDir = Join-Path $env:LOCALAPPDATA 'Programs\dev-shims'
if (-not (Test-Path $shimDir)) { New-Item -Path $shimDir -ItemType Directory -Force | Out-Null }

if ($Safe) { $ccFlags = '' } else { $ccFlags = ' --dangerously-skip-permissions' }

$shimBody = @(
    '@echo off',
    'setlocal',
    'set "CLAUDE_EXE=%USERPROFILE%\.local\bin\claude.exe"',
    'if exist "%CLAUDE_EXE%" (',
    '    "%CLAUDE_EXE%"' + $ccFlags + ' %*',
    ') else (',
    '    claude' + $ccFlags + ' %*',
    ')'
) -join "`r`n"

# Latin cc and Cyrillic cc (U+0441 twice) so it works in either layout.
$ruName = ([string]([char]0x0441) + [string]([char]0x0441) + '.cmd')
foreach ($n in @('cc.cmd', $ruName)) {
    Set-Content -Path (Join-Path $shimDir $n) -Value $shimBody -Encoding Ascii -Force
}
Ok 'created the command  cc  (also in the Russian keyboard layout)'
Add-UserPath $shimDir

if ($Safe) {
    Say 'cc runs Claude Code asking permission for every action.'
} else {
    Say 'cc runs Claude Code WITHOUT confirmations - fast, but it can'
    Say 'change files and run commands without asking first.'
}

# --- VS Code hotkey ---

$userDir = Join-Path $env:APPDATA 'Code\User'
$kbPath  = Join-Path $userDir 'keybindings.json'
$cmdName = 'workbench.action.createTerminalEditor'

if (-not (Test-Path $userDir)) { New-Item -Path $userDir -ItemType Directory -Force | Out-Null }

# VS Code writes JSON with comments; the built-in parser chokes on those.
function Strip-Jsonc([string]$text) {
    $noBlock = [regex]::Replace($text, '/\*[\s\S]*?\*/', '')
    $lines = $noBlock -split "`r?`n" | Where-Object { $_.TrimStart() -notmatch '^//' }
    return ($lines -join "`n")
}

$bindings = @()
$parsed   = $true

if (Test-Path $kbPath) {
    $clean = Strip-Jsonc (Get-Content $kbPath -Raw -Encoding UTF8)
    if ($clean.Trim() -ne '') {
        try {
            $obj = $clean | ConvertFrom-Json
            if ($null -ne $obj) { $bindings = @($obj) }
        } catch { $parsed = $false }
    }
}

if (-not $parsed) {
    Copy-Item $kbPath ($kbPath + '.bak') -Force
    Bad 'Could not parse your keybindings.json - saved a copy as .bak'
    Say 'Add the hotkey by hand in VS Code: press Ctrl+K then Ctrl+S'
} elseif ($bindings | Where-Object { $_.command -eq $cmdName }) {
    Skip 'hotkey is already configured'
} else {
    $bindings += [PSCustomObject]@{ key = 'ctrl+alt+t'; command = $cmdName }
    $json = ConvertTo-Json -InputObject @($bindings) -Depth 6
    if (-not $json.TrimStart().StartsWith('[')) { $json = "[`r`n" + $json + "`r`n]" }
    Set-Content -Path $kbPath -Value $json -Encoding UTF8 -Force
    Ok 'Ctrl+Alt+T in VS Code - a terminal as a tab inside the editor'
}

# --- VS Code extensions ---

if ($hasCode -and -not $NoInstall) {
    Say ''
    Say 'Installing editor add-ons (Python support and Claude Code).'
    Say 'About 60 MB, so 1-3 minutes - the pause is normal, not a freeze.'
    foreach ($ext in @('ms-python.python', 'ms-python.vscode-pylance', 'anthropic.claude-code')) {
        Write-Host ('        ... ' + $ext) -NoNewline
        try {
            $out = (& code --install-extension $ext --force 2>&1) -join ' '
            if ($LASTEXITCODE -eq 0 -or $out -match 'already installed|successfully installed') {
                Write-Host '  done' -ForegroundColor Green
            } else {
                Write-Host '  failed' -ForegroundColor Red
            }
        } catch {
            Write-Host '  failed' -ForegroundColor Red
        }
    }
    Say 'If some failed, no problem - add them later inside VS Code.'
}

# ------------------------------------------------------------ summary ---

Write-Host ''
Line
Write-Host '   Done. Installed on this machine:' -ForegroundColor White
Write-Host ''

function Show-Version([string]$exe, [string[]]$vargs, [string]$label) {
    Sync-Path
    if (Have $exe) {
        try   { $v = (& $exe @vargs 2>&1 | Select-Object -First 1) } catch { $v = '' }
        Write-Host ('     {0,-14} {1}' -f $label, $v) -ForegroundColor Green
    } else {
        Write-Host ('     {0,-14} not found - open a NEW terminal window' -f $label) -ForegroundColor Red
    }
}

Show-Version 'code'   @('--version') 'VS Code'
Show-Version 'git'    @('--version') 'Git'
Show-Version 'python' @('--version') 'Python'
Show-Version 'node'   @('--version') 'Node.js'
Show-Version 'claude' @('--version') 'Claude Code'

Write-Host ''
Line
Write-Host '   What to do next' -ForegroundColor White
Write-Host ''
Write-Host '     1. Close this window.'
Write-Host '     2. Open a NEW terminal window - the new commands are not'
Write-Host '        visible in old ones. Start menu, type:  terminal'
Write-Host '     3. Open your project folder with:  code .'
Write-Host '     4. In the editor press Ctrl+Alt+T to get a terminal.'
Write-Host '     5. Type:  cc'
Write-Host ''
Write-Host '   On first launch Claude Code will ask you to sign in to your'
Write-Host '   Anthropic account. A paid Claude Pro or Max plan is required.'
Write-Host ''
Line
Write-Host ''
