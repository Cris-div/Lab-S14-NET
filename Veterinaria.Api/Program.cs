using AutoMapper;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.EntityFrameworkCore;
using Veterinaria.Datos.Models;
using Veterinaria.Datos.Repositorios;
using Veterinaria.Negocio;
using Veterinaria.Negocio.Servicios;
using Veterinaria.Api.OpenApi;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
builder.Services.AddOpenApi(options =>
{
    options.AddDocumentTransformer<BearerSecurityTransformer>();
    options.AddOperationTransformer<BearerSecurityTransformer>();
});
var jwtKey = builder.Configuration["Jwt:Clave"];
if (string.IsNullOrWhiteSpace(jwtKey) || Encoding.UTF8.GetByteCount(jwtKey) < 32)
    throw new InvalidOperationException("Configura Jwt__Clave con al menos 32 bytes mediante variables de entorno o user-secrets.");
var jwtIssuer = builder.Configuration["Jwt:Emisor"] ?? throw new InvalidOperationException("Falta Jwt:Emisor.");
var jwtAudience = builder.Configuration["Jwt:Audiencia"] ?? throw new InvalidOperationException("Falta Jwt:Audiencia.");
var jwtMinutes = builder.Configuration.GetValue<int>("Jwt:ExpiracionMinutos");
if (jwtMinutes < 1) throw new InvalidOperationException("Jwt:ExpiracionMinutos debe ser mayor que cero.");
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.MapInboundClaims = false;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwtIssuer,
            ValidateAudience = true,
            ValidAudience = jwtAudience,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
            RoleClaimType = "rol",
            NameClaimType = "email"
        };
    });
builder.Services.AddAuthorization();
builder.Services.AddDbContext<VeterinariaContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("Veterinaria")
        ?? throw new InvalidOperationException("Configura ConnectionStrings__Veterinaria mediante una variable de entorno.")));
builder.Services.AddScoped<IPropietarioRepositorio, PropietarioRepositorio>();
builder.Services.AddScoped<IMascotaRepositorio, MascotaRepositorio>();
builder.Services.AddScoped<IUsuarioRepositorio, UsuarioRepositorio>();
builder.Services.AddScoped<IPropietarioServicio, PropietarioServicio>();
builder.Services.AddScoped<IMascotaServicio, MascotaServicio>();
builder.Services.AddScoped<IAuthServicio, AuthServicio>();
builder.Services.AddAutoMapper(config => config.AddProfile<MappingProfile>());

var app = builder.Build();
// Valida los seis mapas antes de atender solicitudes.
app.Services.GetRequiredService<IMapper>().ConfigurationProvider.AssertConfigurationIsValid();
app.MapOpenApi();
app.UseSwaggerUI(options => options.SwaggerEndpoint("/openapi/v1.json", "Veterinaria S13 v1"));
if (builder.Configuration.GetValue<bool>("UsarHttps")) app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.Run();
