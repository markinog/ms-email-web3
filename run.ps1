# run.ps1 - Sobe o ms-email completo: backend (Spring Boot) + frontend (Node)
#
# Uso:
#   .\run.ps1            # verifica pre-requisitos e sobe backend + frontend
#   .\run.ps1 -Backend   # sobe somente o backend (porta 8082)
#   .\run.ps1 -Frontend  # sobe somente o frontend (porta 3000)
#   .\run.ps1 -Check     # apenas verifica pre-requisitos, sem subir nada
#
# Pre-requisitos: Java + Maven (backend), Node/npm (frontend),
# alem de MySQL (3306) e RabbitMQ (5672) ativos para o backend funcionar.

param(
    [switch]$Backend,
    [switch]$Frontend,
    [switch]$Check
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

function Write-Step($msg)  { Write-Host "[run] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "[ok]  $msg" -ForegroundColor Green }
function Write-Warn($msg)  { Write-Host "[!]   $msg" -ForegroundColor Yellow }
function Write-Fail($msg)  { Write-Host "[x]   $msg" -ForegroundColor Red }

# Se nenhum alvo for indicado, sobe os dois
$runBackend  = $Backend -or (-not $Backend -and -not $Frontend)
$runFrontend = $Frontend -or (-not $Backend -and -not $Frontend)

# ----- Verificacao de pre-requisitos -----
function Test-Command($name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

function Test-Port($port) {
    try {
        $c = Test-NetConnection -ComputerName "localhost" -Port $port -WarningAction SilentlyContinue
        return $c.TcpTestSucceeded
    } catch { return $false }
}

Write-Step "Verificando pre-requisitos..."
$problems = 0

if ($runBackend) {
    if (Test-Command "java") { Write-Ok "Java encontrado." } else { Write-Fail "Java nao encontrado no PATH."; $problems++ }
    if (Test-Command "mvn")  { Write-Ok "Maven encontrado." } else { Write-Fail "Maven (mvn) nao encontrado no PATH."; $problems++ }
    if (Test-Port 3306) { Write-Ok "MySQL respondendo na porta 3306." } else { Write-Warn "MySQL nao respondeu em 3306 - o backend nao vai subir sem ele." }
    if (Test-Port 5672) { Write-Ok "RabbitMQ respondendo na porta 5672." } else { Write-Warn "RabbitMQ nao respondeu em 5672 - mensageria de e-mail vai falhar." }
}

if ($runFrontend) {
    if (Test-Command "node") { Write-Ok "Node encontrado." } else { Write-Fail "Node nao encontrado no PATH."; $problems++ }
    if (Test-Command "npm")  { Write-Ok "npm encontrado." } else { Write-Fail "npm nao encontrado no PATH."; $problems++ }
    if (-not (Test-Port 8081)) { Write-Warn "User Service nao respondeu em 8081 - solicitar/validar codigo vai falhar (repo separado)." }
}

if ($problems -gt 0) {
    Write-Fail "$problems pre-requisito(s) obrigatorio(s) ausente(s). Corrija antes de continuar."
    exit 1
}

if ($Check) { Write-Ok "Verificacao concluida."; exit 0 }

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
    Write-Ok "Variaveis do .env carregadas."
} elseif ($runBackend) {
    Write-Warn ".env nao encontrado. O envio de e-mails pode falhar (EMAIL_USERNAME/EMAIL_PASSWORD/RABBITMQ_ADDRESS)."
}

# ----- Backend: Email Service (porta 8082) -----
if ($runBackend) {
    Write-Step "Abrindo Email Service (porta 8082)..."
    $emailCmd = "$envExports cd '$root'; Write-Host 'EMAIL SERVICE (8082)' -ForegroundColor Cyan; mvn spring-boot:run"
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $emailCmd
}

# ----- Frontend (porta 3000) -----
if ($runFrontend) {
    Write-Step "Abrindo Frontend (porta 3000)..."
    $frontPath = Join-Path $root "frontend"
    $frontCmd = "cd '$frontPath'; Write-Host 'FRONTEND (3000)' -ForegroundColor Cyan; if (-not (Test-Path node_modules)) { npm install }; npm start"
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $frontCmd
}

Write-Host ""
Write-Ok "Pronto!"
if ($runFrontend) { Write-Host "      Frontend:      http://localhost:3000" -ForegroundColor Green }
if ($runBackend)  { Write-Host "      Email Service: http://localhost:8082" -ForegroundColor Green }
Write-Warn "Lembre-se de iniciar tambem o User Service (porta 8081) - repositorio separado."
