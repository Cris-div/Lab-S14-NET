FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY Directory.Build.props ./
COPY Veterinaria.Entidades/Veterinaria.Entidades.csproj Veterinaria.Entidades/
COPY Veterinaria.Datos/Veterinaria.Datos.csproj Veterinaria.Datos/
COPY Veterinaria.Negocio/Veterinaria.Negocio.csproj Veterinaria.Negocio/
COPY Veterinaria.Api/Veterinaria.Api.csproj Veterinaria.Api/
RUN dotnet restore Veterinaria.Api/Veterinaria.Api.csproj
COPY . .
RUN dotnet publish Veterinaria.Api/Veterinaria.Api.csproj -c Release -o /app/publish --no-restore /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
COPY --from=build /app/publish .
USER $APP_UID
ENTRYPOINT ["dotnet", "Veterinaria.Api.dll"]
