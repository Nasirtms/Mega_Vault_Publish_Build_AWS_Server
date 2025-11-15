module.exports = {
  apps: [
    {
      name: "CasinoBackend",
      cwd: "/var/www/CasinoBackend",
      command: "dotnet CasinoBackend.dll",
      interpreter: "none",
      instances: 1,
      autorestart: true,
      watch: false,
      env: {
        ASPNETCORE_URLS: "http://0.0.0.0:5036",
        ASPNETCORE_ENVIRONMENT: "Production",
        DOTNET_URLS: "http://0.0.0.0:5036",
        Kestrel__Endpoints__Http__Url: "http://0.0.0.0:5036",
        Kestrel__Endpoints__Http__Protocols: "Http1AndHttp2"
      }
    }
  ]
};