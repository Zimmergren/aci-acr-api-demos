FROM microsoft/dotnet:2.2-aspnetcore-runtime AS base
WORKDIR /app
EXPOSE 443

FROM microsoft/dotnet:2.2-sdk AS build
WORKDIR /src
COPY ["TenantIDLookupAPI/TenantIDLookupAPI.csproj", "TenantIDLookupAPI/"]
RUN dotnet restore "TenantIDLookupAPI/TenantIDLookupAPI.csproj"
COPY . .
WORKDIR "/src/TenantIDLookupAPI"
RUN dotnet build "TenantIDLookupAPI.csproj" -c Release -o /app

FROM build AS publish
RUN dotnet publish "TenantIDLookupAPI.csproj" -c Release -o /app

FROM base AS final
WORKDIR /app
COPY --from=publish /app .
ENTRYPOINT ["dotnet", "TenantIDLookupAPI.dll"]