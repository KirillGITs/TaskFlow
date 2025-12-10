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
