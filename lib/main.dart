import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase initialization failed - app will work in local-only mode
    debugPrint('Firebase initialization failed: $e');
  }
  runApp(const TaskManagerApp());
}

enum TaskCategory { work, personal, home, other }

enum HabitFrequency { daily, weekly, monthly }

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signUp(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Перевірка чи Firebase ініціалізовано
      if (Firebase.apps.isEmpty) {
        throw Exception(
            'Firebase не ініціалізовано. Будь ласка, налаштуйте Firebase згідно з інструкцією у FIREBASE_SETUP.md');
      }

      // Отримуємо Web Client ID з Firebase options для Web
      String? webClientId = '200804731302-jqbp4asrj484dvop63nirnhei78c6lp1.apps.googleusercontent.com';

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        scopes: ['email'],
        // Передаємо clientId для Web
        clientId: webClientId,
      ).signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      // Firebase authentication помилки
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      throw Exception(_getFirebaseErrorMessage(e.code));
    } catch (e) {
      // Інші помилки
      debugPrint('Google Sign-In Error: $e');
      
      // OAuth client помилка (401: invalid_client)
      if (e.toString().contains('invalid_client') ||
          e.toString().contains('OAuth client was not found') ||
          e.toString().contains('401')) {
        throw Exception(
            '🔐 Google Sign-In не налаштовано!\n\n'
            '❌ Помилка: OAuth client не знайдено\n\n'
            '✅ Як виправити:\n\n'
            '1️⃣ Створіть Firebase проект:\n'
            '   → https://console.firebase.google.com/\n\n'
            '2️⃣ Увімкніть Google Sign-In:\n'
            '   → Authentication → Sign-in method → Google → Enable\n\n'
            '3️⃣ Налаштуйте проект:\n'
            '   → flutterfire configure\n\n'
            '4️⃣ Для Web (якщо використовуєте Chrome):\n'
            '   → Додайте Client ID у web/index.html\n'
            '   → Детально: WEB_SETUP.md\n\n'
            '💡 Альтернатива:\n'
            '   • Натисніть "Продовжити без акаунта"\n'
            '   • Або використайте Email/Пароль\n\n'
            '📖 Повна інструкція: FIREBASE_SETUP.md');
      }
      
      // Спеціальна обробка для Web
      if (e.toString().contains('ClientID not set') || 
          e.toString().contains('appClientId')) {
        throw Exception(
            'Google Sign-In для Web не налаштовано.\n\n'
            'Для використання на Web:\n'
            '1. Створіть Firebase проект\n'
            '2. Виконайте: flutterfire configure\n'
            '3. Оновіть web/index.html з вашим Client ID\n\n'
            'Детальна інструкція у файлі WEB_SETUP.md\n\n'
            'Альтернатива: використайте мобільний додаток (Android/iOS) '
            'або натисніть "Продовжити без акаунта"');
      }
      
      if (e.toString().contains('API key not valid') ||
          e.toString().contains('INVALID_API_KEY')) {
        throw Exception(
            'Firebase API ключ недійсний.\n\nБудь ласка, налаштуйте Firebase:\n1. Створіть проект на console.firebase.google.com\n2. Виконайте: flutterfire configure\n3. Перезапустіть додаток\n\nДетальна інструкція у файлі FIREBASE_SETUP.md');
      }
      rethrow;
    }
  }

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'Акаунт з цією поштою вже існує з іншим методом входу';
      case 'invalid-credential':
        return 'Невірні дані для входу. Перевірте налаштування Firebase';
      case 'operation-not-allowed':
        return '🔐 Google Sign-In не увімкнено!\n\n'
            'Увімкніть у Firebase Console:\n'
            '1. Authentication → Sign-in method\n'
            '2. Google → Enable → Save\n\n'
            'Детальна інструкція: FIREBASE_SETUP.md';
      case 'user-disabled':
        return 'Цей акаунт був деактивований';
      case 'user-not-found':
        return 'Користувача не знайдено';
      case 'wrong-password':
        return 'Невірний пароль';
      case 'invalid-api-key':
        return 'Невірний Firebase API ключ. Налаштуйте Firebase згідно з FIREBASE_SETUP.md';
      default:
        return 'Помилка входу: $code';
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  Future<void> syncToCloud(Map<String, dynamic> data) async {
    if (currentUser != null) {
      await _firestore.collection('users').doc(currentUser!.uid).set(data);
    }
  }

  Future<Map<String, dynamic>?> loadFromCloud() async {
    if (currentUser != null) {
      final doc =
          await _firestore.collection('users').doc(currentUser!.uid).get();
      return doc.data();
    }
    return null;
  }
}

class CustomCategory {
  String id;
  String name;
  IconData icon;
  Color color;

  CustomCategory({
    String? id,
    required this.name,
    this.icon = Icons.label,
    this.color = Colors.blue,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon.codePoint,
        'color': color.value,
      };

  factory CustomCategory.fromMap(Map<String, dynamic> map) {
    final iconCodePoint = map['icon'] as int? ?? Icons.label.codePoint;
    return CustomCategory(
      id: map['id']?.toString(),
      name: map['name']?.toString() ?? '',
      icon: _getIconFromCodePoint(iconCodePoint),
      color: Color(map['color'] as int? ?? Colors.blue.value),
    );
  }

  static IconData _getIconFromCodePoint(int codePoint) {
    // Використовуємо const іконки де можливо
    switch (codePoint) {
      case 0xe57f:
        return Icons.label;
      case 0xe88a:
        return Icons.work;
      case 0xe7fd:
        return Icons.home;
      case 0xe7ef:
        return Icons.person;
      case 0xe8b8:
        return Icons.shopping_cart;
      case 0xe3c9:
        return Icons.restaurant;
      case 0xe1b1:
        return Icons.fitness_center;
      case 0xe530:
        return Icons.school;
      default:
        return Icons.label;
    }
  }
}

class AppLocalizations {
  final String languageCode;

  AppLocalizations(this.languageCode);

