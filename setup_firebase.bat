@echo off
echo ========================================
echo   TaskFlow - Firebase Setup
echo ========================================
echo.
echo Цей скрипт допоможе налаштувати Firebase для TaskFlow
echo.
echo КРОК 1: Встановлення Firebase CLI
echo ========================================
echo.
echo Завантажте Firebase CLI з:
echo https://firebase.google.com/docs/cli#windows-standalone-binary
echo.
echo Або встановіть через npm (якщо є Node.js):
echo npm install -g firebase-tools
echo.
pause
echo.
echo КРОК 2: Перевірка встановлення
echo ========================================
firebase --version
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Firebase CLI не встановлено!
    echo Встановіть Firebase CLI і запустіть скрипт знову.
    pause
    exit /b 1
)
echo.
echo [OK] Firebase CLI встановлено!
echo.
echo КРОК 3: Вхід в Firebase
echo ========================================
firebase login
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Не вдалося увійти в Firebase
    pause
    exit /b 1
)
echo.
echo КРОК 4: Налаштування проекту
echo ========================================
echo.
echo Тепер виконаємо flutterfire configure...
echo Оберіть або створіть проект "TaskFlow"
echo.
pause
flutterfire configure
echo.
echo ========================================
echo   Налаштування завершено!
echo ========================================
echo.
echo НЕ ЗАБУДЬТЕ:
echo 1. Firebase Console → Authentication → Sign-in method
echo 2. Увімкніть Google → Введіть support email → Save
echo 3. Для Web: оновіть web/index.html з Client ID
echo.
echo Детальна інструкція: FIREBASE_SETUP.md
echo.
pause
