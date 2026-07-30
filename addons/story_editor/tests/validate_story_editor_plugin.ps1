param([int]$TimeoutSeconds = 120)

$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

$godot = "d:\godot\Godot_v4.6.3-stable_mono_win64_console.exe"
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$originalAppData = $env:APPDATA
$testAppData = Join-Path ([System.IO.Path]::GetTempPath()) ("galchat-story-plugin-" + [guid]::NewGuid().ToString("N"))
$output = @()
$exitCode = 1
$timedOut = $false
$process = $null
try {
	New-Item -ItemType Directory -Path $testAppData -Force | Out-Null
	$env:APPDATA = $testAppData
	$stdoutPath = Join-Path $testAppData "godot-stdout.log"
	$stderrPath = Join-Path $testAppData "godot-stderr.log"
	$arguments = @("--path", "`"$projectPath`"", "--editor", "--headless", "--quit", "--language", "en")
	$process = Start-Process -FilePath $godot -ArgumentList $arguments -NoNewWindow -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
	if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
		$timedOut = $true
		& taskkill.exe /PID $process.Id /T /F 2>$null | Out-Null
		$process.WaitForExit()
		$exitCode = 124
	} else {
		$process.WaitForExit()
		$exitCode = $process.ExitCode
	}
	if (Test-Path -LiteralPath $stdoutPath) {
		$output += Get-Content -LiteralPath $stdoutPath
	}
	if (Test-Path -LiteralPath $stderrPath) {
		$output += Get-Content -LiteralPath $stderrPath
	}
} finally {
	if ($process -and -not $process.HasExited) {
		& taskkill.exe /PID $process.Id /T /F 2>$null | Out-Null
	}
	$env:APPDATA = $originalAppData
	if (Test-Path -LiteralPath $testAppData) {
		Remove-Item -LiteralPath $testAppData -Recurse -Force -ErrorAction SilentlyContinue
	}
}
$textOutput = $output | ForEach-Object { $_.ToString() }

if ($exitCode -ne 0) {
	$textOutput | ForEach-Object { Write-Host $_ }
	if ($timedOut) {
		Write-Error "Godot editor validation timed out after $TimeoutSeconds seconds."
	}
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