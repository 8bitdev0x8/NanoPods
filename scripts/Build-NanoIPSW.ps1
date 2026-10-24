param(
    [Parameter(Mandatory=$true)][string]$OriginalIPSW,
    [Parameter(Mandatory=$true)][string]$PatchedMSE,
    [Parameter(Mandatory=$true)][string]$OutputIPSW
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path -LiteralPath $OutputIPSW) { throw 'Output already exists; nothing overwritten.' }
if ((Get-FileHash -LiteralPath $OriginalIPSW -Algorithm SHA1).Hash -ne 'FC6D4346E8A0FAFE700833CCD4E26B956D8FBFD5') {
    throw 'Original IPSW checksum mismatch.'
}
if (!(Test-Path -LiteralPath $PatchedMSE -PathType Leaf)) { throw 'Patched MSE not found.' }
function Get-EntryHash($archive, $name) {
    $entry = $archive.GetEntry($name)
    if (!$entry) { throw "Missing archive entry: $name" }
    $stream = $entry.Open()
    $sha = [Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $stream.Dispose(); $sha.Dispose() }
}
Copy-Item -LiteralPath $OriginalIPSW -Destination $OutputIPSW
$zip = [IO.Compression.ZipFile]::Open($OutputIPSW, [IO.Compression.ZipArchiveMode]::Update)
try {
    $zip.GetEntry('Firmware.MSE').Delete()
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $PatchedMSE, 'Firmware.MSE', [IO.Compression.CompressionLevel]::Optimal) | Out-Null
} finally { $zip.Dispose() }
$original = [IO.Compression.ZipFile]::OpenRead($OriginalIPSW)
$output = [IO.Compression.ZipFile]::OpenRead($OutputIPSW)
try {
    foreach ($name in @('manifest.plist', 'N31.bootloader.rb3')) {
        if ((Get-EntryHash $original $name) -ne (Get-EntryHash $output $name)) { throw "Preservation check failed: $name" }
    }
    if ((Get-EntryHash $output 'Firmware.MSE') -ne (Get-FileHash -LiteralPath $PatchedMSE -Algorithm SHA256).Hash) {
        throw 'Packaged firmware does not match input.'
    }
} finally { $original.Dispose(); $output.Dispose() }
Write-Host "Created and verified: $OutputIPSW"
Write-Host 'No iPod firmware was written by this script.'
Get-FileHash -LiteralPath $OutputIPSW -Algorithm SHA256
