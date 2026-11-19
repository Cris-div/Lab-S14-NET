param([switch]$Https)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
if (-not $env:ConnectionStrings__Veterinaria) {
    if (-not (Test-Path '.local/connection.txt')) {
        throw 'Configura ConnectionStrings__Veterinaria o guarda la conexión en .local/connection.txt (excluido de Git).'
    }
    $env:ConnectionStrings__Veterinaria = (Get-Content '.local/connection.txt' -Raw).Trim()
}
if (-not $env:Jwt__Clave) {
    $env:Jwt__Clave = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48))
}
$profile = if ($Https) { 'https' } else { 'http' }
dotnet run --project Veterinaria.Api --launch-profile $profile
if ($LASTEXITCODE -ne 0) { throw 'No se pudo iniciar la API. Revisa la salida de dotnet y las directivas del equipo.' }
