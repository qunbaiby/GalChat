param(
	[Parameter(Mandatory = $true)]
	[string]$Script,
	[Parameter(Mandatory = $true)]
	[string]$SuccessMarker
)

$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

$godot = "d:\godot\Godot_v4.6.3-stable_mono_win64_console.exe"
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$output = & $godot --path $projectPath --headless --language en --script $Script 2>&1
$exitCode = $LASTEXITCODE
$textOutput = $output | ForEach-Object { $_.ToString() }
$storyErrors = $textOutput | Where-Object {
	$_ -match "SCRIPT ERROR" -or
	$_ -match "ERROR: STORY_" -or
	$_ -match "Failed to load script.*story_editor" -or
	$_ -match "Parse Error.*story_editor"
}
$markerFound = [bool]($textOutput | Where-Object { $_ -match [regex]::Escape($SuccessMarker) })

if ($exitCode -ne 0 -or $storyErrors -or -not $markerFound) {
	$textOutput | ForEach-Object { Write-Host $_ }
	if (-not $markerFound) {
		Write-Error "Expected marker not found: $SuccessMarker"
	}
	exit $(if ($exitCode -ne 0) { $exitCode } else { 1 })
}

$warningCount = @($textOutput | Where-Object { $_ -match "^WARNING:" }).Count
Write-Host $SuccessMarker
if ($warningCount -gt 0) {
	Write-Host "Ignored $warningCount unrelated project warnings."
}
exit 0