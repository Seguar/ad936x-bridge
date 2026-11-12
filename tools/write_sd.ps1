# Write a raw SD-card image (e.g. ADI Kuiper) to a USB SD-card reader on Windows. Run as Administrator.
# Safety: refuses any disk that is not USB, is a boot/system disk, is outside 28-34 GB, or whose name does not match -Model.
# The first 4 MB (partition table) is written last, so Windows cannot mount partitions in the middle of the write.
# usage: powershell -ExecutionPolicy Bypass -File write_sd.ps1 -Image <file.img> -DiskNumber <n> [-Model 'MXT-USB']
#        (find the disk number with Get-Disk; the log goes next to the script)
param(
  [Parameter(Mandatory = $true)][string]$Image,
  [Parameter(Mandatory = $true)][int]$DiskNumber,
  [string]$Model = 'MXT-USB',
  [string]$Log = "$PSScriptRoot\write_sd.log"
)
$ErrorActionPreference = 'Stop'
function L($m) { $line = "$(Get-Date -Format HH:mm:ss) $m"; Add-Content -Path $Log -Value $line -Encoding ascii; Write-Host $line }

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class RawDisk {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern SafeFileHandle CreateFile(string name, uint access, uint share, IntPtr sec, uint disp, uint flags, IntPtr tmpl);
    public static FileStream Open(string path) {
        // GENERIC_READ|GENERIC_WRITE, FILE_SHARE_READ|FILE_SHARE_WRITE, OPEN_EXISTING, FILE_FLAG_WRITE_THROUGH
        SafeFileHandle h = CreateFile(path, 0xC0000000, 3, IntPtr.Zero, 3, 0x80000000, IntPtr.Zero);
        if (h.IsInvalid) throw new IOException("CreateFile failed, Win32 error " + Marshal.GetLastWin32Error());
        return new FileStream(h, FileAccess.ReadWrite, 4096, false);
    }
}
'@

try {
  Remove-Item $Log -ErrorAction SilentlyContinue
  $d = Get-Disk -Number $DiskNumber
  L "disk $($d.Number): $($d.FriendlyName) bus=$($d.BusType) size=$($d.Size) boot=$($d.IsBoot) system=$($d.IsSystem) style=$($d.PartitionStyle)"
  if ($d.BusType -ne 'USB' -or $d.IsBoot -or $d.IsSystem -or $d.Size -lt 28GB -or $d.Size -gt 34GB -or $d.FriendlyName -notmatch $Model) {
    throw 'Safety check failed: disk is not the expected 32 GB USB SD card. Nothing written.'
  }
  $img = Get-Item $Image
  if ($img.Length -gt $d.Size) { throw 'Image larger than card' }
  L "image $($img.FullName) $($img.Length) bytes"
  if ($d.PartitionStyle -ne 'RAW') {
    Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -Confirm:$false
    L 'card wiped'
  } else { L 'card already blank (RAW)' }
  Start-Sleep 2
  $bs = 4MB
  $src = [IO.File]::OpenRead($img.FullName)
  $dst = [RawDisk]::Open("\\.\PhysicalDrive$DiskNumber")
  # keep the first block (MBR + partition table) for last, so Windows sees no partitions while we write
  $head = New-Object byte[] $bs; $hn = $src.Read($head, 0, $bs)
  [void]$dst.Seek($bs, [IO.SeekOrigin]::Begin)
  L 'writing from offset 4 MB, partition table last'
  $buf = New-Object byte[] $bs; $done = [long]$hn; $t0 = Get-Date; $next = 0
  while (($n = $src.Read($buf, 0, $bs)) -gt 0) {
    if ($n % 512) { $pad = 512 - ($n % 512); [Array]::Clear($buf, $n, $pad); $n += $pad }
    $dst.Write($buf, 0, $n); $done += $n
    $pct = [int][Math]::Floor(100 * $done / $img.Length)
    if ($pct -ge $next) { $mbs = $done / 1MB / [Math]::Max(0.1, ((Get-Date) - $t0).TotalSeconds); L ("written {0}% ({1:N0} MB, {2:N1} MB/s)" -f $pct, ($done / 1MB), $mbs); $next += 5 }
  }
  [void]$dst.Seek(0, [IO.SeekOrigin]::Begin); $dst.Write($head, 0, $hn); L 'partition table written'
  $dst.Flush(); $dst.Close(); $src.Close()
  L "DONE: wrote $done bytes in $([int]((Get-Date) - $t0).TotalSeconds) s"
  Update-HostStorageCache; L 'disk rescanned'
} catch {
  L "ERROR: $($_.Exception.Message)"
}
