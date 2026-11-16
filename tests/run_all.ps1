# Runs every headless test. PowerShell 7, from the project folder:   pwsh tests/run_all.ps1
# Set $env:GODOT to the Godot 4.7.2 console executable if it is not the default below.
$godot = if ($env:GODOT) { $env:GODOT } else { Join-Path $PSScriptRoot "..\..\..\Godot_v4.7.2-stable_win64_console.exe" }
$project = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
& $godot --headless --path $project --import *> $null
$failed = 0
foreach ($test in "test_models", "test_loc", "test_ui") {
	$lines = & $godot --headless --path $project --script "tests/$test.gd" 2>&1 | ForEach-Object { "$_" }
	$lines | Where-Object { $_ -match "FAIL|PASS|SCRIPT ERROR|Parse Error" }
	if (-not ($lines -match "-> PASS")) { $failed++ }
}
if ($failed -eq 0) { "ALL HEADLESS TESTS PASSED" } else { "$failed TEST FILE(S) FAILED" }
exit $failed
