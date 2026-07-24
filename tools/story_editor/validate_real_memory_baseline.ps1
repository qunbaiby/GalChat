param(
	[string]$Dataset = ""
)

$ErrorActionPreference = "Continue"
$godot = "d:\godot\Godot_v4.6.3-stable_mono_win64_console.exe"
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$arguments = @(
	"--path", $projectPath,
	"--headless",
	"--scene", "res://tools/story_editor/validate_real_memory_baseline.tscn"
)
if (-not [string]::IsNullOrWhiteSpace($Dataset)) {
	$arguments += @("--", "--dataset", $Dataset)
}

$output = & $godot @arguments 2>&1
$textOutput = $output | ForEach-Object { $_.ToString() }
$textOutput | ForEach-Object { Write-Host $_ }

if ($textOutput | Where-Object { $_ -match "REAL_MEMORY_BASELINE_OK" }) {
	exit 0
}
if ($textOutput | Where-Object { $_ -match "REAL_MEMORY_BASELINE_NOT_READY" }) {
	exit 2
}
if ($textOutput | Where-Object { $_ -match "REAL_MEMORY_BASELINE_FAILED" }) {
	exit 1
}
Write-Error "Real memory baseline validator returned no recognized result marker."
exit 1