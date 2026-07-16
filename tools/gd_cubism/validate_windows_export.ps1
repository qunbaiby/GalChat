param(
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..")),
    [string]$GodotPath = "",
    [string]$Preset = "Windows Desktop",
    [string]$OutputDirectory = "",
    [switch]$KeepExport
)

$ErrorActionPreference = "Stop"

function Resolve-GodotPath {
    param([string]$RequestedPath)

    if ($RequestedPath -and (Test-Path -LiteralPath $RequestedPath -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    foreach ($commandName in @("godot", "godot4")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }

    $runningGodot = Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -like "Godot*" -and $_.Path } |
        Select-Object -First 1
    if ($runningGodot) {
        return $runningGodot.Path
    }

    throw "Godot was not found. Pass -GodotPath with the Godot 4 Mono executable."
}

function Assert-FileExists {
    param(
        [string]$Path,
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description is missing: $Path"
    }
}

$projectRoot = (Resolve-Path -LiteralPath $ProjectPath).Path
$extensionRoot = Join-Path $projectRoot "addons\gd_cubism"
$extensionManifest = Join-Path $extensionRoot "gd_cubism.gdextension"
$sourceCore = Join-Path $extensionRoot "bin\Live2DCubismCore.dll"
$sourceDebug = Join-Path $extensionRoot "bin\libgd_cubism.windows.debug.x86_64.dll"
$sourceRelease = Join-Path $extensionRoot "bin\libgd_cubism.windows.release.x86_64.dll"

Assert-FileExists $extensionManifest "GDExtension manifest"
Assert-FileExists $sourceCore "Live2D Cubism Core"
Assert-FileExists $sourceDebug "GDCubism debug library"
Assert-FileExists $sourceRelease "GDCubism release library"

$manifestText = Get-Content -LiteralPath $extensionManifest -Raw
if ($manifestText -notmatch '(?ms)^\[dependencies\].*windows\.release\.x86_64\s*=\s*\{.*Live2DCubismCore\.dll') {
    throw "The manifest does not declare Live2DCubismCore.dll as a Windows release dependency."
}

$exportPresetPath = Join-Path $projectRoot "export_presets.cfg"
Assert-FileExists $exportPresetPath "Godot export presets"
$exportPresetText = Get-Content -LiteralPath $exportPresetPath -Raw
if ($exportPresetText -notmatch 'include_filter="[^"]*assets/live2d/') {
    throw "The Windows export preset does not include runtime-loaded Live2D assets."
}

$godotExecutable = Resolve-GodotPath $GodotPath
$createdTemporaryDirectory = -not $OutputDirectory
if ($createdTemporaryDirectory) {
    $OutputDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("galchat-gd-cubism-export-" + [Guid]::NewGuid().ToString("N"))
} elseif (-not [System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path $projectRoot $OutputDirectory
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$exportExecutable = Join-Path $OutputDirectory "GDCubismExportProbe.exe"

try {
    Write-Host "Exporting preset '$Preset' with $godotExecutable"
    $exportProcess = Start-Process -FilePath $godotExecutable -ArgumentList @(
        "--headless",
        "--path", ('"{0}"' -f $projectRoot),
        "--export-release", ('"{0}"' -f $Preset),
        ('"{0}"' -f $exportExecutable)
    ) -PassThru -Wait -NoNewWindow
    if ($exportProcess.ExitCode -ne 0) {
        throw "Godot export failed with exit code $($exportProcess.ExitCode)."
    }

    $exportCore = Join-Path $OutputDirectory "Live2DCubismCore.dll"
    $exportRelease = Join-Path $OutputDirectory "libgd_cubism.windows.release.x86_64.dll"
    Assert-FileExists $exportExecutable "Exported executable"
    Assert-FileExists $exportCore "Exported Live2D Cubism Core"
    Assert-FileExists $exportRelease "Exported GDCubism release library"

    if ((Get-Item -LiteralPath $exportCore).Length -ne (Get-Item -LiteralPath $sourceCore).Length) {
        throw "Exported Live2DCubismCore.dll does not match the source dependency size."
    }
    if ((Get-Item -LiteralPath $exportRelease).Length -ne (Get-Item -LiteralPath $sourceRelease).Length) {
        throw "Exported GDCubism release DLL does not match the source library size."
    }

    Write-Host "Starting exported build for a native-library smoke test."
    $runtimeStdout = Join-Path $OutputDirectory "runtime.stdout.log"
    $runtimeStderr = Join-Path $OutputDirectory "runtime.stderr.log"
    $process = Start-Process -FilePath $exportExecutable -WorkingDirectory $OutputDirectory -PassThru `
        -RedirectStandardOutput $runtimeStdout -RedirectStandardError $runtimeStderr
    try {
        if ($process.WaitForExit(8000)) {
            if ($process.ExitCode -ne 0) {
                throw "Exported build exited early with code $($process.ExitCode)."
            }
        } else {
            Stop-Process -Id $process.Id -Force
            $process.WaitForExit()
        }
    } finally {
        if (-not $process.HasExited) {
            Stop-Process -Id $process.Id -Force
        }
    }

    $runtimeLog = ""
    if (Test-Path -LiteralPath $runtimeStdout) {
        $runtimeLog += Get-Content -LiteralPath $runtimeStdout -Raw
    }
    if (Test-Path -LiteralPath $runtimeStderr) {
        $runtimeLog += Get-Content -LiteralPath $runtimeStderr -Raw
    }
    if ($runtimeLog -match 'GDCubismUserModel::.*is_initialized\(\) == false') {
        throw "The exported build loaded GDCubism but failed to initialize its Live2D model assets."
    }
    if ($runtimeLog -match 'Prompt template not found:') {
        throw "The exported build is missing runtime-loaded prompt templates."
    }

    Write-Host "GD_CUBISM_WINDOWS_EXPORT_OK"
} finally {
    if ($createdTemporaryDirectory -and -not $KeepExport -and (Test-Path -LiteralPath $OutputDirectory)) {
        Remove-Item -LiteralPath $OutputDirectory -Recurse -Force
    } elseif (Test-Path -LiteralPath $OutputDirectory) {
        Write-Host "Export retained at: $OutputDirectory"
    }
}