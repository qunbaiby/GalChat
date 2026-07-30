param(
	[Parameter(Mandatory = $true)]
	[string]$Script,
	[Parameter(Mandatory = $true)]
	[string]$SuccessMarker,
	[int]$TimeoutSeconds = 90
)

$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

$godot = "d:\godot\Godot_v4.6.3-stable_mono_win64_console.exe"
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$originalAppData = $env:APPDATA
$testAppData = Join-Path ([System.IO.Path]::GetTempPath()) ("galchat-story-smoke-" + [guid]::NewGuid().ToString("N"))
$output = @()
$exitCode = 1
$timedOut = $false
$failedFast = $false
$process = $null
try {
	New-Item -ItemType Directory -Path $testAppData -Force | Out-Null
	$env:APPDATA = $testAppData
	$stdoutPath = Join-Path $testAppData "godot-stdout.log"
	$stderrPath = Join-Path $testAppData "godot-stderr.log"
	if ($Script.EndsWith(".tscn", [System.StringComparison]::OrdinalIgnoreCase)) {
		$arguments = @("--path", "`"$projectPath`"", "--headless", "--language", "en", "--scene", $Script)
	} else {
		$arguments = @("--path", "`"$projectPath`"", "--headless", "--language", "en", "--script", $Script)
	}
	$process = Start-Process -FilePath $godot -ArgumentList $arguments -NoNewWindow -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
	$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
	while (-not $process.WaitForExit(250)) {
		$liveOutput = @()
		if (Test-Path -LiteralPath $stdoutPath) {
			$liveOutput += Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue
		}
		if (Test-Path -LiteralPath $stderrPath) {
			$liveOutput += Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue
		}
		$liveText = $liveOutput -join "`n"
		if ($liveText -match "SCRIPT ERROR|Failed to load script|Parse Error") {
			$failedFast = $true
			& taskkill.exe /PID $process.Id /T /F 2>$null | Out-Null
			$process.WaitForExit()
			$exitCode = 1
			break
		}
		if ([DateTime]::UtcNow -ge $deadline) {
			$timedOut = $true
			& taskkill.exe /PID $process.Id /T /F 2>$null | Out-Null
			$process.WaitForExit()
			$exitCode = 124
			break
		}
	}
	if (-not $failedFast -and -not $timedOut) {
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
$storyErrors = $textOutput | Where-Object {
	$_ -match "SCRIPT ERROR" -or
	$_ -match "ERROR: STORY_" -or
	$_ -match "Failed to load script.*story_editor" -or
	$_ -match "Parse Error.*story_editor"
}
$markerFound = [bool]($textOutput | Where-Object { $_ -match [regex]::Escape($SuccessMarker) })

if ($exitCode -ne 0 -or $storyErrors -or -not $markerFound) {
	$textOutput | ForEach-Object { Write-Host $_ }
	if ($timedOut) {
		Write-Error "Godot smoke timed out after $TimeoutSeconds seconds: $Script"
	}
	if ($failedFast) {
		Write-Error "Godot smoke stopped immediately after a script error: $Script"
	}
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