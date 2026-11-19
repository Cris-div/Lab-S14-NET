param(
    [string]$BaseUrl = 'http://127.0.0.1:5164',
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\capturas')
)

$ErrorActionPreference = 'Stop'
$client = [System.Net.Http.HttpClient]::new()
$results = [System.Collections.Generic.List[object]]::new()

function Invoke-LabRequest([string]$Method, [string]$Path, [string]$Body = '', [string]$Token = '') {
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($Method), "$BaseUrl$Path")
    $request.Headers.Accept.ParseAdd('application/json')
    if ($Token) { $request.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $Token) }
    if ($Body) { $request.Content = [System.Net.Http.StringContent]::new($Body, [System.Text.Encoding]::UTF8, 'application/json') }
    $response = $client.SendAsync($request).GetAwaiter().GetResult()
    [pscustomobject]@{
        Status = [int]$response.StatusCode
        Body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    }
}

function Add-Result([int]$Expected, [string]$Method, [string]$Path, [string]$Role, [string]$Meaning, $Response) {
    $script:results.Add([pscustomobject]@{
        Expected = $Expected; Actual = $Response.Status; Method = $Method; Path = $Path
        Role = $Role; Meaning = $Meaning; Passed = ($Response.Status -eq $Expected)
    })
}

$vetLogin = Invoke-LabRequest 'POST' '/api/auth/login' '{"correo":"veterinario@vet.local","clave":"VetS14-Admin123!"}'
Add-Result 200 'POST' '/api/auth/login' 'Veterinario' 'Inicio de sesión y emisión de token.' $vetLogin
$vetToken = ($vetLogin.Body | ConvertFrom-Json).token

$receptionLogin = Invoke-LabRequest 'POST' '/api/auth/login' '{"correo":"recepcion@vet.local","clave":"RecepS14-User123!"}'
Add-Result 200 'POST' '/api/auth/login' 'Recepcionista' 'Inicio de sesión y emisión de token.' $receptionLogin
$receptionToken = ($receptionLogin.Body | ConvertFrom-Json).token
if (-not $vetToken -or -not $receptionToken) { throw 'No se obtuvieron ambos tokens de prueba.' }

$profile = Invoke-LabRequest 'GET' '/api/auth/perfil' '' $vetToken
Add-Result 200 'GET' '/api/auth/perfil' 'Veterinario' 'El perfil devuelve correo y rol del token.' $profile
$owners = Invoke-LabRequest 'GET' '/api/propietarios' '' $receptionToken
Add-Result 200 'GET' '/api/propietarios' 'Recepcionista' 'Consulta permitida para recepción.' $owners
$pets = Invoke-LabRequest 'GET' '/api/mascotas' '' $vetToken
Add-Result 200 'GET' '/api/mascotas' 'Veterinario' 'Consulta autenticada de mascotas.' $pets

$uniqueEmail = 'prueba.s14.' + [Guid]::NewGuid().ToString('N') + '@vet.local'
$registerBody = @{ correo = $uniqueEmail; clave = 'CapturaS14-User123!' } | ConvertTo-Json -Compress
$register = Invoke-LabRequest 'POST' '/api/auth/registro' $registerBody
Add-Result 201 'POST' '/api/auth/registro' 'Público' 'Registro público; el servidor asigna Recepcionista.' $register
$duplicateEmail = Invoke-LabRequest 'POST' '/api/auth/registro' $registerBody
Add-Result 409 'POST' '/api/auth/registro' 'Público' 'Correo repetido; regla de negocio.' $duplicateEmail

$petName = 'Prueba S14 ' + (Get-Date -Format 'HHmmss')
$petBody = @{ nombre = $petName; especie = 'Gato'; edad = 2; peso = 4.25; propietarioId = 1 } | ConvertTo-Json -Compress
$petCreate = Invoke-LabRequest 'POST' '/api/mascotas' $petBody $vetToken
Add-Result 201 'POST' '/api/mascotas' 'Veterinario' 'Creación permitida para veterinaria.' $petCreate
$petId = ($petCreate.Body | ConvertFrom-Json).id
if (-not $petId) { throw 'La creación no devolvió el id de la mascota.' }

$forbidden = Invoke-LabRequest 'POST' '/api/mascotas' $petBody $receptionToken
Add-Result 403 'POST' '/api/mascotas' 'Recepcionista' 'Token válido sin el rol requerido.' $forbidden
$unauthorized = Invoke-LabRequest 'GET' '/api/mascotas'
Add-Result 401 'GET' '/api/mascotas' 'Sin token' 'Endpoint protegido sin autenticación.' $unauthorized
$badLogin = Invoke-LabRequest 'POST' '/api/auth/login' '{"correo":"no.existe@vet.local","clave":"incorrecta"}'
Add-Result 401 'POST' '/api/auth/login' 'Público' 'Credenciales inválidas.' $badLogin

$invalidOwner = Invoke-LabRequest 'POST' '/api/propietarios' '{"nombre":"","documento":"12","telefono":"x"}' $receptionToken
Add-Result 400 'POST' '/api/propietarios' 'Recepcionista' 'Validación de datos del modelo.' $invalidOwner
$missingPet = Invoke-LabRequest 'GET' '/api/mascotas/999999' '' $vetToken
Add-Result 404 'GET' '/api/mascotas/999999' 'Veterinario' 'Mascota inexistente.' $missingPet
$duplicateDocument = Invoke-LabRequest 'POST' '/api/propietarios' '{"nombre":"Documento duplicado","documento":"12345678","telefono":"900000000"}' $receptionToken
Add-Result 409 'POST' '/api/propietarios' 'Recepcionista' 'Documento repetido; regla de negocio.' $duplicateDocument