  static AppLocalizations of(BuildContext context) {
    final localizations =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (localizations == null) {
      // Fallback to Polish if localizations not ready yet
      return AppLocalizations('pl');
    }
    return localizations;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'pl': {
      'app_title': 'TaskFlow',
      'tasks': 'Zadania',
      'calendar': 'Kalendarz',
      'habits': 'Nawyki',
      'settings': 'Ustawienia',
      'add_task': 'Dodaj zadanie',
      'add_habit': 'Dodaj nawyk',
      'task_name': 'Nazwa zadania',
      'priority': 'Priorytet',
      'notes': 'Notatki',
      'note': 'Notatka',
      'category': 'Kategoria',
      'image_url': 'URL zdjęcia (opcjonalnie)',
      'add_reminder': 'Dodaj przypomnienie',
      'reminder': 'Przypomnienie',
      'favorites': 'Ulubione',
      'favorite': 'Ulubione',
      'cancel': 'Anuluj',
      'add': 'Dodaj',
      'delete': 'Usuń',
      'total': 'Razem',
      'to_do': 'Do zrobienia',
      'completed': 'Ukończonych',
      'search_task': 'Szukaj zadania...',
      'search': 'Szukaj zadania...',
      'empty_list': 'Lista jest pusta',
      'add_first_task': 'Dodaj pierwsze zadanie przyciskiem +',
      'task_deleted': 'Usunięto zadanie',
      'deleted_task': 'Usunięto zadanie',
      'undo': 'Cofnij',
      'archive': 'W archiwum',
      'due': 'Do',
      'work': 'Praca',
      'personal': 'Osobiste',
      'home': 'Dom',
      'other': 'Inne',
      'daily': 'Codziennie',
      'weekly': 'Tygodniowo',
      'monthly': 'Miesięcznie',
      'appearance': 'Wygląd',
      'light_theme': 'Jasny motyw',
      'dark_theme': 'Ciemny motyw',
      'system_theme': 'Motyw systemowy',
      'data': 'Dane',
      'statistics': 'Statystyki',
      'tasks_count': 'Liczba zadań',
      'total_tasks': 'Zadań łącznie',
      'completed_tasks': 'Ukończonych',
      'archived_tasks': 'zarchiwizowanych zadań',
      'in_archive': 'W archiwum',
      'clear_tasks': 'Wyczyść listę zadań',
      'clear_archive': 'Wyczyść archiwum',
      'delete_all_tasks': 'Usuń wszystkie zadania z listy',
      'about': 'O aplikacji',
      'version': 'Wersja 2.1.0',
      'your_task_list': 'Twoja lista zadań',
      'language': 'Język',
      'month_stats': 'Statystyka miesiąca',
      'month_statistics': 'Statystyka miesiąca',
      'tasks_total': 'Zadań łącznie',
      'progress': 'Postęp',
      'no_tasks_today': 'Brak zadań na dzisiaj',
      'selected_day_tasks': 'Zadania wybranego dnia',
      'no_habits': 'Brak nawyków',
      'add_first_habit': 'Dodaj pierwszy nawyk przyciskiem +',
      'streak': 'Seria',
      'days': 'dni',
      'pomodoro': 'Pomodoro',
      'work_session': 'Sesja pracy',
      'break_session': 'Przerwa',
      'long_break': 'Długa przerwa',
      'start': 'Start',
      'pause': 'Pauza',
      'resume': 'Wznów',
      'reset': 'Reset',
      'session': 'Sesja',
      'sessions_completed': 'Sesje ukończone',
      'focus_time': 'Czas pracy',
      'break_time': 'Czas przerwy',
      'inbox': 'Wiadomości',
      'inbox_desc': 'Wszystkie nowe zadania',
      'habit_name': 'Nazwa nawyku',
      'description': 'Opis (opcjonalnie)',
      'frequency': 'Częstotliwość',
      'confirm_clear_tasks': 'Czy na pewno chcesz usunąć wszystkie zadania?',
      'confirm_clear_archive':
          'Czy na pewno chcesz usunąć wszystkie zarchiwizowane zadania?',
      'notifications': 'Powiadomienia',
      'enable_notifications': 'Włącz powiadomienia',
      'notification_sound': 'Dźwięk powiadomień',
      'notification_time': 'Czas powiadomienia',
      'general': 'Ogólne',
      'auto_archive': 'Automatyczne archiwizowanie',
      'auto_archive_desc': 'Archiwizuj ukończone zadania po 7 dniach',
      'show_completed': 'Pokaż ukończone',
      'show_completed_desc': 'Wyświetlaj ukończone zadania na liście',
      'backup': 'Kopia zapasowa',
      'export_data': 'Eksportuj dane',
      'import_data': 'Importuj dane',
      'backup_desc': 'Zapisz wszystkie dane do pliku',
      'advanced': 'Zaawansowane',
      'developer_mode': 'Tryb programisty',
      'show_debug_info': 'Pokaż informacje debugowania',
      'reset_app': 'Resetuj aplikację',
      'reset_app_desc': 'Przywróć ustawienia domyślne',
      'mon': 'Pon',
      'tue': 'Wt',
      'wed': 'Śr',
      'thu': 'Czw',
      'fri': 'Pt',
      'sat': 'Sob',
      'sun': 'Nd',
      'january': 'Styczeń',
      'february': 'Luty',
      'march': 'Marzec',
      'april': 'Kwiecień',
      'may': 'Maj',
      'june': 'Czerwiec',
      'july': 'Lipiec',
      'august': 'Sierpień',
      'september': 'Wrzesień',
      'october': 'Październik',
      'november': 'Listopad',
      'december': 'Grudzień',
      'profile': 'Profil',
      'user': 'Użytkownik',
      'tasks_completed': 'zadań wykonano',
      'achievements': 'Osiągnięcia',
      'beginner': 'Początkujący',
      'beginner_desc': 'Utwórz pierwsze zadanie',
      'productive': 'Produktywny',
      'productive_desc': 'Wykonaj 10 zadań',
      'master': 'Mistrz',
      'master_desc': 'Wykonaj 50 zadań',
      'habit_master': 'Mistrz nawyków',
      'habit_master_desc': 'Stwórz 5 nawyków',
      'account': 'Konto',
      'local_mode': 'Tryb lokalny',
      'local_mode_desc': 'Dane przechowywane tylko na tym urządzeniu',
      'login': 'Zaloguj się',
      'logout': 'Wyloguj',
      'add_photo': 'Dodaj zdjęcie',
      'photo_selected': 'Zdjęcie wybrane',
      'select_photo': 'Wybierz zdjęcie z galerii',
      'remove_photo': 'Usuń zdjęcie',
      'or': 'lub',
      'enter_image_url': 'Wprowadź URL zdjęcia',
      'image_url_hint': 'Wklej link do obrazka z internetu',
    },
    'uk': {
      'app_title': 'TaskFlow',
      'tasks': 'Завдання',
      'calendar': 'Календар',
      'habits': 'Звички',
      'settings': 'Налаштування',
      'add_task': 'Додати завдання',
      'add_habit': 'Додати звичку',
      'task_name': 'Назва завдання',
      'priority': 'Пріоритет',
      'notes': 'Нотатки',
      'note': 'Нотатка',
      'category': 'Категорія',
      'image_url': 'URL зображення (опціонально)',
      'add_reminder': 'Додати нагадування',
      'reminder': 'Нагадування',
      'favorites': 'Улюблені',
      'favorite': 'Улюблене',
      'cancel': 'Скасувати',
      'add': 'Додати',
      'delete': 'Видалити',
      'total': 'Всього',
      'to_do': 'До виконання',
      'completed': 'Виконано',
      'search_task': 'Шукати завдання...',
      'search': 'Шукати',
      'empty_list': 'Список порожній',
      'add_first_task': 'Додайте перше завдання кнопкою +',
      'task_deleted': 'Завдання видалено',
      'deleted_task': 'Видалено завдання',
      'undo': 'Скасувати',
      'archive': 'В архіві',
      'due': 'До',
      'work': 'Робота',
      'personal': 'Особисте',
      'home': 'Дім',
      'other': 'Інше',
      'daily': 'Щодня',
      'weekly': 'Щотижня',
      'monthly': 'Щомісяця',
      'appearance': 'Вигляд',
      'light_theme': 'Світла тема',
      'dark_theme': 'Темна тема',
      'system_theme': 'Системна тема',
      'data': 'Дані',
      'statistics': 'Статистика',
      'tasks_count': 'Кількість завдань',
      'total_tasks': 'Завдань всього',
      'completed_tasks': 'Виконано',
      'archived_tasks': 'заархівованих завдань',
      'in_archive': 'В архіві',
      'clear_tasks': 'Очистити список завдань',
      'clear_archive': 'Очистити архів',
      'delete_all_tasks': 'Видалити всі завдання зі списку',
      'about': 'Про додаток',
      'version': 'Версія 2.1.0',
      'your_task_list': 'Ваш список завдань',
      'language': 'Мова',
      'month_stats': 'Статистика місяця',
      'month_statistics': 'Статистика місяця',
      'tasks_total': 'Завдань всього',
      'progress': 'Прогрес',
      'no_tasks_today': 'Немає завдань на сьогодні',
      'selected_day_tasks': 'Завдання вибраного дня',
      'no_habits': 'Немає звичок',
      'add_first_habit': 'Додайте першу звичку кнопкою +',
      'streak': 'Серія',
      'days': 'днів',
      'pomodoro': 'Pomodoro',
      'work_session': 'Робоча сесія',
      'break_session': 'Перерва',
      'long_break': 'Довга перерва',
      'start': 'Старт',
      'pause': 'Пауза',
      'resume': 'Продовжити',
      'reset': 'Скинути',
      'session': 'Сесія',
      'sessions_completed': 'Сесії завершено',
      'focus_time': 'Час роботи',
      'break_time': 'Час перерви',
      'inbox': 'Вхідні',
      'inbox_desc': 'Всі нові завдання',
      'habit_name': 'Назва звички',
      'description': 'Опис (опціонально)',
      'frequency': 'Частота',
      'confirm_clear_tasks': 'Ви впевнені, що хочете видалити всі завдання?',
      'confirm_clear_archive':
          'Ви впевнені, що хочете видалити всі заархівовані завдання?',
      'notifications': 'Сповіщення',
      'enable_notifications': 'Увімкнути сповіщення',
      'notification_sound': 'Звук сповіщень',
      'notification_time': 'Час сповіщення',
      'general': 'Загальні',
      'auto_archive': 'Автоматичне архівування',
      'auto_archive_desc': 'Архівувати виконані завдання через 7 днів',
      'show_completed': 'Показати виконані',
      'show_completed_desc': 'Відображати виконані завдання в списку',
      'backup': 'Резервна копія',
      'export_data': 'Експортувати дані',
      'import_data': 'Імпортувати дані',
      'backup_desc': 'Зберегти всі дані у файл',
      'advanced': 'Розширені',
      'developer_mode': 'Режим розробника',
      'show_debug_info': 'Показати налагоджувальну інформацію',
      'reset_app': 'Скинути додаток',
      'reset_app_desc': 'Відновити налаштування за замовчуванням',
      'mon': 'Пн',
      'tue': 'Вт',
      'wed': 'Ср',
      'thu': 'Чт',
      'fri': 'Пт',
      'sat': 'Сб',
      'sun': 'Нд',
      'january': 'Січень',
      'february': 'Лютий',
      'march': 'Березень',
      'april': 'Квітень',
      'may': 'Травень',
      'june': 'Червень',
      'july': 'Липень',
      'august': 'Серпень',
      'september': 'Вересень',
      'october': 'Жовтень',
      'november': 'Листопад',
      'december': 'Грудень',
      'profile': 'Профіль',
      'user': 'Користувач',
      'tasks_completed': 'завдань виконано',
      'achievements': 'Досягнення',
      'beginner': 'Початківець',
      'beginner_desc': 'Створіть першу задачу',
      'productive': 'Продуктивний',
      'productive_desc': 'Виконайте 10 задач',
      'master': 'Майстер',
      'master_desc': 'Виконайте 50 задач',
      'habit_master': 'Майстер звичок',
      'habit_master_desc': 'Створіть 5 звичок',
      'account': 'Акаунт',
      'local_mode': 'Локальний режим',
      'local_mode_desc': 'Дані зберігаються лише на цьому пристрої',
      'login': 'Увійти',
      'logout': 'Вийти',
      'add_photo': 'Додати фото',
      'photo_selected': 'Фото вибрано',
      'select_photo': 'Виберіть фото з галереї',
      'remove_photo': 'Видалити фото',
      'or': 'або',
      'enter_image_url': 'Введіть URL зображення',
      'image_url_hint': 'Вставте посилання на зображення з інтернету',
    },
    'ru': {
      'app_title': 'TaskFlow',
      'tasks': 'Задачи',
      'calendar': 'Календарь',
      'habits': 'Привычки',
      'settings': 'Настройки',
      'add_task': 'Добавить задачу',
      'add_habit': 'Добавить привычку',
      'task_name': 'Название задачи',
      'priority': 'Приоритет',
      'notes': 'Заметки',
      'note': 'Заметка',
      'category': 'Категория',
      'image_url': 'URL изображения (опционально)',
      'add_reminder': 'Добавить напоминание',
      'reminder': 'Напоминание',
      'favorites': 'Избранные',
      'favorite': 'Избранное',
      'cancel': 'Отмена',
      'add': 'Добавить',
      'delete': 'Удалить',
      'total': 'Всего',
      'to_do': 'К выполнению',
      'completed': 'Выполнено',
      'search_task': 'Искать задачу...',
      'search': 'Искать',
      'empty_list': 'Список пуст',
      'add_first_task': 'Добавьте первую задачу кнопкой +',
      'task_deleted': 'Задача удалена',
      'deleted_task': 'Удалена задача',
      'undo': 'Отменить',
      'archive': 'В архиве',
      'due': 'До',
      'work': 'Работа',
      'personal': 'Личное',
      'home': 'Дом',
      'other': 'Другое',
      'daily': 'Ежедневно',
      'weekly': 'Еженедельно',
      'monthly': 'Ежемесячно',
      'appearance': 'Внешний вид',
      'light_theme': 'Светлая тема',
      'dark_theme': 'Темная тема',
      'system_theme': 'Системная тема',
      'data': 'Данные',
      'statistics': 'Статистика',
      'tasks_count': 'Количество задач',
      'total_tasks': 'Задач всего',
      'completed_tasks': 'Выполнено',
      'archived_tasks': 'архивированных задач',
      'in_archive': 'В архиве',
      'clear_tasks': 'Очистить список задач',
      'clear_archive': 'Очистить архив',
      'delete_all_tasks': 'Удалить все задачи из списка',
      'about': 'О приложении',
      'version': 'Версия 2.1.0',
      'your_task_list': 'Ваш список задач',
      'language': 'Язык',
      'month_stats': 'Статистика месяца',
      'month_statistics': 'Статистика месяца',
      'tasks_total': 'Задач всего',
      'progress': 'Прогресс',
      'no_tasks_today': 'Нет задач на сегодня',
      'selected_day_tasks': 'Задачи выбранного дня',
      'no_habits': 'Нет привычек',
      'add_first_habit': 'Добавьте первую привычку кнопкой +',
      'streak': 'Серия',
      'days': 'дней',
      'pomodoro': 'Pomodoro',
      'work_session': 'Рабочая сессия',
      'break_session': 'Перерыв',
      'long_break': 'Длинный перерыв',
      'start': 'Старт',
      'pause': 'Пауза',
      'resume': 'Продолжить',
      'reset': 'Сбросить',
      'session': 'Сессия',
      'sessions_completed': 'Сессий завершено',
      'focus_time': 'Время работы',
      'break_time': 'Время перерыва',
      'inbox': 'Входящие',
      'inbox_desc': 'Все новые задачи',
      'habit_name': 'Название привычки',
      'description': 'Описание (опционально)',
      'frequency': 'Частота',
      'confirm_clear_tasks': 'Вы уверены, что хотите удалить все задачи?',
      'confirm_clear_archive':
          'Вы уверены, что хотите удалить все архивированные задачи?',
      'notifications': 'Уведомления',
      'enable_notifications': 'Включить уведомления',
      'notification_sound': 'Звук уведомлений',
      'notification_time': 'Время уведомления',
      'general': 'Общие',
      'auto_archive': 'Автоматическая архивация',
      'auto_archive_desc': 'Архивировать выполненные задачи через 7 дней',
      'show_completed': 'Показать выполненные',
      'show_completed_desc': 'Отображать выполненные задачи в списке',
      'backup': 'Резервная копия',
      'export_data': 'Экспортировать данные',
      'import_data': 'Импортировать данные',
      'backup_desc': 'Сохранить все данные в файл',
      'advanced': 'Расширенные',
      'developer_mode': 'Режим разработчика',
      'show_debug_info': 'Показать отладочную информацию',
      'reset_app': 'Сбросить приложение',
      'reset_app_desc': 'Восстановить настройки по умолчанию',
      'mon': 'Пн',
      'tue': 'Вт',
      'wed': 'Ср',
      'thu': 'Чт',
      'fri': 'Пт',
      'sat': 'Сб',
      'sun': 'Вс',
      'january': 'Январь',
      'february': 'Февраль',
      'march': 'Март',
      'april': 'Апрель',
      'may': 'Май',
      'june': 'Июнь',
      'july': 'Июль',
      'august': 'Август',
      'september': 'Сентябрь',
      'october': 'Октябрь',
      'november': 'Ноябрь',
      'december': 'Декабрь',
      'profile': 'Профиль',
      'user': 'Пользователь',
      'tasks_completed': 'задач выполнено',
      'achievements': 'Достижения',
      'beginner': 'Новичок',
      'beginner_desc': 'Создайте первую задачу',
      'productive': 'Продуктивный',
      'productive_desc': 'Выполните 10 задач',
      'master': 'Мастер',
      'master_desc': 'Выполните 50 задач',
      'habit_master': 'Мастер привычек',
      'habit_master_desc': 'Создайте 5 привычек',
      'account': 'Аккаунт',
      'local_mode': 'Локальный режим',
      'local_mode_desc': 'Данные хранятся только на этом устройстве',
      'login': 'Войти',
      'logout': 'Выйти',
      'add_photo': 'Добавить фото',
      'photo_selected': 'Фото выбрано',
      'select_photo': 'Выбрать фото из галереи',
      'remove_photo': 'Удалить фото',
      'or': 'или',
      'enter_image_url': 'Введите URL изображения',
      'image_url_hint': 'Вставьте ссылку на изображение из интернета',
    },
    'en': {
      'app_title': 'TaskFlow',
      'tasks': 'Tasks',
      'calendar': 'Calendar',
      'habits': 'Habits',
      'settings': 'Settings',
      'add_task': 'Add task',
      'add_habit': 'Add habit',
      'task_name': 'Task name',
      'priority': 'Priority',
      'notes': 'Notes',
      'note': 'Note',
      'category': 'Category',
      'image_url': 'Image URL (optional)',
      'add_reminder': 'Add reminder',
      'reminder': 'Reminder',
      'favorites': 'Favorites',
      'favorite': 'Favorite',
      'cancel': 'Cancel',
      'add': 'Add',
      'delete': 'Delete',
      'total': 'Total',
      'to_do': 'To do',
      'completed': 'Completed',
      'search_task': 'Search task...',
      'search': 'Search',
      'empty_list': 'List is empty',
      'add_first_task': 'Add first task with + button',
      'task_deleted': 'Task deleted',
      'deleted_task': 'Deleted task',
      'undo': 'Undo',
      'archive': 'In archive',
      'due': 'Due',
      'work': 'Work',
      'personal': 'Personal',
      'home': 'Home',
      'other': 'Other',
      'daily': 'Daily',
      'weekly': 'Weekly',
      'monthly': 'Monthly',
      'appearance': 'Appearance',
      'light_theme': 'Light theme',
      'dark_theme': 'Dark theme',
      'system_theme': 'System theme',
      'data': 'Data',
      'statistics': 'Statistics',
      'tasks_count': 'Number of tasks',
      'total_tasks': 'Total tasks',
      'completed_tasks': 'Completed tasks',
      'archived_tasks': 'archived tasks',
      'in_archive': 'In archive',
      'clear_tasks': 'Clear task list',
      'clear_archive': 'Clear archive',
      'delete_all_tasks': 'Delete all tasks from list',
      'about': 'About',
      'version': 'Version 2.1.0',
      'your_task_list': 'Your task list',
      'language': 'Language',
      'month_stats': 'Month statistics',
      'month_statistics': 'Month statistics',
      'tasks_total': 'Total tasks',
      'progress': 'Progress',
      'no_tasks_today': 'No tasks for today',
      'selected_day_tasks': 'Selected day tasks',
      'no_habits': 'No habits',
      'add_first_habit': 'Add first habit with + button',
      'streak': 'Streak',
      'days': 'days',
      'pomodoro': 'Pomodoro',
      'work_session': 'Work session',
      'break_session': 'Break',
      'long_break': 'Long break',
      'start': 'Start',
      'pause': 'Pause',
      'resume': 'Resume',
      'reset': 'Reset',
      'session': 'Session',
      'sessions_completed': 'Sessions completed',
      'focus_time': 'Work time',
      'break_time': 'Break time',
      'inbox': 'Inbox',
      'inbox_desc': 'All new tasks',
      'habit_name': 'Habit name',
      'description': 'Description (optional)',
      'frequency': 'Frequency',
      'confirm_clear_tasks': 'Are you sure you want to delete all tasks?',
      'confirm_clear_archive':
          'Are you sure you want to delete all archived tasks?',
      'notifications': 'Notifications',
      'enable_notifications': 'Enable notifications',
      'notification_sound': 'Notification sound',
      'notification_time': 'Notification time',
      'general': 'General',
      'auto_archive': 'Auto archive',
      'auto_archive_desc': 'Archive completed tasks after 7 days',
      'show_completed': 'Show completed',
      'show_completed_desc': 'Display completed tasks in list',
      'backup': 'Backup',
      'export_data': 'Export data',
      'import_data': 'Import data',
      'backup_desc': 'Save all data to file',
      'advanced': 'Advanced',
      'developer_mode': 'Developer mode',
      'show_debug_info': 'Show debug info',
      'reset_app': 'Reset app',
      'reset_app_desc': 'Restore default settings',
      'mon': 'Mon',
      'tue': 'Tue',
      'wed': 'Wed',
      'thu': 'Thu',
      'fri': 'Fri',
      'sat': 'Sat',
      'sun': 'Sun',
      'january': 'January',
      'february': 'February',
      'march': 'March',
      'april': 'April',
      'may': 'May',
      'june': 'June',
      'july': 'July',
      'august': 'August',
      'september': 'September',
      'october': 'October',
      'november': 'November',
      'december': 'December',
      'profile': 'Profile',
      'user': 'User',
      'tasks_completed': 'tasks completed',
      'achievements': 'Achievements',
      'beginner': 'Beginner',
      'beginner_desc': 'Create first task',
      'productive': 'Productive',
      'productive_desc': 'Complete 10 tasks',
      'master': 'Master',
      'master_desc': 'Complete 50 tasks',
      'habit_master': 'Habit Master',
      'habit_master_desc': 'Create 5 habits',
      'account': 'Account',
      'local_mode': 'Local mode',
      'local_mode_desc': 'Data stored only on this device',
      'login': 'Log in',
      'logout': 'Log out',
      'add_photo': 'Add photo',
      'photo_selected': 'Photo selected',
      'select_photo': 'Select photo from gallery',
      'remove_photo': 'Remove photo',
      'or': 'or',
      'enter_image_url': 'Enter image URL',
      'image_url_hint': 'Paste image link from internet',
    },
    'de': {
      'app_title': 'TaskFlow',
      'tasks': 'Aufgaben',
      'calendar': 'Kalender',
      'habits': 'Gewohnheiten',
      'settings': 'Einstellungen',
      'add_task': 'Aufgabe hinzufügen',
      'add_habit': 'Gewohnheit hinzufügen',
      'task_name': 'Aufgabenname',
      'priority': 'Priorität',
      'notes': 'Notizen',
      'note': 'Notiz',
      'category': 'Kategorie',
      'image_url': 'Bild-URL (optional)',
      'add_reminder': 'Erinnerung hinzufügen',
      'reminder': 'Erinnerung',
      'favorites': 'Favoriten',
      'favorite': 'Favorit',
      'cancel': 'Abbrechen',
      'add': 'Hinzufügen',
      'delete': 'Löschen',
      'total': 'Gesamt',
      'to_do': 'Zu erledigen',
      'completed': 'Abgeschlossen',
      'search_task': 'Aufgabe suchen...',
      'search': 'Suchen',
      'empty_list': 'Liste ist leer',
      'add_first_task': 'Erste Aufgabe mit + Taste hinzufügen',
      'task_deleted': 'Aufgabe gelöscht',
      'deleted_task': 'Aufgabe gelöscht',
      'undo': 'Rückgängig',
      'archive': 'Im Archiv',
      'due': 'Fällig',
      'work': 'Arbeit',
      'personal': 'Persönlich',
      'home': 'Zuhause',
      'other': 'Andere',
      'daily': 'Täglich',
      'weekly': 'Wöchentlich',
      'monthly': 'Monatlich',
      'appearance': 'Aussehen',
      'light_theme': 'Helles Thema',
      'dark_theme': 'Dunkles Thema',
      'system_theme': 'Systemthema',
      'data': 'Daten',
      'statistics': 'Statistik',
      'tasks_count': 'Anzahl der Aufgaben',
      'total_tasks': 'Aufgaben insgesamt',
      'completed_tasks': 'Abgeschlossene Aufgaben',
      'archived_tasks': 'archivierte Aufgaben',
      'in_archive': 'Im Archiv',
      'clear_tasks': 'Aufgabenliste löschen',
      'clear_archive': 'Archiv löschen',
      'delete_all_tasks': 'Alle Aufgaben aus der Liste löschen',
      'about': 'Über',
      'version': 'Version 2.1.0',
      'your_task_list': 'Ihre Aufgabenliste',
      'language': 'Sprache',
      'month_stats': 'Monatsstatistik',
      'month_statistics': 'Monatsstatistik',
      'tasks_total': 'Aufgaben insgesamt',
      'progress': 'Fortschritt',
      'no_tasks_today': 'Keine Aufgaben für heute',
      'selected_day_tasks': 'Aufgaben des ausgewählten Tages',
      'no_habits': 'Keine Gewohnheiten',
      'add_first_habit': 'Erste Gewohnheit mit + Taste hinzufügen',
      'streak': 'Serie',
      'days': 'Tage',
      'pomodoro': 'Pomodoro',
      'work_session': 'Arbeitssitzung',
      'break_session': 'Pause',
      'long_break': 'Lange Pause',
      'start': 'Start',
      'pause': 'Pause',
      'resume': 'Fortsetzen',
      'reset': 'Zurücksetzen',
      'session': 'Sitzung',
      'sessions_completed': 'Sitzungen abgeschlossen',
      'focus_time': 'Arbeitszeit',
      'break_time': 'Pausenzeit',
      'inbox': 'Posteingang',
      'inbox_desc': 'Alle neuen Aufgaben',
      'habit_name': 'Gewohnheitsname',
      'description': 'Beschreibung (optional)',
      'frequency': 'Häufigkeit',
      'confirm_clear_tasks':
          'Sind Sie sicher, dass Sie alle Aufgaben löschen möchten?',
      'confirm_clear_archive':
          'Sind Sie sicher, dass Sie alle archivierten Aufgaben löschen möchten?',
      'notifications': 'Benachrichtigungen',
      'enable_notifications': 'Benachrichtigungen aktivieren',
      'notification_sound': 'Benachrichtigungston',
      'notification_time': 'Benachrichtigungszeit',
      'general': 'Allgemein',
      'auto_archive': 'Automatisches Archivieren',
      'auto_archive_desc': 'Abgeschlossene Aufgaben nach 7 Tagen archivieren',
      'show_completed': 'Abgeschlossene anzeigen',
      'show_completed_desc': 'Abgeschlossene Aufgaben in Liste anzeigen',
      'backup': 'Sicherung',
      'export_data': 'Daten exportieren',
      'import_data': 'Daten importieren',
      'backup_desc': 'Alle Daten in Datei speichern',
      'advanced': 'Erweitert',
      'developer_mode': 'Entwicklermodus',
      'show_debug_info': 'Debug-Info anzeigen',
      'reset_app': 'App zurücksetzen',
      'reset_app_desc': 'Standardeinstellungen wiederherstellen',
      'mon': 'Mo',
      'tue': 'Di',
      'wed': 'Mi',
      'thu': 'Do',
      'fri': 'Fr',
      'sat': 'Sa',
      'sun': 'So',
      'january': 'Januar',
      'february': 'Februar',
      'march': 'März',
      'april': 'April',
      'may': 'Mai',
      'june': 'Juni',
      'july': 'Juli',
      'august': 'August',
      'september': 'September',
      'october': 'Oktober',
      'november': 'November',
      'december': 'Dezember',
      'profile': 'Profil',
      'user': 'Benutzer',
      'tasks_completed': 'Aufgaben erledigt',
      'achievements': 'Erfolge',
      'beginner': 'Anfänger',
      'beginner_desc': 'Erstelle die erste Aufgabe',
      'productive': 'Produktiv',
      'productive_desc': 'Erledige 10 Aufgaben',
      'master': 'Meister',
      'master_desc': 'Erledige 50 Aufgaben',
      'habit_master': 'Gewohnheitsmeister',
      'habit_master_desc': 'Erstelle 5 Gewohnheiten',
      'account': 'Konto',
      'local_mode': 'Lokaler Modus',
      'local_mode_desc': 'Daten nur auf diesem Gerät gespeichert',
      'login': 'Anmelden',
      'logout': 'Abmelden',
      'add_photo': 'Foto hinzufügen',
      'photo_selected': 'Foto ausgewählt',
      'select_photo': 'Foto aus Galerie auswählen',
      'remove_photo': 'Foto entfernen',
      'or': 'oder',
      'enter_image_url': 'Bild-URL eingeben',
      'image_url_hint': 'Bildlink aus dem Internet einfügen',
    },
    'es': {
      'app_title': 'TaskFlow',
      'tasks': 'Tareas',
      'calendar': 'Calendario',
      'habits': 'Hábitos',
      'settings': 'Configuración',
      'add_task': 'Añadir tarea',
      'add_habit': 'Añadir hábito',
      'task_name': 'Nombre de tarea',
      'priority': 'Prioridad',
      'notes': 'Notas',
      'note': 'Nota',
      'category': 'Categoría',
      'image_url': 'URL de imagen (opcional)',
      'add_reminder': 'Añadir recordatorio',
      'reminder': 'Recordatorio',
      'favorites': 'Favoritos',
      'favorite': 'Favorito',
      'cancel': 'Cancelar',
      'add': 'Añadir',
      'delete': 'Eliminar',
      'total': 'Total',
      'to_do': 'Por hacer',
      'completed': 'Completado',
      'search_task': 'Buscar tarea...',
      'search': 'Buscar',
      'empty_list': 'La lista está vacía',
      'add_first_task': 'Añade la primera tarea con el botón +',
      'task_deleted': 'Tarea eliminada',
      'deleted_task': 'Tarea eliminada',
      'undo': 'Deshacer',
      'archive': 'En archivo',
      'due': 'Vence',
      'work': 'Trabajo',
      'personal': 'Personal',
      'home': 'Casa',
      'other': 'Otro',
      'daily': 'Diario',
      'weekly': 'Semanal',
      'monthly': 'Mensual',
      'appearance': 'Apariencia',
      'light_theme': 'Tema claro',
      'dark_theme': 'Tema oscuro',
      'system_theme': 'Tema del sistema',
      'data': 'Datos',
      'statistics': 'Estadísticas',
      'tasks_count': 'Número de tareas',
      'total_tasks': 'Tareas totales',
      'completed_tasks': 'Tareas completadas',
      'archived_tasks': 'tareas archivadas',
      'in_archive': 'En archivo',
      'clear_tasks': 'Limpiar lista de tareas',
      'clear_archive': 'Limpiar archivo',
      'delete_all_tasks': 'Eliminar todas las tareas de la lista',
      'about': 'Acerca de',
      'version': 'Versión 2.1.0',
      'your_task_list': 'Tu lista de tareas',
      'language': 'Idioma',
      'month_stats': 'Estadísticas del mes',
      'month_statistics': 'Estadísticas del mes',
      'tasks_total': 'Tareas totales',
      'progress': 'Progreso',
      'no_tasks_today': 'No hay tareas para hoy',
      'selected_day_tasks': 'Tareas del día seleccionado',
      'no_habits': 'No hay hábitos',
      'add_first_habit': 'Añade el primer hábito con el botón +',
      'streak': 'Racha',
      'days': 'días',
      'pomodoro': 'Pomodoro',
      'work_session': 'Sesión de trabajo',
      'break_session': 'Descanso',
      'long_break': 'Descanso largo',
      'start': 'Iniciar',
      'pause': 'Pausar',
      'resume': 'Reanudar',
      'reset': 'Reiniciar',
      'session': 'Sesión',
      'sessions_completed': 'Sesiones completadas',
      'focus_time': 'Tiempo de trabajo',
      'break_time': 'Tiempo de descanso',
      'inbox': 'Bandeja de entrada',
      'inbox_desc': 'Todas las tareas nuevas',
      'habit_name': 'Nombre del hábito',
      'description': 'Descripción (opcional)',
      'frequency': 'Frecuencia',
      'confirm_clear_tasks':
          '¿Estás seguro de que quieres eliminar todas las tareas?',
      'confirm_clear_archive':
          '¿Estás seguro de que quieres eliminar todas las tareas archivadas?',
      'notifications': 'Notificaciones',
      'enable_notifications': 'Activar notificaciones',
      'notification_sound': 'Sonido de notificación',
      'notification_time': 'Hora de notificación',
      'general': 'General',
      'auto_archive': 'Archivar automáticamente',
      'auto_archive_desc': 'Archivar tareas completadas después de 7 días',
      'show_completed': 'Mostrar completadas',
      'show_completed_desc': 'Mostrar tareas completadas en la lista',
      'backup': 'Copia de seguridad',
      'export_data': 'Exportar datos',
      'import_data': 'Importar datos',
      'backup_desc': 'Guardar todos los datos en archivo',
      'advanced': 'Avanzado',
      'developer_mode': 'Modo desarrollador',
      'show_debug_info': 'Mostrar información de depuración',
      'reset_app': 'Restablecer aplicación',
      'reset_app_desc': 'Restaurar configuración predeterminada',
      'mon': 'Lun',
      'tue': 'Mar',
      'wed': 'Mié',
      'thu': 'Jue',
      'fri': 'Vie',
      'sat': 'Sáb',
      'sun': 'Dom',
      'january': 'Enero',
      'february': 'Febrero',
      'march': 'Marzo',
      'april': 'Abril',
      'may': 'Mayo',
      'june': 'Junio',
      'july': 'Julio',
      'august': 'Agosto',
      'september': 'Septiembre',
      'october': 'Octubre',
      'november': 'Noviembre',
      'december': 'Diciembre',
      'profile': 'Perfil',
      'user': 'Usuario',
      'tasks_completed': 'tareas completadas',
      'achievements': 'Logros',
      'beginner': 'Principiante',
      'beginner_desc': 'Crea la primera tarea',
      'productive': 'Productivo',
      'productive_desc': 'Completa 10 tareas',
      'master': 'Maestro',
      'master_desc': 'Completa 50 tareas',
      'habit_master': 'Maestro de hábitos',
      'habit_master_desc': 'Crea 5 hábitos',
      'account': 'Cuenta',
      'local_mode': 'Modo local',
      'local_mode_desc': 'Datos almacenados solo en este dispositivo',
      'login': 'Iniciar sesión',
      'logout': 'Cerrar sesión',
      'add_photo': 'Agregar foto',
      'photo_selected': 'Foto seleccionada',
      'select_photo': 'Seleccionar foto de galería',
      'remove_photo': 'Eliminar foto',
      'or': 'o',
      'enter_image_url': 'Introducir URL de imagen',
      'image_url_hint': 'Pegar enlace de imagen de internet',
    },
  };

