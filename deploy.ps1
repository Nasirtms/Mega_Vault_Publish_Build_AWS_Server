# deploy.ps1 - Deploy CasinoBackend to AWS via ssh alias "my-aws"

param(
    [switch]$Setup,
    [switch]$Nginx
)

$ErrorActionPreference = "Stop"

# Function to setup server environment
function Initialize-Server {
    Write-Host "Setting up server environment..." -ForegroundColor Cyan
    
    $setupCommands = @(
        "set -e",
        "sudo apt-get update -y",
        "sudo apt-get install -y aspnetcore-runtime-8.0",
        "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -",
        "sudo apt-get install -y nodejs",
        "sudo npm i -g pm2",
        "sudo apt-get install -y nginx",
        "sudo mkdir -p /var/www/CasinoBackend",
        "sudo chown -R `$USER:`$USER /var/www/CasinoBackend"
    )
    
    $commandString = $setupCommands -join "; "
    ssh my-aws $commandString
    
    Write-Host "Server setup completed!" -ForegroundColor Green
}

# Function to configure nginx
function Initialize-Nginx {
    Write-Host "Configuring nginx..." -ForegroundColor Cyan
    
    $nginx = @'
set -e
sudo tee /etc/nginx/sites-available/CasinoBackend >/dev/null <<'NGINX'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5036;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX
sudo ln -sf /etc/nginx/sites-available/CasinoBackend /etc/nginx/sites-enabled/CasinoBackend
sudo nginx -t
sudo systemctl reload nginx
'@
    $nginx | ssh my-aws 'bash -s'
    
    Write-Host "Nginx configuration completed!" -ForegroundColor Green
}

# Check if setup parameter is provided
if ($Setup) {
    Initialize-Server
    exit
}

if ($Nginx) {
    Initialize-Nginx
    exit
}

Write-Host "Starting deployment to AWS server..." -ForegroundColor Green

# Build the .NET application first
Write-Host "Building .NET application..." -ForegroundColor Yellow
$projectPath = "D:\GameBackend\Cursor\CasinoBackend\CasinoBackend"
$buildOutput = "D:\GameBackend\Server Data\Publish Build\Build"

# Clean and create build directory
if (Test-Path $buildOutput) {
    Remove-Item -Path $buildOutput -Recurse -Force
}
New-Item -ItemType Directory -Path $buildOutput -Force

# Build and publish the application
Set-Location $projectPath
dotnet publish -c Release -o $buildOutput
Set-Location "D:\GameBackend\Server Data\Publish Build"

Write-Host "Build completed!" -ForegroundColor Green

# Remote destination (kept consistent with ecosystem.config.js)
$RemoteDir   = "/var/www/CasinoBackend"

# 1) Copy build output using scp (Windows native)
Write-Host "Syncing Build directory contents to server..." -ForegroundColor Yellow
    scp -r ".\Build\*" my-aws:$RemoteDir/

# 2) Copy PM2 ecosystem file using scp
Write-Host "Syncing ecosystem.config.js to server..." -ForegroundColor Yellow
    scp ".\ecosystem.config.js" my-aws:$RemoteDir/

# 3) Stop and cleanup old processes, then start new one
Write-Host "Stopping old processes and cleaning up..." -ForegroundColor Yellow
ssh my-aws "pm2 kill 2>/dev/null || true; pkill -f 'dotnet.*CasinoBackend' 2>/dev/null || true; sudo fuser -k 5036/tcp 2>/dev/null || true; sleep 3"

Write-Host "Starting new application..." -ForegroundColor Yellow
ssh my-aws "cd /var/www/CasinoBackend && nohup dotnet CasinoBackend.dll > app.log 2>&1 &"

Write-Host "Waiting for application to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "Checking application status..." -ForegroundColor Yellow
ssh my-aws "echo 'Checking if dotnet process is running...' && ps aux | grep 'dotnet CasinoBackend.dll' | grep -v grep && echo 'Testing connectivity...' && curl -I http://localhost:5036/api/users/login"

Write-Host "Deployment completed!" -ForegroundColor Green
Write-Host ""
Write-Host "To verify your deployment, run one of these commands:" -ForegroundColor Cyan
Write-Host "Invoke-WebRequest -Uri 'http://3.231.201.150:5036/api/users/login' -Method POST -ContentType 'application/json' -Body '{\"email\": \"Nasir\", \"password\": \"pass123\"}'" -ForegroundColor Yellow
Write-Host "# or test with curl: curl -X POST http://3.231.201.150:5036/api/users/login -H 'Content-Type: application/json' -d '{\"email\": \"Nasir\", \"password\": \"pass123\"}'" -ForegroundColor Yellow