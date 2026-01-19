# Skrypt do uruchomienia aplikacji

Write-Host "=== Uruchamianie Article PDF Finder ===" -ForegroundColor Cyan
Write-Host ""

# Sprawdzenie czy jesteśmy w odpowiednim katalogu
if (-not (Test-Path "docker-compose.yml")) {
    Write-Host "Błąd: Uruchom skrypt z katalogu hello_fullstack" -ForegroundColor Red
    exit 1
}

# Sprawdzenie Dockera
Write-Host "Sprawdzanie Dockera..." -ForegroundColor Yellow
try {
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Błąd: Docker nie jest uruchomiony. Uruchom Docker Desktop." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Błąd: Docker nie jest zainstalowany." -ForegroundColor Red
    exit 1
}

# Sprawdzenie Docker Compose
$composeCmd = "docker-compose"
try {
    docker-compose --version 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $composeCmd = "docker compose"
        docker compose version 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Błąd: Docker Compose nie jest dostępny." -ForegroundColor Red
            exit 1
        }
    }
} catch {
    Write-Host "Błąd: Docker Compose nie jest dostępny." -ForegroundColor Red
    exit 1
}

Write-Host "Uruchamianie kontenerów..." -ForegroundColor Green
Write-Host ""

# Uruchomienie docker-compose
& $composeCmd.Split(' ') up --build