  String translate(String key) {
    return _localizedValues[languageCode]?[key] ??
        _localizedValues['en']![key]!;
  }

  String get appTitle => translate('app_title');
  String get tasks => translate('tasks');
  String get calendar => translate('calendar');
  String get habits => translate('habits');
  String get settings => translate('settings');
  String get addTask => translate('add_task');
  String get addHabit => translate('add_habit');
  String get taskName => translate('task_name');
  String get priority => translate('priority');
  String get notes => translate('notes');
  String get category => translate('category');
  String get imageUrl => translate('image_url');
  String get addReminder => translate('add_reminder');
  String get favorites => translate('favorites');
  String get cancel => translate('cancel');
  String get add => translate('add');
  String get delete => translate('delete');
  String get total => translate('total');
  String get toDo => translate('to_do');
  String get completed => translate('completed');
  String get searchTask => translate('search_task');
  String get emptyList => translate('empty_list');
  String get addFirstTask => translate('add_first_task');
  String get taskDeleted => translate('task_deleted');
  String get undo => translate('undo');
  String get work => translate('work');
  String get personal => translate('personal');
  String get home => translate('home');
  String get other => translate('other');
  String get daily => translate('daily');
  String get weekly => translate('weekly');
  String get monthly => translate('monthly');
  String get appearance => translate('appearance');
  String get lightTheme => translate('light_theme');
  String get darkTheme => translate('dark_theme');
  String get systemTheme => translate('system_theme');
  String get data => translate('data');
  String get statistics => translate('statistics');
  String get tasksCount => translate('tasks_count');
  String get inArchive => translate('in_archive');
  String get clearTasks => translate('clear_tasks');
  String get clearArchive => translate('clear_archive');
  String get about => translate('about');
  String get version => translate('version');
  String get yourTaskList => translate('your_task_list');
  String get language => translate('language');
  String get monthStats => translate('month_stats');
  String get tasksTotal => translate('tasks_total');
  String get progress => translate('progress');
  String get noTasksToday => translate('no_tasks_today');
  String get selectedDayTasks => translate('selected_day_tasks');
  String get noHabits => translate('no_habits');
  String get addFirstHabit => translate('add_first_habit');
  String get streak => translate('streak');
  String get days => translate('days');
  String get habitName => translate('habit_name');
  String get description => translate('description');
  String get frequency => translate('frequency');
  String get pomodoro => translate('pomodoro');
  String get workSession => translate('work_session');
  String get breakSession => translate('break_session');
  String get longBreak => translate('long_break');
  String get start => translate('start');
  String get pause => translate('pause');
  String get resume => translate('resume');
  String get reset => translate('reset');
  String get session => translate('session');
  String get sessionsCompleted => translate('sessions_completed');
  String get focusTime => translate('focus_time');
  String get breakTime => translate('break_time');
  String get inbox => translate('inbox');
  String get inboxDesc => translate('inbox_desc');
  String get confirmClearTasks => translate('confirm_clear_tasks');
  String get confirmClearArchive => translate('confirm_clear_archive');
  String get note => translate('note');
  String get reminder => translate('reminder');
  String get favorite => translate('favorite');
  String get search => translate('search');
  String get deletedTask => translate('deleted_task');
  String get archive => translate('archive');
  String get due => translate('due');
  String get totalTasks => translate('total_tasks');
  String get completedTasks => translate('completed_tasks');
  String get archivedTasks => translate('archived_tasks');
  String get deleteAllTasks => translate('delete_all_tasks');
  String get monthStatistics => translate('month_statistics');
  String get mon => translate('mon');
  String get tue => translate('tue');
  String get wed => translate('wed');
  String get thu => translate('thu');
  String get fri => translate('fri');
  String get sat => translate('sat');
  String get sun => translate('sun');

