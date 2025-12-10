# Налаштування Firebase для Google Sign-In

## Крок 1: Створення Firebase проекту

1. Перейдіть на https://console.firebase.google.com/
2. Натисніть **"Add project"** (Додати проект)
3. Введіть назву проекту: **TaskFlow**
4. Виберіть чи хочете Google Analytics (можна вимкнути для простоти)
5. Натисніть **"Create project"**

## Крок 2: Додавання Android додатку

1. На головній сторінці проекту натисніть на іконку **Android**
2. Заповніть форму:
   - **Android package name**: `com.kirill.smartbuy` (з файлу build.gradle)
   - **App nickname**: TaskFlow
   - **Debug signing certificate SHA-1**: (отримайте командою нижче)
3. Натисніть **"Register app"**
4. **Завантажте** файл `google-services.json`
5. Помістіть файл у папку: `android/app/google-services.json`

### Отримання SHA-1 сертифіката:

Виконайте в терміналі (в папці проекту):

```bash
cd android
./gradlew signingReport
```

Або для Windows:
```cmd
cd android
gradlew.bat signingReport
```

Знайдіть рядок **SHA-1** у виводі і скопіюйте його.

## Крок 3: Увімкнення Google Sign-In

1. У Firebase Console перейдіть у **Authentication** → **Sign-in method**
2. Натисніть **"Google"**
3. Увімкніть перемикач **"Enable"**
4. Введіть **Project support email**
5. Натисніть **"Save"**

## Крок 4: Налаштування FlutterFire CLI

1. Встановіть FlutterFire CLI:
```bash
dart pub global activate flutterfire_cli
```

2. Налаштуйте Firebase для Flutter:
```bash
flutterfire configure
```

3. Виберіть ваш проект **TaskFlow**
4. Виберіть платформи (Android, iOS, Web)
5. CLI автоматично створить файл `lib/firebase_options.dart` з правильними ключами

**Важливо для Web:** Після виконання `flutterfire configure`:
1. Відкрийте Firebase Console → Project Settings → General
2. Прокрутіть до розділу **Your apps** → Web app
3. Скопіюйте **Web client ID** (формат: `123456789-abc...xyz.apps.googleusercontent.com`)
4. Відкрийте файл `web/index.html`
5. Замініть `YOUR_WEB_CLIENT_ID` на скопійований Client ID:
```html
<meta name="google-signin-client_id" content="123456789-abc...xyz.apps.googleusercontent.com">
```

## Крок 5: Оновлення android/app/build.gradle

Переконайтеся, що в кінці файлу `android/app/build.gradle` є:

```gradle
apply plugin: 'com.google.gms.google-services'
```

## Крок 6: Оновлення android/build.gradle

Додайте в `dependencies` у файлі `android/build.gradle.kts`:

```kotlin
classpath("com.google.gms:google-services:4.4.0")
```

## Крок 7: Перезапустіть додаток

```bash
flutter clean
flutter pub get
flutter run
```

## Перевірка

Після всіх кроків Google Sign-In має працювати без помилок!

---

## Альтернатива: Локальний режим (без Firebase)

Якщо не хочете налаштовувати Firebase зараз:

1. Додаток вже працює в локальному режимі
2. Натисніть **"Продовжити без акаунта"** на екрані входу
3. Всі дані зберігаються локально на пристрої
4. Firebase можна налаштувати пізніше

---

## Проблеми та рішення

### Помилка "401: invalid_client" або "OAuth client was not found"
Це означає, що Google Sign-In не налаштовано у Firebase:

**Рішення:**
1. Відкрийте Firebase Console → **Authentication**
2. Перейдіть на вкладку **Sign-in method**
3. Знайдіть **Google** у списку провайдерів
4. Натисніть на **Google**
5. **Увімкніть перемикач "Enable"**
6. Введіть **Project support email** (ваш email)
7. Натисніть **Save**
8. Виконайте `flutterfire configure` (якщо ще не робили)
9. Перезапустіть додаток

**Важливо:** Без увімкненого Google Sign-In у Firebase Console він не працюватиме!

### Помилка "API key not valid"
- Переконайтеся, що використовуєте правильний `google-services.json`
- Перевірте, що SHA-1 сертифікат доданий у Firebase Console

### Помилка "sign_in_failed"
- Перевірте, що Google Sign-In увімкнено в Authentication
- Переконайтеся, що вказали support email

### Помилка "ClientID not set" (Web)
- Відкрийте Firebase Console → Project Settings → Your apps → Web
- Скопіюйте Web client ID
- Додайте у `web/index.html`:
```html
<meta name="google-signin-client_id" content="ВАШ_CLIENT_ID.apps.googleusercontent.com">
```
- Перезапустіть додаток: `flutter run -d chrome`

### Помилка "DEVELOPER_ERROR"
- Додайте SHA-1 сертифікат debug keystore у Firebase Console
- Для release: додайте SHA-1 вашого release keystore

---

**Потрібна допомога?** Напишіть питання у Issues на GitHub!
