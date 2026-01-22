# Skrypt sprawdzający gotowość systemu

Write-Host "=== Sprawdzanie gotowości systemu ===" -ForegroundColor Cyan
Write-Host ""

# Sprawdzenie Dockera
Write-Host "1. Sprawdzanie Dockera..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   [OK] Docker zainstalowany: $dockerVersion" -ForegroundColor Green
    } else {
        Write-Host "   [BŁĄD] Docker nie jest zainstalowany lub nie znajduje się w PATH" -ForegroundColor Red
        Write-Host "   Pobierz Docker Desktop ze strony: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "   [BŁĄD] Docker nie jest zainstalowany" -ForegroundColor Red
    Write-Host "   Pobierz Docker Desktop ze strony: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    exit 1
}

# Sprawdzenie Docker Compose
Write-Host "2. Sprawdzanie Docker Compose..." -ForegroundColor Yellow
$composeCmd = "docker-compose"
try {
    $composeVersion = docker-compose --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   [OK] Docker Compose zainstalowany: $composeVersion" -ForegroundColor Green
    } else {
        $composeVersion = docker compose version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   [OK] Docker Compose zainstalowany (nowa składnia): $composeVersion" -ForegroundColor Green
            $composeCmd = "docker compose"
        } else {
            Write-Host "   [BŁĄD] Docker Compose nie jest dostępny" -ForegroundColor Red
            exit 1
        }
    }
} catch {
    Write-Host "   [BŁĄD] Docker Compose nie jest dostępny" -ForegroundColor Red
    exit 1
}

# Sprawdzenie demona Dockera
Write-Host "3. Sprawdzanie demona Dockera..." -ForegroundColor Yellow
try {
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   [OK] Demon Dockera jest uruchomiony" -ForegroundColor Green
    } else {
        Write-Host "   [BŁĄD] Demon Dockera nie jest uruchomiony" -ForegroundColor Red
        Write-Host "   Uruchom Docker Desktop i poczekaj aż się w pełni załaduje" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "   [BŁĄD] Demon Dockera nie jest uruchomiony" -ForegroundColor Red
    Write-Host "   Uruchom Docker Desktop i poczekaj aż się w pełni załaduje" -ForegroundColor Yellow
    exit 1
}

# Sprawdzenie portów
Write-Host "4. Sprawdzanie dostępności portów..." -ForegroundColor Yellow
$ports = @(80, 3000, 8000, 4444, 5432)
$portsInUse = @()

foreach ($port in $ports) {
    $connection = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($connection) {
        $portsInUse += $port
        Write-Host "   [UWAGA] Port $port jest zajęty" -ForegroundColor Yellow
    } else {
        Write-Host "   [OK] Port $port jest wolny" -ForegroundColor Green
    }
}

if ($portsInUse.Count -gt 0) {
    Write-Host ""
    Write-Host "   Uwaga: Niektóre porty są zajęte. Może to spowodować problemy." -ForegroundColor Yellow
    $portsStr = $portsInUse -join ", "
    Write-Host "   Zajęte porty: $portsStr" -ForegroundColor Yellow
}

# Sprawdzenie plików projektu
Write-Host "5. Sprawdzanie plików projektu..." -ForegroundColor Yellow
$requiredFiles = @(
    "docker-compose.yml",
    "backend/Dockerfile",
    "backend/requirements.txt",
    "frontend/Dockerfile",
    "frontend/package.json",
    "nginx/Dockerfile",
    "nginx/nginx.conf"
)

$missingFiles = @()
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "   [OK] $file" -ForegroundColor Green
    } else {
        Write-Host "   [BŁĄD] $file - BRAKUJE" -ForegroundColor Red
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host ""
    $missingStr = $missingFiles -join ", "
    Write-Host "   Brakujące pliki: $missingStr" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== System gotowy do uruchomienia! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Aby uruchomić aplikację, wykonaj:" -ForegroundColor Cyan
Write-Host "  $composeCmd up --build" -ForegroundColor White
Write-Host ""
Write-Host "Następnie otwórz w przeglądarce:" -ForegroundColor Cyan
Write-Host "  http://localhost" -ForegroundColor White
Write-Host ""
