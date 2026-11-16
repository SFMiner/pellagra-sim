# Serves the web export next to SimKit's iframe harness and runs tests/web/web_smoke.js on it.
# PowerShell 7. From the project folder:   pwsh tests/web/run_web_smoke.ps1
# Needs: python, node, and playwright (found in the sims site's node_modules), and Chrome installed.
param(
	[string]$Export = (Join-Path $PSScriptRoot "..\..\..\sfminer.github.io\pellagra-sim"),
	[string]$Out = (Join-Path ([IO.Path]::GetTempPath()) "pellagra-web-check"),
	[int]$Port = 8837,
	[string]$NodeModules = (Join-Path $PSScriptRoot "..\..\..\..\..\Website\game-sim-server\node_modules")
)
$ErrorActionPreference = "Stop"
if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) { throw "Port $Port is already in use. Pass -Port with a free one." }
$site = Join-Path $Out "site"
Remove-Item -Recurse -Force $site -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force (Join-Path $site "game"), (Join-Path $Out "shots") | Out-Null
Copy-Item (Join-Path $Export "*") (Join-Path $site "game") -Recurse
Copy-Item (Join-Path $PSScriptRoot "..\..\addons\simkit\deploy\harness.html") $site
$server = Start-Process python -ArgumentList @("-m", "http.server", "$Port", "--bind", "127.0.0.1", "--directory", $site) -PassThru -WindowStyle Hidden
try {
	Start-Sleep -Seconds 2
	$env:PORT = "$Port"
	$env:NODE_PATH = (Resolve-Path $NodeModules).Path
	node (Join-Path $PSScriptRoot "web_smoke.js") (Join-Path $Out "shots")
	$code = $LASTEXITCODE
} finally {
	Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
}
"Screenshots: $(Join-Path $Out 'shots')"
exit $code
