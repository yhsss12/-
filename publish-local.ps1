param(
    [Parameter(Mandatory=$true)][string]$GameDir,
    [Parameter(Mandatory=$true)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version
)
$ErrorActionPreference = 'Stop'
$GameDir = (Resolve-Path -LiteralPath $GameDir).Path
$output = Join-Path $PSScriptRoot ('packages\' + $Version)
if (Test-Path -LiteralPath $output) { throw 'Version already exists. Use a new version.' }
$build = Join-Path $PSScriptRoot '.build'
& dotnet build (Join-Path $PSScriptRoot 'src\StayAlive.csproj') -c Release -o $build "-p:GameDir=$GameDir"
if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }
New-Item -ItemType Directory -Path $output | Out-Null
Copy-Item -LiteralPath (Join-Path $build 'StayAlive.dll') -Destination $output
$json = @{ pck_name='StayAlive'; name='Stay Alive'; author='local'; description='Toggle minimum player HP with the on-screen button or F8.'; version=$Version } | ConvertTo-Json -Compress
$bytes = [Text.Encoding]::UTF8.GetBytes($json)
$nameBytes = [Text.Encoding]::UTF8.GetBytes('res://mod_manifest.json')
$paddedName = [byte[]]::new([int]([Math]::Ceiling($nameBytes.Length / 4.0) * 4))
[Array]::Copy($nameBytes, $paddedName, $nameBytes.Length)
$offset = [uint64]([Math]::Ceiling((100 + 4 + $paddedName.Length + 8 + 8 + 16 + 4) / 16.0) * 16)
$md5 = [Security.Cryptography.MD5]::Create()
try { $digest = $md5.ComputeHash($bytes) } finally { $md5.Dispose() }
$stream = [IO.File]::Create((Join-Path $output 'StayAlive.pck'))
$writer = [IO.BinaryWriter]::new($stream)
try {
    foreach ($value in @(0x43504447,2,4,5,1,0)) { $writer.Write([uint32]$value) }
    $writer.Write([uint64]0)
    $writer.Write([byte[]]::new(64))
    $writer.Write([uint32]1)
    $writer.Write([uint32]$paddedName.Length)
    $writer.Write($paddedName)
    $writer.Write($offset)
    $writer.Write([uint64]$bytes.Length)
    $writer.Write($digest)
    $writer.Write([uint32]0)
    while ($stream.Position -lt $offset) { $writer.Write([byte]0) }
    $writer.Write($bytes)
} finally { $writer.Dispose(); $stream.Dispose() }
$manifest = @{
    version=$Version
    game_version=(Get-Content -LiteralPath (Join-Path $GameDir 'release_info.json') -Raw | ConvertFrom-Json).version
    files=@(@('StayAlive.dll','StayAlive.pck') | ForEach-Object { @{ name=$_; sha256=(Get-FileHash -LiteralPath (Join-Path $output $_) -Algorithm SHA256).Hash } })
}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'update.json'), ($manifest | ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))
Write-Host "Prepared $Version. Review and push these files to publish the update."