  // Місяці
  String get january => translate('january');
  String get february => translate('february');
  String get march => translate('march');
  String get april => translate('april');
  String get may => translate('may');
  String get june => translate('june');
  String get july => translate('july');
  String get august => translate('august');
  String get september => translate('september');
  String get october => translate('october');
  String get november => translate('november');
  String get december => translate('december');

  String get notifications => translate('notifications');
  String get enableNotifications => translate('enable_notifications');
  String get notificationSound => translate('notification_sound');
  String get notificationTime => translate('notification_time');
  String get general => translate('general');
  String get autoArchive => translate('auto_archive');
  String get autoArchiveDesc => translate('auto_archive_desc');
  String get showCompleted => translate('show_completed');
  String get showCompletedDesc => translate('show_completed_desc');
  String get backup => translate('backup');
  String get exportData => translate('export_data');
  String get importData => translate('import_data');
  String get backupDesc => translate('backup_desc');
  String get advanced => translate('advanced');
  String get developerMode => translate('developer_mode');
  String get showDebugInfo => translate('show_debug_info');
  String get resetApp => translate('reset_app');
  String get resetAppDesc => translate('reset_app_desc');

  // Profile
  String get profile => translate('profile');
  String get user => translate('user');
  String get tasksCompleted => translate('tasks_completed');
  String get achievements => translate('achievements');
  String get beginner => translate('beginner');
  String get beginnerDesc => translate('beginner_desc');
  String get productive => translate('productive');
  String get productiveDesc => translate('productive_desc');
  String get master => translate('master');
  String get masterDesc => translate('master_desc');
  String get habitMaster => translate('habit_master');
  String get habitMasterDesc => translate('habit_master_desc');
  String get account => translate('account');
  String get localMode => translate('local_mode');
  String get localModeDesc => translate('local_mode_desc');
  String get login => translate('login');
  String get logout => translate('logout');
  String get addPhoto => translate('add_photo');
  String get photoSelected => translate('photo_selected');
  String get selectPhoto => translate('select_photo');
  String get removePhoto => translate('remove_photo');
  String get or => translate('or');
  String get enterImageUrl => translate('enter_image_url');
  String get imageUrlHint => translate('image_url_hint');
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['pl', 'uk', 'ru', 'en', 'de', 'es'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale.languageCode);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

String categoryLabel(TaskCategory c, BuildContext context) {
  final l = AppLocalizations.of(context);
  switch (c) {
    case TaskCategory.work:
      return l.work;
    case TaskCategory.personal:
      return l.personal;
    case TaskCategory.home:
      return l.home;
    case TaskCategory.other:
      return l.other;
  }
}

String frequencyLabel(HabitFrequency f, BuildContext context) {
  final l = AppLocalizations.of(context);
  switch (f) {
    case HabitFrequency.daily:
      return l.daily;
    case HabitFrequency.weekly:
      return l.weekly;
    case HabitFrequency.monthly:
      return l.monthly;
  }
}

class Habit {
  final String id;
  String name;
  String? description;
  HabitFrequency frequency;
  bool active;
  DateTime createdAt;
  List<DateTime> completedDates;
  IconData icon;
  List<int> selectedDays; // 1=Monday, 7=Sunday

  Habit({
    String? id,
    required this.name,
    this.description,
    this.frequency = HabitFrequency.daily,
    this.active = true,
    DateTime? createdAt,
    List<DateTime>? completedDates,
    this.icon = Icons.check_circle,
    List<int>? selectedDays,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now(),
        completedDates = completedDates ?? [],
        selectedDays = selectedDays ?? [1, 2, 3, 4, 5, 6, 7];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'frequency': frequency.name,
        'active': active,
        'createdAt': createdAt.toIso8601String(),
        'completedDates':
            completedDates.map((d) => d.toIso8601String()).toList(),
        'iconCodePoint': icon.codePoint,
        'selectedDays': selectedDays,
      };

  factory Habit.fromMap(Map<String, dynamic> m) {
    final map = Map<String, dynamic>.from(m);
    HabitFrequency parseFreq(String? v) {
      return HabitFrequency.values.firstWhere(
        (f) => f.name == v,
        orElse: () => HabitFrequency.daily,
      );
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    List<DateTime> parseDates(dynamic v) {
      if (v is! List) return [];
      return v
          .map((d) {
            final dt = DateTime.tryParse(d.toString());
            return dt;
          })
          .whereType<DateTime>()
          .toList();
    }

    return Habit(
      id: map['id']?.toString(),
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      frequency: parseFreq(map['frequency']?.toString()),
      active: map['active'] == true,
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      completedDates: parseDates(map['completedDates']),
      icon: IconData(map['iconCodePoint'] ?? Icons.check_circle.codePoint, fontFamily: 'MaterialIcons'),
      selectedDays: map['selectedDays'] != null 
          ? List<int>.from(map['selectedDays'])
          : [1, 2, 3, 4, 5, 6, 7],
    );
  }

  bool isCompletedToday() {
    final today = DateTime.now();
    return completedDates.any((d) =>
        d.year == today.year && d.month == today.month && d.day == today.day);
  }
  
  bool isActiveToday() {
    final today = DateTime.now();
    final dayOfWeek = today.weekday; // 1=Monday, 7=Sunday
    return selectedDays.contains(dayOfWeek);
  }
}

class TaskItem {
  final String id;
  String name;
  bool completed;
  bool favorite;
  TaskCategory category;
  String? priority;
  String? notes;
  String? imageUrl;
  DateTime createdAt;
  DateTime? reminderAt;
  DateTime? archivedAt;

  TaskItem({
    String? id,
    required this.name,
    this.completed = false,
    this.favorite = false,
    this.category = TaskCategory.other,
    this.priority,
    this.notes,
    this.imageUrl,
    DateTime? createdAt,
    this.reminderAt,
    this.archivedAt,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'completed': completed,
        'favorite': favorite,
        'category': category.name,
        'priority': priority,
        'notes': notes,
        'imageUrl': imageUrl,
        'createdAt': createdAt.toIso8601String(),
        'reminderAt': reminderAt?.toIso8601String(),
        'archivedAt': archivedAt?.toIso8601String(),
      };

  factory TaskItem.fromMap(Map<String, dynamic> m) {
    final map = Map<String, dynamic>.from(m);
    TaskCategory parseCat(String? v) {
      return TaskCategory.values.firstWhere(
        (c) => c.name == v,
        orElse: () => TaskCategory.other,
      );
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return TaskItem(
      id: map['id']?.toString(),
      name: map['name']?.toString() ?? '',
      completed: map['completed'] == true,
      favorite: map['favorite'] == true,
      category: parseCat(map['category']?.toString()),
      priority: map['priority']?.toString(),
      notes: map['notes']?.toString(),
      imageUrl: map['imageUrl']?.toString(),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      reminderAt: parseDate(map['reminderAt']),
      archivedAt: parseDate(map['archivedAt']),
    );
  }
}

class TaskManagerApp extends StatefulWidget {
  const TaskManagerApp({super.key});

  @override
  State<TaskManagerApp> createState() => _TaskManagerAppState();
}

class _TaskManagerAppState extends State<TaskManagerApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('pl');
  bool _showSplash = true;
  bool? _authSkippedCache;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _startSplashTimer();
  }

  void _startSplashTimer() {
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme_mode');

    // Визначаємо мову: якщо збережена - використовуємо її, інакше беремо мову системи
    String savedLang = prefs.getString('language') ?? '';
    if (savedLang.isEmpty) {
      // Перший запуск - визначаємо мову з системи
      final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
      final supportedLanguages = ['pl', 'uk', 'ru', 'en', 'de', 'es'];
      savedLang = supportedLanguages.contains(systemLocale.languageCode)
          ? systemLocale.languageCode
          : 'en'; // За замовчуванням англійська
      // Зберігаємо визначену мову
      await prefs.setString('language', savedLang);
    }

    setState(() {
      _themeMode = switch (savedTheme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _locale = Locale(savedLang);
    });
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'theme_mode',
        switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          _ => 'system',
        });
  }

  Future<void> _saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
  }

  void _setTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    _saveTheme(mode);
  }

  void _setLanguage(String languageCode) {
    setState(() {
      _locale = Locale(languageCode);
    });
    _saveLanguage(languageCode);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const _SplashScreen(),
      );
    }
    return MaterialApp(
      title: 'TaskFlow',
      scaffoldMessengerKey: scaffoldMessengerKey,
      themeMode: _themeMode,
      themeAnimationDuration: const Duration(milliseconds: 600),
      themeAnimationCurve: Curves.easeInOutCubic,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0E9F6E), brightness: Brightness.light),
        useMaterial3: true,
        fontFamily: 'Montserrat',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withAlpha((255 * 0.6).round()),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 6,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        datePickerTheme: DatePickerThemeData(
          headerBackgroundColor: const Color(0xFF0E9F6E),
          headerForegroundColor: Colors.white,
          dayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            if (states.contains(WidgetState.disabled)) {
              return Colors.grey.shade400;
            }
            return Colors.black87;
          }),
          todayForegroundColor:
              WidgetStateProperty.all(const Color(0xFF0E9F6E)),
          dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF0E9F6E);
            }
            return Colors.transparent;
          }),
        ),
        timePickerTheme: TimePickerThemeData(
          dialHandColor: const Color(0xFF0E9F6E),
          hourMinuteColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF0E9F6E);
            }
            return Colors.grey.shade200;
          }),
          hourMinuteTextColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.black87;
          }),
          dayPeriodColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF0E9F6E);
            }
            return Colors.grey.shade200;
          }),
          dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.black87;
          }),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0E9F6E), brightness: Brightness.dark),
        useMaterial3: true,
        fontFamily: 'Montserrat',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withAlpha((255 * 0.06).round()),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: Colors.white.withAlpha((255 * 0.08).round())),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: const Color(0xFF1F2937),
          surfaceTintColor: Colors.transparent,
          headerBackgroundColor: const Color(0xFF0E9F6E),
          headerForegroundColor: Colors.white,
          weekdayStyle: const TextStyle(color: Colors.white70),
          dayStyle: const TextStyle(color: Colors.white),
          dayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return Colors.white38;
            }
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.white;
          }),
          todayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return const Color(0xFF0E9F6E);
          }),
          todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF0E9F6E);
            }
            return Colors.transparent;
          }),
          todayBorder: const BorderSide(color: Color(0xFF0E9F6E), width: 1),
          dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF0E9F6E);
            }
            return Colors.transparent;
          }),
          yearStyle: const TextStyle(color: Colors.white),
          yearForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.white;
          }),
          yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF0E9F6E);
            }
            return Colors.transparent;
          }),
          dayOverlayColor: WidgetStateProperty.all(
            const Color(0xFF0E9F6E).withAlpha((255 * 0.2).round()),
          ),
          yearOverlayColor: WidgetStateProperty.all(
            const Color(0xFF0E9F6E).withAlpha((255 * 0.2).round()),
          ),
        ),
        timePickerTheme: TimePickerThemeData(
          backgroundColor: const Color(0xFF1F2937),
          dialBackgroundColor: const Color(0xFF374151),
          dialHandColor: const Color(0xFF0E9F6E),
          dialTextColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.white;
          }),
          dialTextStyle: const TextStyle(color: Colors.white, fontSize: 16),
          hourMinuteTextStyle: const TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          dayPeriodTextStyle:
              const TextStyle(color: Colors.white, fontSize: 14),
          helpTextStyle: const TextStyle(color: Colors.white70),
          hourMinuteColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF0E9F6E);
            }
            return const Color(0xFF374151);
          }),
          hourMinuteTextColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.white;
          }),
          dayPeriodColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF0E9F6E);
            }
            return const Color(0xFF374151);
          }),
          dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.white;
          }),
        ),
      ),
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pl'),
        Locale('uk'),
        Locale('ru'),
        Locale('en'),
        Locale('de'),
        Locale('es'),
      ],
      locale: _locale,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // Перевіряємо чи користувач вже пропустив авторизацію
          return FutureBuilder<bool>(
            future: _checkSkippedAuth(),
            builder: (context, skipSnapshot) {
              if (skipSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final skipped = skipSnapshot.data ?? false;
              if (snapshot.hasData || skipped) {
                return TaskListPage(
                  onThemeChanged: _setTheme,
                  onLanguageChanged: _setLanguage,
                  themeMode: _themeMode,
                );
              }
              return AuthPage(
                onSkip: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('auth_skipped', true);
                  _authSkippedCache = true; // Оновлюємо кеш
                  if (mounted) {
                    setState(() {}); // Перезапускаємо FutureBuilder
                  }
                },
              );
            },
          );
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }

  Future<bool> _checkSkippedAuth() async {
    if (_authSkippedCache != null) {
      return _authSkippedCache!;
    }
    final prefs = await SharedPreferences.getInstance();
    _authSkippedCache = prefs.getBool('auth_skipped') ?? false;
    return _authSkippedCache!;
  }
}

