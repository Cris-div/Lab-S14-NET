# Veterinaria S14

API de veterinaria de la semana 13, ampliada con registro, login y autorización JWT. Los propietarios y las mascotas se administran según el rol del personal de la clínica.

## Tema y roles

La API organiza los propietarios y sus mascotas. `Recepcionista` administra los datos de propietarios y puede consultar mascotas; `Veterinario` consulta y mantiene los registros de mascotas. El registro público crea siempre una cuenta `Recepcionista`. El rol no se recibe del cliente; el rol de una cuenta veterinaria lo asigna el administrador de la base de datos.

## Matriz de permisos

| Endpoint | Sin token | Recepcionista | Veterinario |
|---|---:|---:|---:|
| `POST /api/auth/registro` | 201 | 201 | 201 |
| `POST /api/auth/login` | 200 / 401 | 200 / 401 | 200 / 401 |
| `GET /api/auth/perfil` | 401 | 200 | 200 |
| `GET /api/mascotas` y `GET /api/mascotas/{id}` | 401 | 200 | 200 |
| `POST /api/mascotas` | 401 | 403 | 201 |
| `PUT /api/mascotas/{id}` | 401 | 403 | 204 |
| `DELETE /api/mascotas/{id}` | 401 | 403 | 204 |
| `GET /api/propietarios`, `GET /api/propietarios/{id}` y `GET /api/propietarios/{id}/mascotas` | 401 | 200 | 403 |
| `POST /api/propietarios` | 401 | 403 | 201 |
| `PUT /api/propietarios/{id}` y `DELETE /api/propietarios/{id}` | 401 | 403 | 204 |

Las respuestas 400 corresponden a datos inválidos; 404, a recursos inexistentes; y 409, a una regla de negocio incumplida como correo o documento duplicado. `POST /api/auth/login` devuelve 401 con el mismo resultado para un correo inexistente y una clave incorrecta.

## Cuentas de prueba

`database/Usuarios.sql` crea una cuenta para cada rol. Las claves de demostración son `VetS14-Admin123!` para `veterinario@vet.local` y `RecepS14-User123!` para `recepcion@vet.local`. Las cuentas y sus hashes se usan solo en la base local del laboratorio. Los usuarios registrados desde la API reciben el rol `Recepcionista`.

## Ejecutar

Requisitos: Docker Desktop en modo Linux y Docker Compose. Desde PowerShell, en la raíz:

```powershell
./scripts/Start-Docker.ps1
```

El script genera `.env` local con claves aleatorias, inicializa SQL Server y levanta la API en <http://localhost:5164/swagger>. `.env` está excluido de Git. `appsettings.json` contiene emisor, audiencia y duración del token; `Jwt__Clave` se configura fuera del repositorio. En ejecución local con `./scripts/Start-Local.ps1`, se crea una clave aleatoria para esa sesión si no existe una variable `Jwt__Clave`.

La solución usa `VeterinariaS14DB`, una base independiente para no modificar la base de la semana 13. El inicializador ejecuta `database/Veterinaria.sql` y `database/Usuarios.sql`; ambos scripts son idempotentes y pueden volver a ejecutarse sin borrar datos.

## Pruebas

Usa `Veterinaria.Api/Veterinaria.Api.http` desde VS Code con REST Client o IntelliJ HTTP Client. Las solicitudes están ordenadas para obtener ambos tokens y demostrar 200, 201, 204, 400, 401, 403, 404 y 409. Swagger incluye el esquema Bearer: inicia sesión, copia `token` y pégalo en Authorize sin la palabra `Bearer`.

Para la captura del token decodificado, inicia sesión con una cuenta de prueba y pega el token en un decodificador JWT local. Comprueba que aparecen `sub`, `email` y `rol`; el contenido de un JWT está codificado, no cifrado.

## Sustentación de seguridad

- **401 y 403:** una petición sin token a `POST /api/mascotas` recibe 401 porque falta autenticación. Si inicia sesión `recepcion@vet.local` y usa ese token en el mismo endpoint, recibe 403: el token es válido, pero el rol no es `Veterinario`.
- **Claims:** el token lleva `sub` para identificar al usuario, `email` para mostrar su cuenta y `rol` para autorizar operaciones. No debe incluir contraseñas, hashes, claves secretas ni datos personales que el cliente no deba leer: el payload no está cifrado.
- **Contraseña en texto:** una filtración de la base expondría directamente las credenciales y permitiría reutilizarlas en otros servicios. BCrypt almacena un hash con sal y costo de cálculo.
- **Rol asignado en servidor:** aceptar el rol del registro permitiría que cualquiera se autoproclamara veterinario. El servidor asigna `Recepcionista`; un administrador puede promover la cuenta en la base.
