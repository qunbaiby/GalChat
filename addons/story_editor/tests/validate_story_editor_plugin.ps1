$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

$godot = "d:\godot\Godot_v4.6.3-stable_mono_win64_console.exe"
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$output = & $godot --path $projectPath --editor --headless --quit --language en 2>&1
$exitCode = $LASTEXITCODE
$textOutput = $output | ForEach-Object { $_.ToString() }

if ($exitCode -ne 0) {
	$textOutput | ForEach-Object { Write-Host $_ }
	Write-Error "Godot editor validation failed with exit code $exitCode."
	exit $exitCode
}

$pluginErrors = $textOutput | Where-Object {
	$_ -match "SCRIPT ERROR.*story_editor" -or
	$_ -match "Failed to load script.*addons/story_editor" -or
	$_ -match "Parse Error.*addons/story_editor" -or
	$_ -match "ERROR:.*addons/story_editor"
}

if ($pluginErrors) {
	$pluginErrors | ForEach-Object { Write-Host $_ }
	Write-Error "Story editor plugin errors detected."
	exit 1
}

Write-Host "STORY_EDITOR_PLUGIN_OK"
$warningCount = @($textOutput | Where-Object { $_ -match "^WARNING:" }).Count
if ($warningCount -gt 0) {
	Write-Host "Ignored $warningCount unrelated project warnings."
}
exit 0