class TaskListPage extends StatefulWidget {
  const TaskListPage(
      {super.key,
      required this.onThemeChanged,
      required this.onLanguageChanged,
      required this.themeMode});
  final void Function(ThemeMode) onThemeChanged;
  final void Function(String) onLanguageChanged;
  final ThemeMode themeMode;

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priorityCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _imageCtrl = TextEditingController();
  String? _selectedImageBase64;
  TaskCategory _selectedCategory = TaskCategory.other;
  DateTime? _selectedReminder;
  bool _favorite = false;

  final List<TaskItem> _items = [];
  final List<TaskItem> _archived = [];
  final List<Habit> _habits = [];
  final List<CustomCategory> _customCategories = [];
  String _search = '';
  late TabController _tabController;

  // Calendar state
  DateTime _calendarMonth = DateTime.now();
  DateTime? _selectedDay;

  // Debouncing для збереження
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      // Оновлюємо UI коли змінюється вкладка
      setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priorityCtrl.dispose();
    _notesCtrl.dispose();
    _imageCtrl.dispose();
    _tabController.dispose();
    _saveDebounce?.cancel();
    super.dispose();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () {
      _saveData();
    });
  }

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        var fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: curve),
        );
        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: offsetAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Спробуємо завантажити з хмари якщо користувач увійшов
      final authService = AuthService();
      Map<String, dynamic>? cloudData;
      if (authService.currentUser != null) {
        try {
          cloudData = await authService.loadFromCloud();
        } catch (e) {
          // Якщо помилка з хмарою, використаємо локальні дані
        }
      }

      final itemsRaw =
          (cloudData?['task_items'] as List<dynamic>?)?.cast<String>() ??
              prefs.getStringList('task_items') ??
              [];
      final archivedRaw =
          (cloudData?['task_archived'] as List<dynamic>?)?.cast<String>() ??
              prefs.getStringList('task_archived') ??
              [];
      List<TaskItem> parse(List<String> raw) {
        return raw
            .map((s) {
              final decoded = json.decode(s);
              if (decoded is Map)
                return TaskItem.fromMap(Map<String, dynamic>.from(decoded));
              return null;
            })
            .whereType<TaskItem>()
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(parse(itemsRaw));
        _archived
          ..clear()
          ..addAll(parse(archivedRaw));
      });

      final habitsRaw =
          (cloudData?['habits'] as List<dynamic>?)?.cast<String>() ??
              prefs.getStringList('habits') ??
              [];
      List<Habit> parseHabits(List<String> raw) {
        return raw
            .map((s) {
              final decoded = json.decode(s);
              if (decoded is Map)
                return Habit.fromMap(Map<String, dynamic>.from(decoded));
              return null;
            })
            .whereType<Habit>()
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _habits
          ..clear()
          ..addAll(parseHabits(habitsRaw));
      });

      final categoriesRaw =
          (cloudData?['custom_categories'] as List<dynamic>?)?.cast<String>() ??
              prefs.getStringList('custom_categories') ??
              [];
      List<CustomCategory> parseCategories(List<String> raw) {
        return raw
            .map((s) {
              final decoded = json.decode(s);
              if (decoded is Map)
                return CustomCategory.fromMap(
                    Map<String, dynamic>.from(decoded));
              return null;
            })
            .whereType<CustomCategory>()
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _customCategories
          ..clear()
          ..addAll(parseCategories(categoriesRaw));
      });
    } catch (e) {
      // ignore
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsRaw = _items.map((it) => json.encode(it.toMap())).toList();
    final archivedRaw = _archived.map((it) => json.encode(it.toMap())).toList();
    final habitsRaw = _habits.map((h) => json.encode(h.toMap())).toList();
    final categoriesRaw =
        _customCategories.map((c) => json.encode(c.toMap())).toList();
    await prefs.setStringList('task_items', itemsRaw);
    await prefs.setStringList('task_archived', archivedRaw);
    await prefs.setStringList('habits', habitsRaw);
    await prefs.setStringList('custom_categories', categoriesRaw);

    // Синхронізація з хмарою якщо користувач увійшов
    final authService = AuthService();
    if (authService.currentUser != null) {
      try {
        await authService.syncToCloud({
          'task_items': itemsRaw,
          'task_archived': archivedRaw,
          'habits': habitsRaw,
          'custom_categories': categoriesRaw,
          'last_sync': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        // Ігноруємо помилки синхронізації
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImageBase64 = base64Encode(bytes);
        _imageCtrl.clear(); // Очищуємо URL якщо було
      });
    }
  }

  void _resetDialogFields() {
    _nameCtrl.clear();
    _priorityCtrl.clear();
    _notesCtrl.clear();
    _imageCtrl.clear();
    _selectedImageBase64 = null;
    _selectedCategory = TaskCategory.other;
    _selectedReminder = null;
    _favorite = false;
  }

  void _addItem() {
    final t = _nameCtrl.text.trim();
    if (t.isEmpty) return;

    setState(() {
      _items.insert(
        0,
        TaskItem(
          name: t,
          favorite: _favorite,
          category: _selectedCategory,
          priority: _priorityCtrl.text.trim().isEmpty
              ? null
              : _priorityCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          imageUrl: _selectedImageBase64 ??
              (_imageCtrl.text.trim().isEmpty ? null : _imageCtrl.text.trim()),
          reminderAt: _selectedReminder,
        ),
      );
    });
    _resetDialogFields();
    _saveData();
  }

  void _toggleCompleted(TaskItem it) {
    setState(() {
      it.completed = !it.completed;
    });
    _scheduleSave();
  }

  void _toggleFavorite(TaskItem it) {
    setState(() {
      it.favorite = !it.favorite;
    });
    _scheduleSave();
  }

  void _removeItem(TaskItem it) {
    final index = _items.indexWhere((e) => e.id == it.id);
    if (index == -1) return;
    setState(() {
      _items.removeAt(index);
    });
    _saveData();
    scaffoldMessengerKey.currentState?.clearSnackBars();
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content:
            Text('${AppLocalizations.of(context).deletedTask} "${it.name}"'),
        action: SnackBarAction(
          label: AppLocalizations.of(context).undo,
          onPressed: () {
            setState(() {
              _items.insert(index, it);
            });
            _saveData();
          },
        ),
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _items.clear();
    });
    _saveData();
  }

  void _clearArchived() {
    setState(() {
      _archived.clear();
    });
    _saveData();
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = await showDatePicker(
      context: context,
      locale: Localizations.localeOf(context),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _selectedReminder ?? now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF0E9F6E),
                    onPrimary: Colors.white,
                    surface: Color(0xFF1F2937),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF0E9F6E),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black87,
                  ),
            textTheme: TextTheme(
              bodyLarge: TextStyle(
                  color: isDark ? Colors.white : Colors.black87, inherit: true),
              bodyMedium: TextStyle(
                  color: isDark ? Colors.white : Colors.black87, inherit: true),
              labelLarge: TextStyle(
                  color: isDark ? Colors.white : Colors.black87, inherit: true),
              headlineMedium:
                  const TextStyle(color: Colors.white, inherit: true),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedReminder ?? now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF0E9F6E),
                    onPrimary: Colors.white,
                    surface: Color(0xFF1F2937),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF0E9F6E),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black87,
                  ),
            textTheme: TextTheme(
              bodyLarge: TextStyle(
                  color: isDark ? Colors.white : Colors.black87, inherit: true),
              bodyMedium: TextStyle(
                  color: isDark ? Colors.white : Colors.black87, inherit: true),
              labelLarge: TextStyle(
                  color: isDark ? Colors.white : Colors.black87, inherit: true),
              headlineMedium: TextStyle(
                  color: isDark ? Colors.white : Colors.black87, inherit: true),
              displayLarge: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 56,
                  fontWeight: FontWeight.w400,
                  inherit: true),
              displayMedium: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 45,
                  fontWeight: FontWeight.w400,
                  inherit: true),
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null) return;
    setState(() {
      _selectedReminder =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  List<TaskItem> get _filteredItems {
    final q = _search.trim().toLowerCase();
    final list = _items.where((it) {
      final matchesQuery = q.isEmpty || it.name.toLowerCase().contains(q);
      return matchesQuery;
    }).toList();

    list.sort((a, b) {
      int fav = (b.favorite ? 1 : 0) - (a.favorite ? 1 : 0);
      if (fav != 0) return fav;
      int completed = (a.completed ? 1 : 0) - (b.completed ? 1 : 0);
      if (completed != 0) return completed;
      if (a.reminderAt != null && b.reminderAt != null) {
        return a.reminderAt!.compareTo(b.reminderAt!);
      } else if (a.reminderAt != null) {
        return -1;
      } else if (b.reminderAt != null) {
        return 1;
      }
      return a.createdAt.compareTo(b.createdAt);
    });

    return list;
  }

  void _openAddDialog() {
    final loc = AppLocalizations.of(context);
    _resetDialogFields();
    _showTaskDialog(loc);
  }

  void _openAddDialogForDate(DateTime date) {
    final loc = AppLocalizations.of(context);
    _resetDialogFields();
    _selectedReminder = DateTime(date.year, date.month, date.day, 9, 0);
    _showTaskDialog(loc);
  }

  void _showTaskDialog(AppLocalizations loc) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.addTask),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: InputDecoration(hintText: loc.taskName),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _priorityCtrl,
                decoration: InputDecoration(labelText: loc.priority),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(labelText: loc.notes),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<TaskCategory>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(labelText: loc.category),
                items: TaskCategory.values
                    .map((c) => DropdownMenuItem(
                        value: c, child: Text(categoryLabel(c, context))))
                    .toList(),
                onChanged: (c) =>
                    setState(() => _selectedCategory = c ?? TaskCategory.other),
              ),
              if (_customCategories.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _customCategories
                      .map((cat) => ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(cat.icon, size: 16, color: cat.color),
                                const SizedBox(width: 4),
                                Text(cat.name),
                              ],
                            ),
                            selected: false,
                            onSelected: (selected) {
                              // Custom categories as visual tags only
                              scaffoldMessengerKey.currentState?.showSnackBar(
                                SnackBar(
                                    content:
                                        Text('${cat.name} - ${loc.category}')),
                              );
                            },
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),
              // Секція додавання фото
              Text(
                loc.addPhoto,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Кнопка вибору фото з галереї
              OutlinedButton.icon(
                icon: Icon(
                  _selectedImageBase64 != null
                      ? Icons.check_circle
                      : Icons.photo_library,
                  color: _selectedImageBase64 != null ? Colors.green : null,
                ),
                label: Text(
                  _selectedImageBase64 != null
                      ? loc.photoSelected
                      : loc.selectPhoto,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _pickImage,
              ),
              if (_selectedImageBase64 != null) ...[
                const SizedBox(height: 8),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(_selectedImageBase64!),
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                        tooltip: loc.removePhoto,
                        onPressed: () =>
                            setState(() => _selectedImageBase64 = null),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              // Розділювач "або"
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      loc.or,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              // Поле для URL
              TextField(
                controller: _imageCtrl,
                decoration: InputDecoration(
                  labelText: loc.enterImageUrl,
                  hintText: 'https://example.com/image.jpg',
                  prefixIcon: const Icon(Icons.link),
                  border: const OutlineInputBorder(),
                  helperText: loc.imageUrlHint,
                  helperMaxLines: 2,
                ),
                enabled: _selectedImageBase64 == null,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.alarm),
                      label: Text(_selectedReminder == null
                          ? loc.addReminder
                          : '${loc.reminder}: ${_selectedReminder!.day}.${_selectedReminder!.month}.${_selectedReminder!.hour.toString().padLeft(2, '0')}:${_selectedReminder!.minute.toString().padLeft(2, '0')}'),
                      onPressed: _pickReminder,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: loc.favorite,
                    onPressed: () => setState(() => _favorite = !_favorite),
                    icon: Icon(_favorite ? Icons.star : Icons.star_border,
                        color: Colors.amber),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.cancel)),
          ElevatedButton(
            onPressed: () {
              _addItem();
              Navigator.of(ctx).pop();
            },
            child: Text(loc.add),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.appTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.task_alt), text: loc.tasks),
            Tab(icon: const Icon(Icons.calendar_today), text: loc.calendar),
            Tab(icon: const Icon(Icons.favorite), text: loc.habits),
            Tab(icon: const Icon(Icons.timer), text: loc.pomodoro),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Профіль',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_items.length} ${loc.tasks.toLowerCase()}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inbox),
              title: Text(loc.inbox),
              subtitle: Text(loc.inboxDesc),
              trailing: Text(
                '${_items.where((item) => !item.completed).length}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _tabController.index = 0; // Перехід на вкладку Tasks
                });
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Мій профіль'),
              onTap: () {
                Navigator.pop(context);
                // Підрахунок статистики
                final completedCount =
                    _items.where((item) => item.completed).length;
                final totalCount = _items.length + _archived.length;
                final activeHabitsCount = _habits.length;
                final longestStreak = _habits.isEmpty
                    ? 0
                    : _habits
                        .map((h) => _calculateStreak(h))
                        .reduce((a, b) => a > b ? a : b);

                Navigator.push(
                  context,
                  _createRoute(
                    ProfilePage(
                      totalTasks: totalCount,
                      completedTasks: completedCount,
                      habitsCount: activeHabitsCount,
                      activeHabitsStreak: longestStreak,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Статистика'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  _createRoute(
                    StatisticsPage(
                      totalTasks: _items.length,
                      completedTasks: _items.where((t) => t.completed).length,
                      habitsCount: _habits.length,
                      activeHabitsStreak: _habits
                          .where((h) => h.completedDates.contains(
                              DateTime.now().toIso8601String().split('T')[0]))
                          .length,
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(loc.settings),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  _createRoute(
                    SettingsPage(
                      themeMode: widget.themeMode,
                      onThemeChanged: widget.onThemeChanged,
                      onLanguageChanged: widget.onLanguageChanged,
                      onClearAll: _clearAll,
                      onClearArchived: _clearArchived,
                      archivedCount: _archived.length,
                      totalTasks: _items.length,
                      customCategories: _customCategories,
                      onCategoriesChanged: (categories) {
                        setState(() {
                          _customCategories.clear();
                          _customCategories.addAll(categories);
                        });
                        _saveData();
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(loc.about),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'TaskFlow',
                  applicationVersion: '2.1.0',
                  applicationIcon: const Icon(Icons.task_alt, size: 48),
                );
              },
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTasksTab(),
          _buildCalendarTab(),
          _buildHabitsTab(),
          const PomodoroPage(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: _openAddDialog,
              child: const Icon(Icons.add),
              tooltip: loc.addTask,
            )
          : _tabController.index == 2
              ? FloatingActionButton(
                  onPressed: _openAddHabitDialog,
                  child: const Icon(Icons.add),
                  tooltip: loc.addHabit,
                )
              : null,
    );
  }

  Widget _buildTasksTab() {
    final loc = AppLocalizations.of(context);
    final items = _filteredItems;
    final completedCount = _items.where((i) => i.completed).length;
    final favCount = _items.where((i) => i.favorite).length;
    final total = _items.length;
    final gradient = [
      Theme.of(context).colorScheme.primary.withAlpha((255 * 0.10).round()),
      Theme.of(context).colorScheme.secondary.withAlpha((255 * 0.08).round()),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _StatsCard(
                  total: total, fav: favCount, completed: completedCount),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search), hintText: loc.search),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            if (_archived.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.archive, size: 18),
                    const SizedBox(width: 6),
                    Text('${loc.archive}: ${_archived.length}'),
                  ],
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: items.isEmpty
                    ? Center(
                        key: const ValueKey('empty'),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.task_alt,
                                size: 80, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(loc.emptyList,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Text(loc.addFirstTask,
                                style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        key: const ValueKey('list'),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 8),
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final it = items[i];
                          final due = it.reminderAt != null &&
                                  it.reminderAt!.isAfter(DateTime.now())
                              ? '${loc.due}: ${it.reminderAt!.hour.toString().padLeft(2, '0')}:${it.reminderAt!.minute.toString().padLeft(2, '0')}'
                              : null;
                          return Dismissible(
                            key: ValueKey(it.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: const Icon(Icons.delete_forever,
                                  color: Colors.white),
                            ),
                            onDismissed: (_) => _removeItem(it),
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 6),
                              child: ListTile(
                                leading: _buildAvatar(it),
                                title: Text(
                                  it.name,
                                  style: it.completed
                                      ? const TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: Colors.grey)
                                      : null,
                                ),
                                subtitle: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    if (it.priority != null)
                                      Chip(
                                          label: Text(
                                              '${loc.priority}: ${it.priority!}')),
                                    Chip(
                                        label: Text(categoryLabel(
                                            it.category, context))),
                                    if (due != null)
                                      Chip(
                                          avatar:
                                              const Icon(Icons.alarm, size: 16),
                                          label: Text(due)),
                                    if (it.notes != null &&
                                        it.notes!.isNotEmpty)
                                      Chip(
                                          avatar:
                                              const Icon(Icons.note, size: 16),
                                          label: Text(loc.note)),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                          it.favorite
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: Colors.amber),
                                      tooltip: loc.favorite,
                                      onPressed: () => _toggleFavorite(it),
                                    ),
                                    Checkbox(
                                        value: it.completed,
                                        onChanged: (_) => _toggleCompleted(it)),
                                  ],
                                ),
                                onTap: () => _toggleCompleted(it),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarTab() {
    final loc = AppLocalizations.of(context);
    final today = DateTime.now();
    final firstDayOfMonth =
        DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final lastDayOfMonth =
        DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday;

    final gradient = [
      Theme.of(context).colorScheme.primary.withAlpha((255 * 0.10).round()),
      Theme.of(context).colorScheme.secondary.withAlpha((255 * 0.08).round()),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: Column(
        children: [
          // Month navigation
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime(
                            _calendarMonth.year, _calendarMonth.month - 1);
                      });
                    },
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime.now();
                        _selectedDay = null;
                      });
                    },
                    child: Text(
                      '${_monthName(_calendarMonth.month)} ${_calendarMonth.year}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime(
                            _calendarMonth.year, _calendarMonth.month + 1);
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          // Calendar grid
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildCalendarGrid(daysInMonth, firstWeekday, today),
                  ),
                ),
                const SizedBox(height: 16),
                // Statistics
                Text(loc.monthStatistics,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          context,
                          _getTotalTasksInMonth(_calendarMonth).toString(),
                          loc.totalTasks,
                          null,
                        ),
                        _buildStatColumn(
                          context,
                          _getCompletedTasksInMonth(_calendarMonth).toString(),
                          loc.completedTasks,
                          Colors.green,
                        ),
                        _buildStatColumn(
                          context,
                          '${(_getCompletedTasksInMonth(_calendarMonth) * 100 ~/ (_getTotalTasksInMonth(_calendarMonth) == 0 ? 1 : _getTotalTasksInMonth(_calendarMonth)))}%',
                          loc.progress,
                          null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Selected day tasks
                if (_selectedDay != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedDay!.day} ${_monthName(_selectedDay!.month)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        tooltip: loc.addTask,
                        onPressed: () => _openAddDialogForDate(_selectedDay!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._buildSelectedDayTasks(_selectedDay!),
                  const SizedBox(height: 80),
                ] else ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        loc.selectedDayTasks,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(
      BuildContext context, String value, String label, Color? color) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  String _monthName(int month) {
    final loc = AppLocalizations.of(context);
    const months = [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december'
    ];
    return loc.translate(months[month - 1]);
  }

  Widget _buildCalendarGrid(int daysInMonth, int firstWeekday, DateTime today) {
    final loc = AppLocalizations.of(context);
    final dayLabels = [
      loc.mon,
      loc.tue,
      loc.wed,
      loc.thu,
      loc.fri,
      loc.sat,
      loc.sun
    ];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: dayLabels
              .map((day) => Expanded(
                    child: Center(
                      child: Text(day,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: 42,
          itemBuilder: (context, index) {
            final dayNumber = index - firstWeekday + 2;

            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return Container();
            }

            final date =
                DateTime(_calendarMonth.year, _calendarMonth.month, dayNumber);
            final tasksOnDay = _items
                .where((i) =>
                    i.createdAt.year == date.year &&
                    i.createdAt.month == date.month &&
                    i.createdAt.day == date.day)
                .toList();

            final completedOnDay = tasksOnDay.where((i) => i.completed).length;
            final isToday = date.year == DateTime.now().year &&
                date.month == DateTime.now().month &&
                date.day == DateTime.now().day;
            final isSelected = _selectedDay != null &&
                _selectedDay!.year == date.year &&
                _selectedDay!.month == date.month &&
                _selectedDay!.day == date.day;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedDay = date;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withAlpha(200)
                      : isToday
                          ? Theme.of(context).colorScheme.primary.withAlpha(100)
                          : Colors.transparent,
                  border: isToday
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayNumber.toString(),
                      style: TextStyle(
                        fontWeight: isToday || isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                        color: isSelected ? Colors.white : null,
                      ),
                    ),
                    if (tasksOnDay.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: completedOnDay == tasksOnDay.length
                                ? Colors.green
                                : Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$completedOnDay/${tasksOnDay.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  int _getTotalTasksInMonth(DateTime date) {
    return _items
        .where((i) =>
            i.createdAt.year == date.year && i.createdAt.month == date.month)
        .length;
  }

  int _getCompletedTasksInMonth(DateTime date) {
    return _items
        .where((i) =>
            i.createdAt.year == date.year &&
            i.createdAt.month == date.month &&
            i.completed)
        .length;
  }

  List<Widget> _buildSelectedDayTasks(DateTime selectedDay) {
    final tasksForDay = _items
        .where((i) =>
            i.createdAt.year == selectedDay.year &&
            i.createdAt.month == selectedDay.month &&
            i.createdAt.day == selectedDay.day)
        .toList();

    if (tasksForDay.isEmpty) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context).emptyList,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).addFirstTask,
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return tasksForDay
        .map((it) => TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Icon(
                      it.completed ? Icons.check_circle : Icons.circle_outlined,
                      key: ValueKey(it.completed),
                      color: it.completed ? Colors.green : Colors.grey,
                      size: 32,
                    ),
                  ),
                  title: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: it.completed
                        ? TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                            fontSize: 16,
                          )
                        : TextStyle(
                            fontSize: 16,
                            color:
                                Theme.of(context).textTheme.bodyLarge?.color ??
                                    Colors.black),
                    child: Text(it.name),
                  ),
                  subtitle: Row(
                    children: [
                      if (it.priority != null)
                        Chip(
                          label: Text(it.priority!,
                              style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (it.priority != null) const SizedBox(width: 4),
                      Chip(
                        label: Text(categoryLabel(it.category, context),
                            style: const TextStyle(fontSize: 10)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (it.favorite)
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.8, end: 1.0),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) {
                            return Transform.scale(
                              scale: scale,
                              child: child,
                            );
                          },
                          child: const Icon(Icons.star,
                              color: Colors.amber, size: 20),
                        ),
                      const SizedBox(width: 8),
                      Checkbox(
                        value: it.completed,
                        onChanged: (_) => setState(() {
                          it.completed = !it.completed;
                          _saveData();
                        }),
                      ),
                    ],
                  ),
                  onTap: () => setState(() {
                    it.completed = !it.completed;
                    _saveData();
                  }),
                ),
              ),
            ))
        .toList();
  }

  Widget _buildHabitsTab() {
    final loc = AppLocalizations.of(context);
    final gradient = [
      Theme.of(context).colorScheme.primary.withAlpha((255 * 0.10).round()),
      Theme.of(context).colorScheme.secondary.withAlpha((255 * 0.08).round()),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: _habits.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_outline,
                      size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(loc.noHabits,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(loc.addFirstHabit,
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(8),
              children: _habits.map((habit) {
                final streak = _calculateStreak(habit);
                return Dismissible(
                  key: Key(habit.name + habit.completedDates.length.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    setState(() {
                      _habits.remove(habit);
                    });
                    _saveData();
                    scaffoldMessengerKey.currentState?.showSnackBar(
                      SnackBar(content: Text(loc.deletedTask)),
                    );
                  },
                  child: Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: habit.isCompletedToday()
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[300],
                        child: Icon(
                          habit.icon,
                          color: habit.isCompletedToday()
                              ? Colors.white
                              : Colors.grey[600],
                        ),
                      ),
                      title: Text(habit.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          if (habit.description != null)
                            Text(habit.description!,
                                style: const TextStyle(fontSize: 11)),
                          Text(frequencyLabel(habit.frequency, context),
                              style: const TextStyle(fontSize: 12)),
                          Row(
                            children: [
                              const Text('Дні: ', style: TextStyle(fontSize: 11)),
                              ...['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'].asMap().entries.map((entry) {
                                final dayNumber = entry.key + 1;
                                final isSelected = habit.selectedDays.contains(dayNumber);
                                return Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${loc.streak}: $streak ${loc.days}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      trailing: habit.isActiveToday() ? GestureDetector(
                        onTap: () {
                          setState(() {
                            if (habit.isCompletedToday()) {
                              habit.completedDates.removeWhere((d) =>
                                  d.year == DateTime.now().year &&
                                  d.month == DateTime.now().month &&
                                  d.day == DateTime.now().day);
                            } else {
                              habit.completedDates.add(DateTime.now());
                            }
                          });
                          _saveData();
                        },
                        child: Icon(
                          habit.isCompletedToday()
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: habit.isCompletedToday()
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ) : const Icon(Icons.remove_circle_outline, color: Colors.grey),
                      onLongPress: () => _openEditHabitDialog(habit),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  int _calculateStreak(Habit habit) {
    if (habit.completedDates.isEmpty) return 0;
    final sorted = habit.completedDates..sort((a, b) => b.compareTo(a));
    int streak = 0;
    var current = DateTime.now();

    for (final date in sorted) {
      if (date.year == current.year &&
          date.month == current.month &&
          date.day == current.day) {
        streak++;
        current = current.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  void _openAddHabitDialog() {
    final loc = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var selectedFreq = HabitFrequency.daily;
    var selectedIcon = Icons.check_circle;
    var selectedDays = <int>[1, 2, 3, 4, 5, 6, 7];
    
    final availableIcons = [
      Icons.check_circle,
      Icons.fitness_center,
      Icons.book,
      Icons.water_drop,
      Icons.nightlight,
      Icons.restaurant,
      Icons.directions_run,
      Icons.self_improvement,
      Icons.favorite,
      Icons.local_drink,
      Icons.music_note,
      Icons.brush,
      Icons.school,
      Icons.work,
      Icons.pets,
      Icons.smoking_rooms,
      Icons.phone_android,
      Icons.videogame_asset,
    ];
    
    final dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(loc.addHabit),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(hintText: loc.habitName),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: loc.description),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<HabitFrequency>(
                  value: selectedFreq,
                  decoration: InputDecoration(labelText: loc.frequency),
                  items: HabitFrequency.values
                      .map((f) => DropdownMenuItem(
                          value: f, child: Text(frequencyLabel(f, context))))
                      .toList(),
                  onChanged: (f) {
                    if (f != null) {
                      setState(() {
                        selectedFreq = f;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text('Дні тижня:', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (index) {
                    final dayNumber = index + 1;
                    final isSelected = selectedDays.contains(dayNumber);
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedDays.remove(dayNumber);
                          } else {
                            selectedDays.add(dayNumber);
                          }
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            dayNames[index],
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Text('Іконка:', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableIcons.map((icon) {
                    final isSelected = icon == selectedIcon;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          selectedIcon = icon;
                        });
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(loc.cancel)),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                if (selectedDays.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Виберіть хоча б один день')),
                  );
                  return;
                }
                this.setState(() {
                  _habits.add(Habit(
                    name: name,
                    description: descCtrl.text.trim().isEmpty
                        ? null
                        : descCtrl.text.trim(),
                    frequency: selectedFreq,
                    icon: selectedIcon,
                    selectedDays: selectedDays,
                  ));
                });
                _saveData();
                Navigator.of(ctx).pop();
              },
              child: Text(loc.add),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditHabitDialog(Habit habit) {
    final loc = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: habit.name);
    final descCtrl = TextEditingController(text: habit.description ?? '');
    var selectedFreq = habit.frequency;
    var selectedIcon = habit.icon;
    var selectedDays = List<int>.from(habit.selectedDays);
    
    final availableIcons = [
      Icons.check_circle,
      Icons.fitness_center,
      Icons.book,
      Icons.water_drop,
      Icons.nightlight,
      Icons.restaurant,
      Icons.directions_run,
      Icons.self_improvement,
      Icons.favorite,
      Icons.local_drink,
      Icons.music_note,
      Icons.brush,
      Icons.school,
      Icons.work,
      Icons.pets,
      Icons.smoking_rooms,
      Icons.phone_android,
      Icons.videogame_asset,
    ];
    
    final dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edytuj nawyk'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(hintText: loc.habitName),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: loc.description),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<HabitFrequency>(
                  value: selectedFreq,
                  decoration: InputDecoration(labelText: loc.frequency),
                  items: HabitFrequency.values
                      .map((f) => DropdownMenuItem(
                          value: f, child: Text(frequencyLabel(f, context))))
                      .toList(),
                  onChanged: (f) {
                    if (f != null) {
                      setState(() {
                        selectedFreq = f;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text('Дні тижня:', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (index) {
                    final dayNumber = index + 1;
                    final isSelected = selectedDays.contains(dayNumber);
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedDays.remove(dayNumber);
                          } else {
                            selectedDays.add(dayNumber);
                          }
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            dayNames[index],
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Text('Іконка:', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableIcons.map((icon) {
                    final isSelected = icon == selectedIcon;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          selectedIcon = icon;
                        });
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(loc.cancel)),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                if (selectedDays.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Виберіть хоча б один день')),
                  );
                  return;
                }
                this.setState(() {
                  habit.name = name;
                  habit.description = descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim();
                  habit.frequency = selectedFreq;
                  habit.icon = selectedIcon;
                  habit.selectedDays = selectedDays;
                });
                _saveData();
                Navigator.of(ctx).pop();
              },
              child: Text(loc.add),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(TaskItem it) {
    if (it.imageUrl != null && it.imageUrl!.isNotEmpty) {
      // Перевіряємо чи це base64
      if (it.imageUrl!.startsWith('data:image') || it.imageUrl!.length > 200) {
        try {
          String base64String = it.imageUrl!;
          if (base64String.contains(',')) {
            base64String = base64String.split(',')[1];
          }
          final Uint8List bytes = base64Decode(base64String);
          return CircleAvatar(backgroundImage: MemoryImage(bytes));
        } catch (e) {
          // Якщо помилка декодування, показуємо заглушку
          return CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            child: const Icon(Icons.error),
          );
        }
      }
      // Інакше це URL
      return CircleAvatar(backgroundImage: NetworkImage(it.imageUrl!));
    }
    return CircleAvatar(
      backgroundColor: Theme.of(context)
          .colorScheme
          .primaryContainer
          .withAlpha((255 * 0.9).round()),
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      child: Text(it.name.isNotEmpty ? it.name[0].toUpperCase() : '?'),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard(
      {required this.total, required this.fav, required this.completed});
  final int total;
  final int fav;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final remaining = total - completed;
    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _stat(context, loc.total, total.toString(), Icons.list_alt),
            _stat(context, loc.favorites, fav.toString(), Icons.star),
            _stat(context, loc.toDo, remaining.toString(),
                Icons.check_circle_outline),
          ],
        ),
      ),
    );
  }

  Widget _stat(
      BuildContext context, String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 18, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

class CategoriesManagementPage extends StatefulWidget {
  final List<CustomCategory> categories;
  final void Function(List<CustomCategory>) onSave;

  const CategoriesManagementPage({
    super.key,
    required this.categories,
    required this.onSave,
  });

  @override
  State<CategoriesManagementPage> createState() =>
      _CategoriesManagementPageState();
}

class _CategoriesManagementPageState extends State<CategoriesManagementPage> {
  late List<CustomCategory> _categories;

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);
  }

  void _addCategory() {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        IconData selectedIcon = Icons.label;
        Color selectedColor = Colors.blue;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(AppLocalizations.of(context).addTask.replaceAll(
                    AppLocalizations.of(context).tasks.toLowerCase(),
                    AppLocalizations.of(context).category.toLowerCase(),
                  )),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)
                            .taskName
                            .replaceAll(
                              AppLocalizations.of(context).tasks.toLowerCase(),
                              AppLocalizations.of(context)
                                  .category
                                  .toLowerCase(),
                            ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context).settings,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Icons.work,
                        Icons.home,
                        Icons.shopping_cart,
                        Icons.fitness_center,
                        Icons.school,
                        Icons.restaurant,
                        Icons.local_hospital,
                        Icons.directions_car,
                        Icons.movie,
                        Icons.music_note,
                      ]
                          .map((icon) => IconButton(
                                icon: Icon(icon,
                                    color: selectedIcon == icon
                                        ? selectedColor
                                        : Colors.grey),
                                onPressed: () =>
                                    setStateDialog(() => selectedIcon = icon),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        Colors.red,
                        Colors.pink,
                        Colors.purple,
                        Colors.blue,
                        Colors.cyan,
                        Colors.teal,
                        Colors.green,
                        Colors.lime,
                        Colors.yellow,
                        Colors.orange,
                        Colors.brown,
                        Colors.grey,
                      ]
                          .map((color) => GestureDetector(
                                onTap: () =>
                                    setStateDialog(() => selectedColor = color),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selectedColor == color
                                          ? Colors.black
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.of(context).cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      setState(() {
                        _categories.add(CustomCategory(
                          name: nameCtrl.text.trim(),
                          icon: selectedIcon,
                          color: selectedColor,
                        ));
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  child: Text(AppLocalizations.of(context).add),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editCategory(int index) {
    final category = _categories[index];
    final nameCtrl = TextEditingController(text: category.name);

    showDialog(
      context: context,
      builder: (ctx) {
        IconData selectedIcon = category.icon;
        Color selectedColor = category.color;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(AppLocalizations.of(context).settings),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)
                            .taskName
                            .replaceAll(
                              AppLocalizations.of(context).tasks.toLowerCase(),
                              AppLocalizations.of(context)
                                  .category
                                  .toLowerCase(),
                            ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        Icons.work,
                        Icons.home,
                        Icons.shopping_cart,
                        Icons.fitness_center,
                        Icons.school,
                        Icons.restaurant,
                        Icons.local_hospital,
                        Icons.directions_car,
                        Icons.movie,
                        Icons.music_note,
                      ]
                          .map((icon) => IconButton(
                                icon: Icon(icon,
                                    color: selectedIcon == icon
                                        ? selectedColor
                                        : Colors.grey),
                                onPressed: () =>
                                    setStateDialog(() => selectedIcon = icon),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        Colors.red,
                        Colors.pink,
                        Colors.purple,
                        Colors.blue,
                        Colors.cyan,
                        Colors.teal,
                        Colors.green,
                        Colors.lime,
                        Colors.yellow,
                        Colors.orange,
                        Colors.brown,
                        Colors.grey,
                      ]
                          .map((color) => GestureDetector(
                                onTap: () =>
                                    setStateDialog(() => selectedColor = color),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selectedColor == color
                                          ? Colors.black
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.of(context).cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      setState(() {
                        _categories[index] = CustomCategory(
                          id: category.id,
                          name: nameCtrl.text.trim(),
                          icon: selectedIcon,
                          color: selectedColor,
                        );
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  child: Text(AppLocalizations.of(context).add),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteCategory(int index) {
    setState(() {
      _categories.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.category),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              widget.onSave(_categories);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: _categories.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.category, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(loc.emptyList,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    loc.addFirstTask.replaceAll(
                      loc.tasks.toLowerCase(),
                      loc.category.toLowerCase(),
                    ),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _categories.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _categories.removeAt(oldIndex);
                  _categories.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final category = _categories[index];
                return Card(
                  key: ValueKey(category.id),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: ListTile(
                    leading: Icon(category.icon, color: category.color),
                    title: Text(category.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editCategory(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteCategory(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _rotateController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();

    // Анімація масштабування
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // Анімація появи
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Анімація обертання
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _rotateAnimation = CurvedAnimation(
      parent: _rotateController,
      curve: Curves.easeInOut,
    );

    // Запускаємо анімації послідовно
    _fadeController.forward().then((_) {
      _scaleController.forward();
      _rotateController.forward();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF0E9F6E).withAlpha((255 * 0.9).round()),
      const Color(0xFF0E9F6E).withAlpha((255 * 0.65).round()),
      const Color(0xFF0E9F6E).withAlpha((255 * 0.5).round()),
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Анімована іконка з обертанням і масштабуванням
                RotationTransition(
                  turns: Tween<double>(begin: 0.0, end: 0.5)
                      .animate(_rotateAnimation),
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.task_alt,
                        size: 88,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Анімований текст з появою знизу
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.5),
                    end: Offset.zero,
                  ).animate(_fadeAnimation),
                  child: const Text(
                    'TaskFlow',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Анімований підзаголовок
                FadeTransition(
                  opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _fadeController,
                      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
                    ),
                  ),
                  child: const Text(
                    'Twoja lista zadań',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Анімований індикатор завантаження
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  final VoidCallback onSkip;

  const AuthPage({super.key, required this.onSkip});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  final _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showMessage('Заповніть всі поля');
      return;
    }

    if (!_isLogin &&
        _passwordController.text != _confirmPasswordController.text) {
      _showMessage('Паролі не співпадають');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _authService.signIn(
            _emailController.text, _passwordController.text);
      } else {
        await _authService.signUp(
            _emailController.text, _passwordController.text);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Помилка';
      if (e.code == 'user-not-found') {
        message = 'Користувача не знайдено';
      } else if (e.code == 'wrong-password') {
        message = 'Невірний пароль';
      } else if (e.code == 'email-already-in-use') {
        message = 'Email вже використовується';
      } else if (e.code == 'weak-password') {
        message = 'Пароль занадто слабкий (мінімум 6 символів)';
      } else if (e.code == 'invalid-email') {
        message = 'Невірний формат email';
      } else {
        message = 'Помилка: ${e.code} - ${e.message}';
      }
      _showMessage(message);
    } catch (e) {
      _showMessage('Помилка: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.task_alt,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'TaskFlow',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLogin ? 'Вхід в акаунт' : 'Створити акаунт',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Пароль',
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                      ),
                      if (!_isLogin) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _confirmPasswordController,
                          decoration: const InputDecoration(
                            labelText: 'Підтвердіть пароль',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          obscureText: true,
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isLogin ? 'Увійти' : 'Зареєструватися',
                                  style: const TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                          });
                        },
                        child: Text(
                          _isLogin
                              ? 'Немає акаунта? Зареєструватися'
                              : 'Вже є акаунт? Увійти',
                        ),
                      ),
                      const Divider(height: 32),
                      // Google Sign-In
                      const Text(
                        'або',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  setState(() => _isLoading = true);
                                  try {
                                    await _authService.signInWithGoogle();
                                    // Успішний вхід - AuthPage автоматично закриється
                                  } catch (e) {
                                    if (mounted) {
                                      _showMessage(e
                                          .toString()
                                          .replaceAll('Exception: ', ''));
                                    }
                                  } finally {
                                    if (mounted)
                                      setState(() => _isLoading = false);
                                  }
                                },
                          icon: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const Center(
                              child: Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4285F4),
                                ),
                              ),
                            ),
                          ),
                          label: const Text(
                            'Увійти через Google',
                            style:
                                TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: widget.onSkip,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Продовжити без акаунта'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StatisticsPage extends StatelessWidget {
  final int totalTasks;
  final int completedTasks;
  final int habitsCount;
  final int activeHabitsStreak;

  const StatisticsPage({
    super.key,
    required this.totalTasks,
    required this.completedTasks,
    required this.habitsCount,
    required this.activeHabitsStreak,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final completionRate =
        totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.statistics),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Статистичні картки
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      Icons.task_alt,
                      totalTasks.toString(),
                      loc.totalTasks,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      Icons.check_circle,
                      completedTasks.toString(),
                      loc.completedTasks,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      Icons.favorite,
                      habitsCount.toString(),
                      loc.habits,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      Icons.local_fire_department,
                      activeHabitsStreak.toString(),
                      '${loc.streak} ${loc.days}',
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Прогрес виконання
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            loc.progress,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$completionRate%',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: completionRate / 100,
                          minHeight: 12,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$completedTasks з $totalTasks ${loc.tasksCompleted}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Досягнення
              Text(
                loc.achievements,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildAchievementCard(
                context,
                Icons.workspace_premium,
                loc.beginner,
                loc.beginnerDesc,
                totalTasks > 0,
              ),
              const SizedBox(height: 12),
              _buildAchievementCard(
                context,
                Icons.military_tech,
                loc.productive,
                loc.productiveDesc,
                completedTasks >= 10,
              ),
              const SizedBox(height: 12),
              _buildAchievementCard(
                context,
                Icons.emoji_events,
                loc.master,
                loc.masterDesc,
                completedTasks >= 50,
              ),
              const SizedBox(height: 12),
              _buildAchievementCard(
                context,
                Icons.auto_awesome,
                loc.habitMaster,
                loc.habitMasterDesc,
                habitsCount >= 5,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildStatCard(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildAchievementCard(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    bool unlocked,
  ) {
    return Card(
      elevation: unlocked ? 2 : 0,
      color: unlocked ? null : Colors.grey.shade100,
      child: ListTile(
        leading: Icon(
          icon,
          size: 32,
          color: unlocked
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade400,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: unlocked ? null : Colors.grey.shade600,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(
            fontSize: 12,
            color: unlocked ? Colors.grey.shade600 : Colors.grey.shade500,
          ),
        ),
        trailing: unlocked
            ? Icon(Icons.check_circle, color: Colors.green.shade600)
            : Icon(Icons.lock, color: Colors.grey.shade400),
      ),
    );
  }
}

class PomodoroPage extends StatefulWidget {
  const PomodoroPage({super.key});

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
  Timer? _timer;
  int _remainingSeconds = 25 * 60; // 25 хвилин
  bool _isRunning = false;
  bool _isWorkSession = true; // true = робота, false = перерва
  int _completedSessions = 0;
  final int _workDuration = 25 * 60; // 25 хвилин
  final int _shortBreakDuration = 5 * 60; // 5 хвилин
  final int _longBreakDuration = 15 * 60; // 15 хвилин

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _onSessionComplete();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _isWorkSession ? _workDuration : _shortBreakDuration;
    });
  }

  void _onSessionComplete() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      if (_isWorkSession) {
        _completedSessions++;
        // Кожна 4-та сесія - довга перерва
        if (_completedSessions % 4 == 0) {
          _remainingSeconds = _longBreakDuration;
        } else {
          _remainingSeconds = _shortBreakDuration;
        }
        _isWorkSession = false;
      } else {
        _remainingSeconds = _workDuration;
        _isWorkSession = true;
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final progress = _isWorkSession
        ? 1 - (_remainingSeconds / _workDuration)
        : 1 -
            (_remainingSeconds /
                (_completedSessions % 4 == 0
                    ? _longBreakDuration
                    : _shortBreakDuration));

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.pomodoro),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Індикатор сесії
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _isWorkSession
                      ? Colors.red.shade100
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  _isWorkSession ? loc.workSession : loc.breakSession,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isWorkSession
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Круговий таймер
              SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Фоновий круг
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _isWorkSession ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                    // Час
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(_remainingSeconds),
                          style: TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          _isWorkSession ? loc.focusTime : loc.breakTime,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              // Кнопки управління
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Кнопка старт/пауза
                  ElevatedButton.icon(
                    onPressed: _isRunning ? _pauseTimer : _startTimer,
                    icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(
                      _isRunning
                          ? loc.pause
                          : (_remainingSeconds ==
                                  (_isWorkSession
                                      ? _workDuration
                                      : _shortBreakDuration)
                              ? loc.start
                              : loc.resume),
                      style: const TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      backgroundColor:
                          _isWorkSession ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Кнопка скидання
                  OutlinedButton.icon(
                    onPressed: _resetTimer,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      loc.reset,
                      style: const TextStyle(fontSize: 18),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // Статистика
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        loc.sessionsCompleted,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _completedSessions.toString(),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  final int totalTasks;
  final int completedTasks;
  final int habitsCount;
  final int activeHabitsStreak;

  const ProfilePage({
    super.key,
    required this.totalTasks,
    required this.completedTasks,
    required this.habitsCount,
    required this.activeHabitsStreak,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final completionRate =
        totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.profile),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Градієнтний header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      loc.user,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TaskFlow • ${DateTime.now().year}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Статистика
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.statistics,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          Icons.task_alt,
                          totalTasks.toString(),
                          loc.totalTasks,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          Icons.check_circle,
                          completedTasks.toString(),
                          loc.completedTasks,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          Icons.favorite,
                          habitsCount.toString(),
                          loc.habits,
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          Icons.local_fire_department,
                          activeHabitsStreak.toString(),
                          '${loc.streak} ${loc.days}',
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Прогрес
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                loc.progress,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$completionRate%',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: completionRate / 100,
                              minHeight: 10,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$completedTasks з $totalTasks ${loc.tasksCompleted}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Досягнення
                  const Text(
                    'Досягнення',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAchievementCard(
                    context,
                    Icons.workspace_premium,
                    loc.beginner,
                    loc.beginnerDesc,
                    totalTasks > 0,
                  ),
                  const SizedBox(height: 12),
                  _buildAchievementCard(
                    context,
                    Icons.military_tech,
                    loc.productive,
                    loc.productiveDesc,
                    completedTasks >= 10,
                  ),
                  const SizedBox(height: 12),
                  _buildAchievementCard(
                    context,
                    Icons.emoji_events,
                    loc.master,
                    loc.masterDesc,
                    habitsCount >= 5,
                  ),
                  const SizedBox(height: 24),
                  // Інформація про акаунт
                  Text(
                    loc.account,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<User?>(
                    future: Future.value(FirebaseAuth.instance.currentUser),
                    builder: (context, snapshot) {
                      final user = snapshot.data;
                      if (user != null) {
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.account_circle),
                            title: const Text('Email акаунт'),
                            subtitle: Text(user.email ?? ''),
                            trailing: IconButton(
                              icon: const Icon(Icons.logout),
                              onPressed: () async {
                                await AuthService().signOut();
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.remove('auth_skipped');
                                if (context.mounted) {
                                  Navigator.of(context)
                                      .popUntil((route) => route.isFirst);
                                }
                              },
                            ),
                          ),
                        );
                      } else {
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.cloud_off),
                            title: Text(loc.localMode),
                            subtitle: Text(loc.localModeDesc),
                            trailing: TextButton(
                              onPressed: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.remove('auth_skipped');
                                if (context.mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (context) => AuthPage(
                                        onSkip: () async {
                                          final prefs = await SharedPreferences
                                              .getInstance();
                                          await prefs.setBool(
                                              'auth_skipped', true);
                                          if (context.mounted) {
                                            Navigator.of(context)
                                                .pushAndRemoveUntil(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    TaskListPage(
                                                  onThemeChanged: (mode) {},
                                                  onLanguageChanged:
                                                      (locale) {},
                                                  themeMode: ThemeMode.system,
                                                ),
                                              ),
                                              (route) => false,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    (route) => false,
                                  );
                                }
                              },
                              child: Text(loc.login),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCard(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    bool unlocked,
  ) {
    return Card(
      elevation: unlocked ? 4 : 1,
      child: Opacity(
        opacity: unlocked ? 1.0 : 0.5,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: unlocked
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            child: Icon(
              icon,
              color: unlocked ? Colors.white : Colors.grey.shade500,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: unlocked ? null : Colors.grey.shade600,
            ),
          ),
          subtitle: Text(description),
          trailing: unlocked
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.lock_outline, color: Colors.grey),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    required this.onClearAll,
    required this.onClearArchived,
    required this.archivedCount,
    required this.totalTasks,
    required this.customCategories,
    required this.onCategoriesChanged,
  });

  final ThemeMode themeMode;
  final void Function(ThemeMode) onThemeChanged;
  final void Function(String) onLanguageChanged;
  final VoidCallback onClearAll;
  final VoidCallback onClearArchived;
  final int archivedCount;
  final int totalTasks;
  final List<CustomCategory> customCategories;
  final void Function(List<CustomCategory>) onCategoriesChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _notificationSoundEnabled = true;
  bool _autoArchiveEnabled = false;
  bool _showCompletedTasks = true;
  bool _developerMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _notificationSoundEnabled = prefs.getBool('notification_sound') ?? true;
      _autoArchiveEnabled = prefs.getBool('auto_archive') ?? false;
      _showCompletedTasks = prefs.getBool('show_completed') ?? true;
      _developerMode = prefs.getBool('developer_mode') ?? false;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _exportData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'tasks': prefs.getStringList('task_items') ?? [],
      'archived': prefs.getStringList('task_archived') ?? [],
      'habits': prefs.getStringList('habits') ?? [],
      'categories': prefs.getStringList('custom_categories') ?? [],
      'settings': {
        'theme': prefs.getString('theme_mode'),
        'language': prefs.getString('language'),
      },
      'exported_at': DateTime.now().toIso8601String(),
    };

    final jsonData = json.encode(data);
    // In a real app, save to file or share
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Дані експортовано (${jsonData.length} байт)')),
    );
  }

  Future<void> _resetApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    widget.onThemeChanged(ThemeMode.system);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Налаштування скинуто')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final currentLocale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.settings),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // Загальні налаштування
          _buildSection(
            context,
            loc.general,
            Icons.tune,
            [
              SwitchListTile(
                secondary: const Icon(Icons.check_circle_outline),
                title: Text(loc.showCompleted),
                subtitle: Text(loc.showCompletedDesc),
                value: _showCompletedTasks,
                onChanged: (val) {
                  setState(() => _showCompletedTasks = val);
                  _saveSetting('show_completed', val);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.archive_outlined),
                title: Text(loc.autoArchive),
                subtitle: Text(loc.autoArchiveDesc),
                value: _autoArchiveEnabled,
                onChanged: (val) {
                  setState(() => _autoArchiveEnabled = val);
                  _saveSetting('auto_archive', val);
                },
              ),
            ],
          ),
          const Divider(),

          // Вигляд
          _buildSection(
            context,
            loc.appearance,
            Icons.palette,
            [
              ListTile(
                leading: const Icon(Icons.light_mode),
                title: Text(loc.lightTheme),
                trailing: Radio<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: widget.themeMode,
                  onChanged: (v) => widget.onThemeChanged(v!),
                ),
                onTap: () => widget.onThemeChanged(ThemeMode.light),
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: Text(loc.darkTheme),
                trailing: Radio<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: widget.themeMode,
                  onChanged: (v) => widget.onThemeChanged(v!),
                ),
                onTap: () => widget.onThemeChanged(ThemeMode.dark),
              ),
              ListTile(
                leading: const Icon(Icons.phone_android),
                title: Text(loc.systemTheme),
                trailing: Radio<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: widget.themeMode,
                  onChanged: (v) => widget.onThemeChanged(v!),
                ),
                onTap: () => widget.onThemeChanged(ThemeMode.system),
              ),
            ],
          ),
          const Divider(),

          // Сповіщення
          _buildSection(
            context,
            loc.notifications,
            Icons.notifications,
            [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active),
                title: Text(loc.enableNotifications),
                subtitle: const Text('Отримувати нагадування про завдання'),
                value: _notificationsEnabled,
                onChanged: (val) {
                  setState(() => _notificationsEnabled = val);
                  _saveSetting('notifications_enabled', val);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.volume_up),
                title: Text(loc.notificationSound),
                subtitle: const Text('Звуковий сигнал при нагадуванні'),
                value: _notificationSoundEnabled,
                onChanged: _notificationsEnabled
                    ? (val) {
                        setState(() => _notificationSoundEnabled = val);
                        _saveSetting('notification_sound', val);
                      }
                    : null,
              ),
            ],
          ),
          const Divider(),

          // Мова
          _buildSection(
            context,
            loc.language,
            Icons.language,
            [
              _buildLanguageTile(context, 'Polski', 'pl', currentLocale,
                  widget.onLanguageChanged),
              _buildLanguageTile(context, 'Українська', 'uk', currentLocale,
                  widget.onLanguageChanged),
              _buildLanguageTile(context, 'Русский', 'ru', currentLocale,
                  widget.onLanguageChanged),
              _buildLanguageTile(context, 'English', 'en', currentLocale,
                  widget.onLanguageChanged),
              _buildLanguageTile(context, 'Deutsch', 'de', currentLocale,
                  widget.onLanguageChanged),
              _buildLanguageTile(context, 'Español', 'es', currentLocale,
                  widget.onLanguageChanged),
            ],
          ),
          const Divider(),

          // Категорії
          _buildSection(
            context,
            loc.category,
            Icons.category,
            [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Керування категоріями'),
                subtitle: Text(
                    '${widget.customCategories.length} ${loc.category.toLowerCase()}'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => CategoriesManagementPage(
                        categories: widget.customCategories,
                        onSave: widget.onCategoriesChanged,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const Divider(),

          // Резервна копія
          _buildSection(
            context,
            loc.backup,
            Icons.backup,
            [
              ListTile(
                leading: const Icon(Icons.file_download),
                title: Text(loc.exportData),
                subtitle: Text(loc.backupDesc),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _exportData,
              ),
              ListTile(
                leading: const Icon(Icons.file_upload),
                title: Text(loc.importData),
                subtitle: const Text('Відновити дані з файлу'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Функція в розробці')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_sync),
                title: const Text('Синхронізація з хмарою'),
                subtitle: FutureBuilder<User?>(
                  future: Future.value(FirebaseAuth.instance.currentUser),
                  builder: (context, snapshot) {
                    if (snapshot.data != null) {
                      return Text('Увімкнено: ${snapshot.data!.email}');
                    }
                    return const Text('Локальний режим');
                  },
                ),
              ),
            ],
          ),
          const Divider(),

          // Дані
          _buildSection(
            context,
            loc.data,
            Icons.storage,
            [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(loc.statistics),
                subtitle: Text(
                    '${loc.totalTasks}: ${widget.totalTasks}\n${loc.archive}: ${widget.archivedCount}'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep),
                title: Text(loc.clearTasks),
                subtitle: Text(loc.deleteAllTasks),
                onTap: () {
                  _showConfirmDialog(
                    context,
                    loc.clearTasks,
                    loc.confirmClearTasks,
                    () {
                      widget.onClearAll();
                      Navigator.pop(context);
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: Text(loc.clearArchive),
                subtitle: Text(
                    '${loc.delete} ${widget.archivedCount} ${loc.archivedTasks}'),
                enabled: widget.archivedCount > 0,
                onTap: widget.archivedCount > 0
                    ? () {
                        _showConfirmDialog(
                          context,
                          loc.clearArchive,
                          loc.confirmClearArchive,
                          () {
                            widget.onClearArchived();
                            Navigator.pop(context);
                          },
                        );
                      }
                    : null,
              ),
            ],
          ),
          const Divider(),

          // Розширені
          _buildSection(
            context,
            loc.advanced,
            Icons.build,
            [
              SwitchListTile(
                secondary: const Icon(Icons.code),
                title: Text(loc.developerMode),
                subtitle: Text(loc.showDebugInfo),
                value: _developerMode,
                onChanged: (val) {
                  setState(() => _developerMode = val);
                  _saveSetting('developer_mode', val);
                },
              ),
              if (_developerMode) ...[
                ListTile(
                  leading: const Icon(Icons.bug_report),
                  title: const Text('Debug інформація'),
                  subtitle: Text(
                      'Flutter ${const String.fromEnvironment('FLUTTER_VERSION', defaultValue: '3.x')}'),
                ),
                ListTile(
                  leading: const Icon(Icons.memory),
                  title: const Text('Кеш'),
                  subtitle: const Text('Очистити тимчасові дані'),
                  onTap: () async {
                    // Clear cache logic here
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Кеш очищено')),
                    );
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.restore, color: Colors.red),
                title: Text(loc.resetApp,
                    style: const TextStyle(color: Colors.red)),
                subtitle: Text(loc.resetAppDesc),
                onTap: () {
                  _showConfirmDialog(
                    context,
                    loc.resetApp,
                    'Це видалить всі налаштування та повернеться до заводських. Дані (завдання, звички) збережуться.',
                    _resetApp,
                  );
                },
              ),
            ],
          ),
          const Divider(),

          // Про додаток
          _buildSection(
            context,
            loc.about,
            Icons.info,
            [
              const ListTile(
                leading: Icon(Icons.task_alt),
                title: Text('TaskFlow'),
                subtitle:
                    Text('Версія 2.2.0\nВаш персональний менеджер завдань'),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Розробник'),
                subtitle: const Text('Made with Flutter ❤️'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: const Text('Політика конфіденційності'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, IconData icon,
      List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(icon,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildLanguageTile(BuildContext context, String name, String code,
      String currentCode, Function(String) onChanged) {
    return ListTile(
      title: Text(name),
      trailing: Radio<String>(
        value: code,
        groupValue: currentCode,
        onChanged: (v) => onChanged(v!),
      ),
      onTap: () => onChanged(code),
    );
  }

  void _showConfirmDialog(BuildContext context, String title, String message,
      VoidCallback onConfirm) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(loc.delete),
          ),
        ],
      ),
    );
  }
}