$petUpdate = Invoke-LabRequest 'PUT' "/api/mascotas/$petId" $petBody $vetToken
Add-Result 204 'PUT' "/api/mascotas/$petId" 'Veterinario' 'Actualización permitida.' $petUpdate
$petDelete = Invoke-LabRequest 'DELETE' "/api/mascotas/$petId" '' $vetToken
Add-Result 204 'DELETE' "/api/mascotas/$petId" 'Veterinario' 'Eliminación permitida.' $petDelete

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$groups = @{
    'captura-200' = @{ Title = 'Pruebas correctas · HTTP 200'; Codes = @(200) }
    'captura-201' = @{ Title = 'Creaciones correctas · HTTP 201'; Codes = @(201) }
    'captura-204' = @{ Title = 'Actualización y eliminación · HTTP 204'; Codes = @(204) }
    'captura-401-403' = @{ Title = 'Autenticación y rol · HTTP 401 y 403'; Codes = @(401,403) }
    'captura-409' = @{ Title = 'Reglas de negocio · HTTP 409'; Codes = @(409) }
    'captura-400-404' = @{ Title = 'Validación y recurso ausente · HTTP 400 y 404'; Codes = @(400,404) }
}

foreach ($key in $groups.Keys) {
    $group = $groups[$key]
    $cards = foreach ($item in $results | Where-Object { $group.Codes -contains $_.Actual }) {
        $method = [System.Net.WebUtility]::HtmlEncode($item.Method)
        $path = [System.Net.WebUtility]::HtmlEncode($item.Path)
        $role = [System.Net.WebUtility]::HtmlEncode($item.Role)
        $meaning = [System.Net.WebUtility]::HtmlEncode($item.Meaning)
        $actual = $item.Actual
        $class = if ($item.Passed) { 'ok' } else { 'bad' }
        "<article class='card'><span class='badge $class'>HTTP $actual</span><p><b>$method</b> <code>$path</code></p><p>Rol usado: <b>$role</b></p><p>$meaning</p></article>"
    }
    $html = @"
<!doctype html><html lang="es"><meta charset="utf-8"><title>$($group.Title)</title>
<style>body{font:18px Arial,sans-serif;background:#eef2f7;color:#172554;margin:0;padding:34px}.sheet{max-width:1120px;margin:auto;background:white;padding:36px 44px;border-radius:16px;box-shadow:0 8px 26px #94a3b855}h1{font-size:30px;margin:0 0 10px}.sub{color:#475569;margin:0 0 24px}.grid{display:grid;grid-template-columns:1fr 1fr;gap:16px}.card{border:1px solid #cbd5e1;border-left:7px solid #16a34a;border-radius:10px;padding:14px 18px;background:#fbfdff}.card p{margin:9px 0}.badge{display:inline-block;color:white;font-weight:bold;border-radius:999px;padding:6px 12px}.ok{background:#15803d}.bad{background:#b91c1c}code{font-size:16px;color:#0f172a}.footer{margin-top:24px;color:#64748b;font-size:13px}</style>
<body><main class="sheet"><h1>$($group.Title)</h1><p class="sub">Evidencia generada con solicitudes reales a la API local Veterinaria S14 mediante HTTP.</p><section class="grid">$($cards -join "`n")</section><p class="footer">Cuentas de demostración locales. No se muestra el contenido de los tokens.</p></main></body></html>
"@
    Set-Content -LiteralPath (Join-Path $OutputDirectory "$key.html") -Value $html -Encoding utf8
}

$payloadPart = $vetToken.Split('.')[1].Replace('-', '+').Replace('_', '/')
switch ($payloadPart.Length % 4) { 2 { $payloadPart += '==' } 3 { $payloadPart += '=' } }
$claims = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payloadPart)) | ConvertFrom-Json | ConvertTo-Json -Depth 5
$claimsHtml = @"
<!doctype html><html lang="es"><meta charset="utf-8"><title>Claims del token Veterinario</title>
<style>body{font:20px Arial,sans-serif;background:#eef2f7;color:#172554;margin:0;padding:40px}.sheet{max-width:900px;margin:auto;background:#fff;padding:42px;border-radius:16px;box-shadow:0 8px 26px #94a3b855}h1{font-size:30px}p{color:#475569}pre{background:#0f172a;color:#e2e8f0;padding:24px;border-radius:12px;font-size:20px;line-height:1.55}.badge{display:inline-block;background:#15803d;color:#fff;border-radius:999px;padding:8px 14px;font-weight:bold}.note{font-size:14px}</style>
<body><main class="sheet"><h1>Token de prueba decodificado</h1><span class="badge">Claims reales del login local</span><p>Se muestra el payload del token; el JWT completo y su firma se omiten.</p><pre>$([System.Net.WebUtility]::HtmlEncode($claims))</pre><p class="note">El token está firmado y su payload está codificado, no cifrado. Las claves de firma no se incluyen.</p></main></body></html>
"@
Set-Content -LiteralPath (Join-Path $OutputDirectory 'captura-claims.html') -Value $claimsHtml -Encoding utf8

$results | Select-Object Actual,Role,Method,Path,Passed | Format-Table -AutoSize
$failed = @($results | Where-Object { -not $_.Passed })
if ($failed.Count) { throw "$($failed.Count) pruebas no devolvieron el código esperado." }
Write-Host "Capturas HTML listas en: $OutputDirectory"
