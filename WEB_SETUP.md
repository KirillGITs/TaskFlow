# 🌐 Налаштування Google Sign-In для Web

## Коротка інструкція

Якщо ви бачите помилку **"ClientID not set"** при використанні Web версії:

### Крок 1: Отримайте Web Client ID

1. Відкрийте Firebase Console: https://console.firebase.google.com/
2. Виберіть проект **TaskFlow**
3. Перейдіть: **⚙️ Project Settings** → вкладка **General**
4. Прокрутіть вниз до **"Your apps"**
5. Знайдіть розділ **Web apps**
6. Скопіюйте **Web client ID** (виглядає як `123456789-abc...xyz.apps.googleusercontent.com`)

### Крок 2: Додайте Client ID у web/index.html

Відкрийте файл `web/index.html` і знайдіть рядок:

```html
<meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com">
```

Замініть `YOUR_WEB_CLIENT_ID.apps.googleusercontent.com` на ваш справжній Client ID:

```html
<meta name="google-signin-client_id" content="123456789-abcdefghijk.apps.googleusercontent.com">
```

### Крок 3: Перезапустіть додаток

```bash
# Зупиніть поточний процес (Ctrl+C)
# Очистіть кеш
flutter clean

# Перезапустіть на Chrome
flutter run -d chrome
```

**Готово!** Google Sign-In має працювати на Web.

---

## Альтернативи

### Варіант 1: Використайте мобільну версію

Google Sign-In працює краще на Android/iOS:

```bash
flutter run -d android
# або
flutter run -d ios
```

### Варіант 2: Локальний режим

Натисніть **"Продовжити без акаунта"** - всі дані зберігаються локально.

---

## Детальна інструкція

### Якщо у вас ще немає Web app у Firebase:

1. Firebase Console → Project Settings
2. Прокрутіть до **"Your apps"**
3. Натисніть **"Add app"** → Виберіть **"Web" (</>)**
4. Введіть nickname: **TaskFlow Web**
5. ✅ Поставте галочку **"Also set up Firebase Hosting"** (опціонально)
6. Натисніть **"Register app"**
7. **Скопіюйте Web Client ID** з екрану конфігурації
8. Додайте у `web/index.html` як описано вище

---

## Перевірка налаштувань

### 1. Перевірте web/index.html

Файл повинен містити:

```html
<!DOCTYPE html>
<html>
<head>
  <!-- ... інші meta теги ... -->
  
  <!-- Google Sign-In - ВАЖЛИВО! -->
  <meta name="google-signin-client_id" content="ВАШ_СПРАВЖНІЙ_CLIENT_ID.apps.googleusercontent.com">
  
  <!-- ... решта файлу ... -->
</head>
```

### 2. Перевірте Firebase Console

- ✅ Authentication → Sign-in method → Google: **Enabled**
- ✅ Project Settings → Your apps → Web app: **Існує**
- ✅ Web client ID: **Скопійований**

### 3. Запустіть на Chrome

```bash
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

---

## Помилки та рішення

### ❌ "ClientID not set"
**Рішення:** Додайте Client ID у `web/index.html` (див. Крок 2)

### ❌ "API key not valid"
**Рішення:** Виконайте `flutterfire configure` і перезапустіть

### ❌ "Pop-up blocked"
**Рішення:** Дозвольте pop-ups для localhost у налаштуваннях браузера

### ❌ "redirect_uri_mismatch"
**Рішення:** 
1. Firebase Console → Authentication → Settings → Authorized domains
2. Додайте `localhost`

---

## Важливі примітки

⚠️ **Web Client ID ≠ API Key**
- API Key: використовується у `firebase_options.dart`
- Web Client ID: використовується для Google Sign-In у `web/index.html`

⚠️ **Для production**
Додайте ваш домен у Firebase Console → Authentication → Authorized domains

⚠️ **CORS issues**
Якщо виникають CORS помилки, переконайтеся що домен додано до Authorized domains

---

**Потрібна допомога?** Створіть Issue на GitHub з описом помилки!
