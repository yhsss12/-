$ErrorActionPreference = 'Stop'
$stage = $null
try {
    if (!(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'SlayTheSpire2.exe'))) { throw 'Put this script in the game folder first.' }
    if (Get-Process SlayTheSpire2 -ErrorAction SilentlyContinue) { throw 'Exit the game before updating.' }
    $release = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'release_info.json') -Raw | ConvertFrom-Json
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $base = 'https://raw.githubusercontent.com/yhsss12/-/main'
    $stage = Join-Path ([IO.Path]::GetTempPath()) ('StayAlive-update-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage | Out-Null
    Invoke-WebRequest -UseBasicParsing -Uri ($base + '/update.json?time=' + [DateTime]::UtcNow.Ticks) -OutFile (Join-Path $stage 'update.json') -TimeoutSec 60
    $manifest = Get-Content -LiteralPath (Join-Path $stage 'update.json') -Raw | ConvertFrom-Json
    if ($manifest.version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid update version.' }
    if ($release.version -ne $manifest.game_version) { throw "This update needs game $($manifest.game_version); installed: $($release.version)." }
    $names = @('StayAlive.dll', 'StayAlive.pck')
    if (@($manifest.files).Count -ne 2) { throw 'Invalid file list.' }
    foreach ($name in $names) {
        $entry = @($manifest.files | Where-Object name -eq $name)
        if ($entry.Count -ne 1 -or $entry[0].sha256 -notmatch '^[A-Fa-f0-9]{64}$') { throw 'Invalid file hash.' }
        $file = Join-Path $stage $name
        Invoke-WebRequest -UseBasicParsing -Uri ($base + '/packages/' + $manifest.version + '/' + $name) -OutFile $file -TimeoutSec 60
        if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $entry[0].sha256) { throw "Hash check failed: $name. Nothing was installed." }
    }
    if (Get-Process SlayTheSpire2 -ErrorAction SilentlyContinue) { throw 'Game started during download. Exit it and retry.' }
    $target = Join-Path $PSScriptRoot 'mods\StayAlive'
    $backup = Join-Path $PSScriptRoot ('mod-backups\' + (Get-Date -Format yyyyMMdd_HHmmss) + '-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $backup, $target | Out-Null
    $managed = @('StayAlive.dll', 'StayAlive.pck', 'installed-version.txt')
    foreach ($name in $managed) {
        $old = Join-Path $target $name
        if (Test-Path -LiteralPath $old) { Copy-Item -LiteralPath $old -Destination $backup }
    }
    try {
        foreach ($name in $names) { Copy-Item -LiteralPath (Join-Path $stage $name) -Destination $target -Force }
        [IO.File]::WriteAllText((Join-Path $target 'installed-version.txt'), $manifest.version)
    } catch {
        foreach ($name in $managed) {
            $saved = Join-Path $backup $name
            $destination = Join-Path $target $name
            if (Test-Path -LiteralPath $saved) { Copy-Item -LiteralPath $saved -Destination $destination -Force }
            elseif (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination }
        }
        throw
    }
    Write-Host "Installed Stay Alive $($manifest.version). Update BOTH computers before multiplayer." -ForegroundColor Green
    Write-Host "Backup: $backup"
    Write-Host 'Saves and account settings were not changed. Start the game with your normal launcher.'
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
} finally {
    if ($stage -and (Test-Path -LiteralPath $stage)) { Remove-Item -LiteralPath $stage -Recurse -Force }
}
