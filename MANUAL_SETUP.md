# 🚀 Швидке налаштування без Firebase CLI

Якщо не хочете встановлювати Firebase CLI, можете налаштувати все вручну через Web-консоль.

---

## Крок 1: Створіть Firebase проект

1. Відкрийте: https://console.firebase.google.com/
2. Натисніть **"Create a project"** або **"Add project"**
3. Назва проекту: **TaskFlow**
4. Вимкніть Google Analytics (або залиште за бажанням)
5. Натисніть **"Create project"**
6. Дочекайтеся завершення створення

---

## Крок 2: Додайте Android додаток

### 2.1. Створення Android app

1. На головній Firebase Console натисніть іконку **Android**
2. Заповніть форму:
   - **Android package name**: `com.kirill.smartbuy`
   - **App nickname**: TaskFlow
   - **SHA-1**: (залиште порожнім для тестування, додасте пізніше)
3. Натисніть **"Register app"**

### 2.2. Завантажте google-services.json

1. Завантажте файл **google-services.json**
2. Помістіть його у папку: `android/app/google-services.json`

### 2.3. Скопіюйте конфігурацію для Flutter

1. У Firebase Console натисніть на **⚙️ (Settings)** → **Project settings**
2. Прокрутіть до **"Your apps"**
3. Знайдіть ваш Android app
4. Скопіюйте конфігураційні дані

---

## Крок 3: Оновіть firebase_options.dart вручну

Відкрийте файл `lib/firebase_options.dart` і замініть значення для Android:

```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'ВАШ_API_KEY',  // Знайдіть у Project Settings
  appId: 'ВАШ_APP_ID',    // Формат: 1:123456:android:abc123
  messagingSenderId: 'ВАШ_SENDER_ID',
  projectId: 'ваш-project-id',
  storageBucket: 'ваш-project-id.appspot.com',
);
```

**Де знайти ці дані:**
- Firebase Console → Project Settings → General → Your apps → Android app
- Scroll down → **SDK setup and configuration** → **Config**

---

## Крок 4: Увімкніть Google Sign-In

### ⚠️ ВАЖЛИВО: Без цього кроку Google Sign-In не працюватиме!

1. Firebase Console → **Authentication**
2. Вкладка **Sign-in method**
3. Знайдіть **Google** у списку
4. Натисніть на **Google**
5. Увімкніть перемикач **"Enable"**
6. **Project support email**: введіть ваш email
7. Натисніть **"Save"**

---

## Крок 5 (Опціонально): Web додаток

Якщо хочете використовувати на Web (Chrome):

1. Firebase Console → Add app → **Web** (</>)
2. Nickname: **TaskFlow Web**
3. Зареєструйте додаток
4. Скопіюйте **Web Client ID**
5. Додайте у `web/index.html`:
```html
<meta name="google-signin-client_id" content="ВАШ_WEB_CLIENT_ID">
```

Детальніше: **WEB_SETUP.md**

---

## Крок 6: Перезапустіть додаток

```bash
flutter clean
flutter pub get
flutter run
```

---

## ✅ Готово!

Тепер Google Sign-In має працювати!

### Перевірте:
- ✅ `google-services.json` у папці `android/app/`
- ✅ `firebase_options.dart` оновлено з правильними ключами
- ✅ Google Sign-In увімкнено у Firebase Console
- ✅ Додаток перезапущено

---

## 🆘 Проблеми?

### Помилка "401: invalid_client"
➡️ Ви не увімкнули Google Sign-In у Authentication → Sign-in method

### Помилка "API key not valid"
➡️ Перевірте `firebase_options.dart` - можливо не всі поля заповнено

### Помилка "google-services.json not found"
➡️ Файл має бути у `android/app/google-services.json`

---

## 💡 Альтернатива

Не хочете налаштовувати Firebase?

**Натисніть "Продовжити без акаунта"** - все працює локально!

---

**Потрібна допомога?** Створіть Issue на GitHub!
