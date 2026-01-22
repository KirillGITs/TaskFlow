<<<<<<< HEAD
# TaskFlow 📱

**Ваш персональний менеджер завдань з Pomodoro таймером**

![Flutter](https://img.shields.io/badge/Flutter-3.38.3-blue)
![Dart](https://img.shields.io/badge/Dart-3.10.1-blue)
![License](https://img.shields.io/badge/License-MIT-green)

---

## ✨ Можливості

- ✅ **Завдання** - створюйте, редагуйте, архівуйте
- 📅 **Календар** - планування та перегляд по датах
- 💪 **Звички** - відстежуйте щоденні звички та серії
- ⏲️ **Pomodoro** - таймер 25/5/15 хвилин для продуктивності
- 📥 **Inbox** - швидкий доступ до всіх завдань
- 🔐 **Firebase** - синхронізація між пристроями (опціонально)
- 🌍 **6 мов** - Polski, Українська, Русский, English, Deutsch, Español
- 🎨 **Теми** - Світла, темна, системна
- 📊 **Статистика** - відстежуйте прогрес і досягнення

---

## 🚀 Швидкий старт

### Варіант 1: Без Firebase (Найпростіше)

```bash
flutter pub get
flutter run
```

Натисніть **"Продовжити без акаунта"** - готово!

### Варіант 2: З Google Sign-In

Дивіться детальну інструкцію: **[QUICK_START.md](QUICK_START.md)**

---

## 📦 Встановлення

```bash
# Клонуйте репозиторій
git clone https://github.com/KirillGITs/TaskFlow.git
cd TaskFlow

# Встановіть залежності
flutter pub get

# Запустіть на пристрої
flutter run

# Або зберіть APK
flutter build apk --release
```

---

## 🔧 Налаштування Firebase (Опціонально)

Google Sign-In працює тільки після налаштування Firebase.

### Швидке налаштування (з Firebase CLI):

```bash
# 1. Встановіть Firebase CLI
# Windows: https://firebase.google.com/docs/cli#windows-standalone-binary
# macOS/Linux: curl -sL https://firebase.tools | bash

# 2. Встановіть FlutterFire CLI
dart pub global activate flutterfire_cli

# 3. Увійдіть в Firebase
firebase login

# 4. Налаштуйте проект
flutterfire configure

# 5. ⚠️ ВАЖЛИВО: Увімкніть Google Sign-In
# → Firebase Console: https://console.firebase.google.com/
# → Authentication → Sign-in method → Google → Enable
# → Введіть support email → Save

# 6. Перезапустіть додаток
flutter clean && flutter pub get && flutter run
```

### Ручне налаштування (без CLI):

Не хочете встановлювати Firebase CLI? Дивіться покрокову інструкцію: **[MANUAL_SETUP.md](MANUAL_SETUP.md)**

**Детальна інструкція з Firebase CLI:** [FIREBASE_SETUP.md](FIREBASE_SETUP.md)

---

## 📱 Скріншоти

_Coming soon..._

---

## 🛠️ Технології

- **Flutter** 3.38.3
- **Dart** 3.10.1
- **Firebase** (Auth, Firestore)
- **Google Sign-In**
- **SharedPreferences**
- **Material Design 3**

---

## 📄 Ліцензія

MIT License - дивіться [LICENSE](LICENSE) для деталей

---

## 👤 Автор

**Kirill** - [GitHub](https://github.com/KirillGITs)

---

## 🤝 Внесок

Pull requests вітаються! Для великих змін спочатку створіть Issue.

---

## 📞 Підтримка

Є питання? Створіть [Issue](https://github.com/KirillGITs/TaskFlow/issues) на GitHub!
=======
# Article PDF Finder - Instrukcja instalacji i uruchomienia

## Opis projektu

Serwis internetowy służący do wyszukiwania informacji o wpisach (newsach) na wybranej stronie internetowej. Aplikacja wykorzystuje PostgreSQL, Django, React, Selenium i jest uruchamiana w środowisku Docker.

## Wymagania

- Windows 10/11 (64-bit)
- Docker Desktop dla Windows
- Minimum 4GB RAM (zalecane 8GB)
- Minimum 10GB wolnego miejsca na dysku

## Instalacja Docker Desktop

### Krok 1: Pobierz Docker Desktop

1. Przejdź na stronę: https://www.docker.com/products/docker-desktop/
2. Kliknij "Download for Windows"
3. Pobierz plik instalacyjny `Docker Desktop Installer.exe`

### Krok 2: Zainstaluj Docker Desktop

1. Uruchom pobrany plik instalacyjny
2. Zaznacz opcję "Use WSL 2 instead of Hyper-V" (jeśli dostępna)
3. Postępuj zgodnie z instrukcjami instalatora
4. Po zakończeniu instalacji uruchom ponownie komputer (jeśli wymagane)

### Krok 3: Uruchom Docker Desktop

1. Znajdź Docker Desktop w menu Start
2. Uruchom aplikację
3. Poczekaj, aż Docker Desktop się uruchomi (ikona wieloryba w zasobniku systemowym)
4. Upewnij się, że Docker Desktop działa (ikona nie miga)

## Uruchomienie aplikacji

### Krok 1: Otwórz terminal

1. Otwórz PowerShell lub Command Prompt
2. Przejdź do katalogu projektu:
   ```powershell
   cd C:\Users\rassu\Downloads\FULLSTACK\hello_fullstack
   ```

### Krok 2: Uruchom aplikację

```powershell
docker-compose up --build
```

Lub jeśli używasz nowszej wersji Docker:
```powershell
docker compose up --build
```

### Krok 3: Poczekaj na uruchomienie

Pierwsze uruchomienie może zająć kilka minut, ponieważ:
- Pobierane są obrazy Docker (PostgreSQL, Selenium, Nginx)
- Instalowane są zależności Python i Node.js
- Tworzone są tabele w bazie danych

### Krok 4: Otwórz aplikację

Po zakończeniu uruchamiania otwórz przeglądarkę i przejdź do:
```
http://localhost
```

## Użycie aplikacji

1. **Wpisz słowo kluczowe** - np. "chopin"
2. **Wpisz domenę strony** - np. "rzeczpospolita.pl"
3. **Kliknij "Search"**
4. **Poczekaj na wyniki** - aplikacja przeszuka stronę i znajdzie artykuły
5. **Pobierz PDF** - jeśli artykuł ma wersję PDF, pojawi się link do pobrania

## Struktura projektu

```
hello_fullstack/
├── backend/          # Django backend
│   ├── config/       # Konfiguracja Django
│   ├── search/       # Aplikacja wyszukiwania
│   └── downloads/    # Pobrane pliki PDF
├── frontend/         # React frontend
├── nginx/            # Konfiguracja Nginx
└── docker-compose.yml # Konfiguracja Docker
```

## Porty

- **80** - Nginx (główny dostęp do aplikacji)
- **3000** - React development server
- **8000** - Django backend
- **4444** - Selenium Grid
- **5432** - PostgreSQL

## Rozwiązywanie problemów

### Problem: "docker-compose: command not found"

**Rozwiązanie:** Użyj `docker compose` (bez myślnika) lub zaktualizuj Docker Desktop.

### Problem: "Cannot connect to Docker daemon"

**Rozwiązanie:** 
1. Upewnij się, że Docker Desktop jest uruchomiony
2. Sprawdź, czy ikona Docker w zasobniku systemowym nie miga
3. Spróbuj uruchomić Docker Desktop ponownie

### Problem: Port już zajęty

**Rozwiązanie:**
1. Sprawdź, czy port 80 nie jest używany przez inną aplikację
2. Zatrzymaj inne serwery web (IIS, Apache, itp.)
3. Lub zmień port w `docker-compose.yml` i `nginx.conf`

### Problem: Błąd połączenia z bazą danych

**Rozwiązanie:**
1. Sprawdź logi: `docker-compose logs db`
2. Upewnij się, że kontener `db` jest uruchomiony: `docker-compose ps`
3. Spróbuj zrestartować: `docker-compose restart db`

### Problem: Selenium nie działa

**Rozwiązanie:**
1. Sprawdź logi: `docker-compose logs selenium`
2. Upewnij się, że kontener ma wystarczająco pamięci (shm_size: "2g")
3. Spróbuj zrestartować: `docker-compose restart selenium`

## Przydatne komendy

### Zatrzymanie aplikacji
```powershell
docker-compose down
```

### Zatrzymanie i usunięcie wolumenów
```powershell
docker-compose down -v
```

### Wyświetlenie logów
```powershell
docker-compose logs -f
```

### Wyświetlenie logów konkretnego serwisu
```powershell
docker-compose logs -f backend
docker-compose logs -f frontend
docker-compose logs -f selenium
```

### Sprawdzenie statusu kontenerów
```powershell
docker-compose ps
```

### Przeładowanie aplikacji (po zmianach w kodzie)
```powershell
docker-compose restart backend
docker-compose restart frontend
```

### Rebuild bez cache
```powershell
docker-compose build --no-cache
docker-compose up
```

## Testowanie

Aby przetestować aplikację:

1. Otwórz `http://localhost`
2. Wpisz słowo kluczowe: **chopin**
3. Wpisz domenę: **rzeczpospolita.pl**
4. Kliknij "Search"
5. Poczekaj na wyniki (może zająć 30-60 sekund)
6. Sprawdź, czy pojawiły się artykuły
7. Sprawdź, czy można pobrać PDF (jeśli dostępny)

## Wsparcie

W przypadku problemów sprawdź:
- Logi Docker: `docker-compose logs`
- Status kontenerów: `docker-compose ps`
- Dokumentację Docker: https://docs.docker.com/
>>>>>>> acadc86232f312e0be65dda4f2c086d80dfe0513
