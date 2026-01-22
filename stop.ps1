# Skrypt do zatrzymania aplikacji

Write-Host "=== Zatrzymywanie Article PDF Finder ===" -ForegroundColor Cyan
Write-Host ""

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

# Zatrzymanie kontenerów
Write-Host "Zatrzymywanie kontenerów..." -ForegroundColor Yellow
& $composeCmd.Split(' ') down

Write-Host ""
Write-Host "Aplikacja zatrzymana." -ForegroundColor Green
