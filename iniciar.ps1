# iniciar.ps1 - Sobe Email Service e Frontend em terminais separados (Windows / PowerShell)
#
# Uso:  .\iniciar.ps1
#
# Observacao: o User Service (porta 8081) esta em outro repositorio e precisa ser
# iniciado a parte. Ajuste $UserServicePath abaixo se quiser que este script o inicie tambem.

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

# ----- Carrega variaveis do .env (se existir) -----
$envFile = Join-Path $root ".env"
$envExports = ""
if (Test-Path $envFile) {
    Get-Content $envFile | Where-Object { $_ -match "=" -and $_ -notmatch "^\s*#" } | ForEach-Object {
        $pair = $_ -split "=", 2
        $name = $pair[0].Trim()
        $value = $pair[1].Trim()
        $envExports += "`$env:$name = '$value'; "
    }
    Write-Host "[iniciar] Variaveis do .env carregadas." -ForegroundColor Green
} else {
    Write-Host "[iniciar] AVISO: .env nao encontrado. Email Service pode falhar ao enviar e-mails." -ForegroundColor Yellow
}

# ----- Terminal 1: Email Service -----
Write-Host "[iniciar] Abrindo Email Service (porta 8082)..." -ForegroundColor Cyan
$emailCmd = "$envExports cd '$root'; Write-Host 'EMAIL SERVICE' -ForegroundColor Cyan; mvn spring-boot:run"
Start-Process powershell -ArgumentList "-NoExit", "-Command", $emailCmd

# ----- Terminal 2: Frontend -----
Write-Host "[iniciar] Abrindo Frontend (porta 3000)..." -ForegroundColor Cyan
$frontPath = Join-Path $root "frontend"
$frontCmd = "cd '$frontPath'; Write-Host 'FRONTEND' -ForegroundColor Cyan; if (-not (Test-Path node_modules)) { npm install }; npm start"
Start-Process powershell -ArgumentList "-NoExit", "-Command", $frontCmd

# ----- (Opcional) Terminal 3: User Service -----
# $UserServicePath = "C:\caminho\para\ms-user"
# if (Test-Path $UserServicePath) {
#     Write-Host "[iniciar] Abrindo User Service (porta 8081)..." -ForegroundColor Cyan
#     $userCmd = "cd '$UserServicePath'; Write-Host 'USER SERVICE' -ForegroundColor Cyan; mvn spring-boot:run"
#     Start-Process powershell -ArgumentList "-NoExit", "-Command", $userCmd
# }

Write-Host ""
Write-Host "[iniciar] Pronto! Acesse http://localhost:3000" -ForegroundColor Green
Write-Host "[iniciar] Lembre-se de iniciar tambem o User Service (porta 8081)." -ForegroundColor Yellow
