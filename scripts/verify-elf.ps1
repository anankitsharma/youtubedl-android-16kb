param(
    [string]$SdkRoot = $Env:ANDROID_SDK_ROOT,
    [string]$Abi = "arm64-v8a"
)

if (-not $SdkRoot) {
    Write-Error "ANDROID_SDK_ROOT is not set. Set it or pass -SdkRoot."
    exit 2
}

$llvm = Join-Path $SdkRoot "ndk\27.0.12077973\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-readobj.exe"
if (-not (Test-Path $llvm)) {
    $llvm = Get-ChildItem -Recurse -Filter llvm-readobj.exe -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "ndk\\.*\\toolchains\\llvm\\prebuilt\\windows-x86_64\\bin" } |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $llvm) {
    Write-Error "llvm-readobj not found under ANDROID_SDK_ROOT. Install NDK r27+."
    exit 3
}

$roots = @(
    "ffmpeg\src\main\jniLibs\$Abi",
    "aria2c\src\main\jniLibs\$Abi",
    "library\src\main\jniLibs\$Abi"
)

$failed = $false
foreach ($root in $roots) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem $root -Filter *.so | ForEach-Object {
        $file = $_.FullName
        $out = & $llvm --program-headers $file 2>$null | Select-String -Pattern "Type: PT_LOAD|Alignment:" | ForEach-Object { $_.Line }
        $aligns = $out | Select-String -Pattern "Alignment: (\d+)" | ForEach-Object { [int]($_.Matches[0].Groups[1].Value) }
        $name = $_.Name
        if ($aligns -contains 16384) {
            Write-Output ("[OK] {0}: PT_LOAD contains Alignment=16384" -f $name)
        } else {
            Write-Output ("[FAIL] {0}: PT_LOAD Alignment(s) = {1}" -f $name, ($aligns -join ","))
            $failed = $true
        }
    }
}

if ($failed) { exit 1 } else { exit 0 }
