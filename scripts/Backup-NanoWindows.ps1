param([Parameter(Mandatory=$true)][string]$OutputPath)
$ErrorActionPreference = 'Stop'
$candidates = @(Get-CimInstance Win32_DiskDrive | Where-Object {
    $_.Model -match 'Apple.*iPod' -and [uint64]$_.Size -gt 14000000000 -and [uint64]$_.Size -lt 18000000000
})
if ($candidates.Count -ne 1) { throw 'Expected exactly one 16 GB Apple iPod disk. No backup started.' }
$disk = $candidates[0]
$destination = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $destination) { throw 'Output already exists. Choose a new filename; nothing overwritten.' }
$partitions = @(Get-Partition -DiskNumber $disk.Index)
$outputRoot = [IO.Path]::GetPathRoot($destination).TrimEnd('\')
if ($partitions | Where-Object { $_.DriveLetter -and ($_.DriveLetter.ToString()+':') -eq $outputRoot }) {
    throw 'Backup destination is on the iPod. Choose a computer drive.'
}
$drive = New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($destination))
if ($drive.AvailableFreeSpace -lt ([int64]$disk.Size + 1073741824)) { throw 'Insufficient destination space.' }
Write-Host "Reading ONLY: $($disk.DeviceID), $($disk.Model), $($disk.Size) bytes"
Write-Host "Creating: $destination"
Write-Host 'Keep the nano connected and close iTunes/Apple Devices and other programs using the iPod.'
$inputStream = $null
$outputStream = $null
$completed = $false
try {
    $inputStream = [IO.File]::Open($disk.DeviceID, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $outputStream = [IO.File]::Open($destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    [byte[]]$buffer = New-Object byte[] 1048576
    [int64]$total = 0
    [int64]$size = $disk.Size
    while ($total -lt $size) {
        $wanted = [int][Math]::Min([int64]$buffer.Length, [int64]($size-$total))
        $read = $inputStream.Read($buffer, 0, $wanted)
        if ($read -le 0) { throw "Unexpected end of device at $total of $size bytes. Backup is incomplete." }
        $outputStream.Write($buffer, 0, $read)
        $total += $read
        Write-Progress -Activity 'Reading iPod backup' -Status "$total / $size bytes" -PercentComplete ([int](100.0*$total/$size))
    }
    $outputStream.Flush($true)
    $completed = $true
} finally {
    if ($outputStream) { $outputStream.Dispose() }
    if ($inputStream) { $inputStream.Dispose() }
    Write-Progress -Activity 'Reading iPod backup' -Completed
    if (!$completed) { Write-Warning "Backup did not complete. Any output file at $destination is partial; do not use it as a recovery image." }
}
if ((Get-Item -LiteralPath $destination).Length -ne [int64]$disk.Size) { throw 'Backup size check failed.' }
Write-Host 'Full reported device length copied. Computing SHA256...'
Get-FileHash -LiteralPath $destination -Algorithm SHA256
Write-Host 'Backup copy complete. This does not test restoration or guarantee recovery.'
