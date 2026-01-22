<<<<<<< HEAD
# 🚀 Швидкий старт - Google Sign-In

## Варіант 1: Використання без Google Sign-In (Найпростіше)

1. Запустіть додаток
2. Натисніть **"Продовжити без акаунта"**
3. Готово! Всі дані зберігаються локально

---

## Варіант 2: Налаштування Google Sign-In (5 хвилин)

### Метод A: Автоматичне налаштування (рекомендовано)

1️⃣ **Встановіть Firebase CLI:**

**Windows:**
- Завантажте: https://firebase.google.com/docs/cli#windows-standalone-binary
- Або через npm: `npm install -g firebase-tools`

**macOS/Linux:**
```bash
curl -sL https://firebase.tools | bash
```

2️⃣ **Встановіть FlutterFire CLI:**

```bash
dart pub global activate flutterfire_cli
```

3️⃣ **Налаштуйте Firebase:**

```bash
# Увійдіть в Firebase
firebase login

# Налаштуйте проект
flutterfire configure
```

- Виберіть проект **TaskFlow**
- Виберіть платформи (Android, Web, тощо)
- Готово! Файл `firebase_options.dart` створено автоматично

### Метод B: Ручне налаштування (без CLI)

Не хочете встановлювати Firebase CLI? Дивіться: **[MANUAL_SETUP.md](MANUAL_SETUP.md)**

---

### 4️⃣ Увімкніть Google Sign-In

1. Відкрийте Firebase Console → **Authentication**
2. Натисніть **Sign-in method**
3. Увімкніть **Google**
4. Введіть support email
5. Збережіть

### 5️⃣ Для Android: Додайте SHA-1

```bash
# У папці проекту:
cd android
./gradlew signingReport
# Або на Windows:
gradlew.bat signingReport
```

Скопіюйте **SHA-1** і додайте у Firebase Console → Project Settings → Your apps → Android app

### 6️⃣ Перезапустіть додаток

```bash
flutter clean
flutter pub get
flutter run
```

### ✅ Готово!

Тепер Google Sign-In працює без помилок!

---

## 🆘 Що робити при помилках?

### "flutterfire: command not found"
➡️ **Firebase CLI не встановлено!**
- Встановіть Firebase CLI: https://firebase.google.com/docs/cli
- Або використайте ручне налаштування: [MANUAL_SETUP.md](MANUAL_SETUP.md)

### "401: invalid_client" або "OAuth client was not found"
➡️ **Google Sign-In не увімкнено у Firebase Console!**
1. Firebase Console → Authentication → Sign-in method
2. Google → Enable → Введіть support email → Save
3. Виконайте `flutterfire configure`
4. Перезапустіть додаток

### "ClientID not set" (Web)
➡️ **Для Web потрібен додатковий крок!** Дивіться: [WEB_SETUP.md](WEB_SETUP.md)

### "API key not valid"
➡️ Виконайте `flutterfire configure` і перезапустіть додаток

### "Sign in failed" / "DEVELOPER_ERROR"
➡️ Додайте SHA-1 сертифікат у Firebase Console

### "Google Sign-In тимчасово недоступний"
➡️ Використайте "Продовжити без акаунта" або налаштуйте Firebase

---

## 📖 Детальна інструкція

Дивіться файл `FIREBASE_SETUP.md` для покрокової інструкції з скріншотами.

---

## 💡 Підказки

- **Локальний режим** працює без Firebase
- **Email/пароль** працює відразу після налаштування Firebase
- **Google Sign-In** потребує додаткового налаштування SHA-1

---

**Потрібна допомога?** Створіть Issue на GitHub!
=======
# Szybki start

## 1. Zainstaluj Docker Desktop

Pobierz i zainstaluj z: https://www.docker.com/products/docker-desktop/

## 2. Uruchom aplikację

```powershell
cd hello_fullstack
docker-compose up --build
```

Lub:
```powershell
docker compose up --build
```

## 3. Otwórz w przeglądarce

```
http://localhost
```

## 4. Przetestuj

- Słowo kluczowe: `chopin`
- Strona: `rzeczpospolita.pl`
- Kliknij "Search"

## Zatrzymanie

Naciśnij `Ctrl+C` w terminalu lub:
```powershell
docker-compose down
```
>>>>>>> acadc86232f312e0be65dda4f2c086d80dfe0513
