$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Instala Docker Desktop e inicialo en modo contenedores Linux.'
}
docker info --format '{{.OSType}}' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Inicia Docker Desktop antes de continuar.' }
docker compose version | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Se necesita Docker Compose, incluido en Docker Desktop.' }

if (-not (Test-Path -LiteralPath '.env')) {
    $password = if ($env:MSSQL_SA_PASSWORD) { $env:MSSQL_SA_PASSWORD } else { [Guid]::NewGuid().ToString('N') + 'Aa1!' }
    $jwtSecret = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48))
    @("MSSQL_SA_PASSWORD=$password", 'API_PORT=5164', "JWT_SECRET=$jwtSecret") | Set-Content -LiteralPath '.env' -Encoding ascii
} elseif (-not (Select-String -LiteralPath '.env' -Pattern '^JWT_SECRET=.{32,}$' -Quiet)) {
    $jwtSecret = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48))
    $envLines = @(Get-Content -LiteralPath '.env')
    if ($envLines -match '^JWT_SECRET=') {
        $envLines = @($envLines | ForEach-Object { if ($_ -match '^JWT_SECRET=') { "JWT_SECRET=$jwtSecret" } else { $_ } })
    } else {
        $envLines += "JWT_SECRET=$jwtSecret"
    }
    $envLines | Set-Content -LiteralPath '.env' -Encoding ascii
}

docker compose config --quiet
if ($LASTEXITCODE -ne 0) { throw 'Revisa la configuracion de .env.' }
docker compose up -d --build
if ($LASTEXITCODE -ne 0) { throw 'No se pudieron iniciar los contenedores. Revisa docker compose logs.' }

$apiPort = 5164
if ($env:API_PORT) { $apiPort = [int]$env:API_PORT }
else {
    foreach ($line in Get-Content -LiteralPath '.env') {
        if ($line -match '^API_PORT=(\d+)$') { $apiPort = [int]$Matches[1] }
    }
}
$ready = $false
for ($attempt = 0; $attempt -lt 40; $attempt++) {
    try {
        $response = Invoke-WebRequest "http://localhost:$apiPort/openapi/v1.json" -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -eq 200) { $ready = $true; break }
    } catch { }
    Start-Sleep -Milliseconds 500
}
if (-not $ready) { throw 'La API no respondio a tiempo. Revisa docker compose logs api.' }
Write-Host "Aplicacion lista: http://localhost:$apiPort/swagger"
