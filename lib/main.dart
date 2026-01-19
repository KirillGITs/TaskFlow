import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  tz.initializeTimeZones();

  // Отримуємо часову зону пристрою
  try {
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    final String timeZoneName = timezoneInfo.identifier;
    debugPrint('Device timezone: $timeZoneName');
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  } catch (e) {
    debugPrint('Error getting timezone: $e, using UTC');
    tz.setLocalLocation(tz.UTC);
  }

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Запит дозволу для Android 13+
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  // Запит дозволу на точні нагадування
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestExactAlarmsPermission();
}

Future<void> scheduleNotification({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledDate,
}) async {
  final now = DateTime.now();
  debugPrint(
      'scheduleNotification called: scheduledDate=$scheduledDate, now=$now');

  if (scheduledDate.isBefore(now)) {
    debugPrint('Notification skipped - date is in past: $scheduledDate');
    return;
  }

  // Рахуємо різницю в секундах
  final difference = scheduledDate.difference(now);
  debugPrint('Notification will fire in ${difference.inSeconds} seconds');

  // Створюємо TZDateTime додаючи різницю до поточного часу
  final tzScheduledDate = tz.TZDateTime.now(tz.local).add(difference);
  debugPrint('Scheduling notification for: $tzScheduledDate');

  try {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Нагадування про завдання',
          channelDescription: 'Сповіщення про заплановані завдання',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint('Notification scheduled successfully with zonedSchedule!');
  } catch (e) {
    debugPrint('zonedSchedule failed: $e, using Future.delayed fallback');
    // Fallback до Future.delayed
    Future.delayed(difference, () async {
      debugPrint('Showing notification now (fallback)!');
      await flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders',
            'Нагадування про завдання',
            channelDescription: 'Сповіщення про заплановані завдання',
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    });
  }
}

Future<void> cancelNotification(int id) async {
  await flutterLocalNotificationsPlugin.cancel(id);
}

Future<void> showTestNotification() async {
  await flutterLocalNotificationsPlugin.show(
    0,
    'Тестове сповіщення',
    'Сповіщення працюють!',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'task_reminders',
        'Нагадування про завдання',
        channelDescription: 'Сповіщення про заплановані завдання',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );
  debugPrint('Test notification shown!');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initNotifications();

  await Supabase.initialize(
    url: 'https://xsvfvckfrvlapldkhsgl.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhzdmZ2Y2tmcnZsYXBsZGtoc2dsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgzNDM2NzUsImV4cCI6MjA4MzkxOTY3NX0.yDIN34sgspml23Y2f_lmkuqCPFC917jdizp5TJoPKWc',
  );

  runApp(const TaskManagerApp());
}

enum TaskCategory { work, personal, home, other }

enum HabitFrequency { daily, weekly }

enum TaskPriority { low, medium, high }

Color getPriorityColor(TaskPriority? priority) {
  switch (priority) {
    case TaskPriority.low:
      return Colors.blue;
    case TaskPriority.medium:
      return Colors.orange;
    case TaskPriority.high:
      return Colors.red;
    case null:
      return Colors.grey;
  }
}

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<AuthResponse?> signUp(String email, String password) async {
    try {
      return await _supabase.auth.signUp(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthResponse?> signIn(String email, String password) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<void> syncToCloud(Map<String, dynamic> data) async {
    if (currentUser != null) {
      await _supabase.from('user_data').upsert({
        'user_id': currentUser!.id,
        'data': data,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<Map<String, dynamic>?> loadFromCloud() async {
    if (currentUser != null) {
      final response = await _supabase
          .from('user_data')
          .select('data')
          .eq('user_id', currentUser!.id)
          .maybeSingle();
      return response?['data'] as Map<String, dynamic>?;
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
      'categories': 'Kategorie',
      'add_category': 'Dodaj kategorię',
      'manage_categories': 'Zarządzaj kategoriami',
      'image_url': 'URL zdjęcia (opcjonalnie)',
      'add_reminder': 'Dodaj przypomnienie',
      'reminder': 'Przypomnienie',
      'favorites': 'Ulubione',
      'favorite': 'Ulubione',
      'cancel': 'Anuluj',
      'add': 'Dodaj',
      'delete': 'Usuń',
      'edit': 'Edytuj',
      'priority_low': 'Niski',
      'priority_medium': 'Średni',
      'priority_high': 'Wysoki',
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
      'today': 'Dzisiaj',
      'today_desc': 'Zadania na dzisiaj',
      'habit_name': 'Nazwa nawyku',
      'description': 'Opis (opcjonalnie)',
      'frequency': 'Częstotliwość',
      'confirm_clear_tasks': 'Czy na pewno chcesz usunąć wszystkie zadania?',
      'confirm_clear_archive':
          'Czy na pewno chcesz usunąć wszystkie zarchiwizowane zadania?',
      'notifications': 'Powiadomienia',
      'enable_notifications': 'Włącz powiadomienia',
      'notifications_subtitle': 'Otrzymuj przypomnienia o zadaniach',
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
      'my_profile': 'Mój profil',
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
      'night_owl': 'Nocny marek',
      'night_owl_desc': 'Utwórz zadanie po 22:00',
      'early_bird': 'Ranny ptaszek',
      'early_bird_desc': 'Ukończ zadanie przed 8:00',
      'perfectionist': 'Perfekcjonista',
      'perfectionist_desc': 'Ukończ 100 zadań',
      'streak_master': 'Mistrz serii',
      'streak_master_desc': 'Utrzymaj nawyk przez 7 dni z rzędu',
      'speed_runner': 'Szybki start',
      'speed_runner_desc': 'Ukończ zadanie w dniu utworzenia',
      'collector': 'Kolekcjoner',
      'collector_desc': 'Odblokuj wszystkie pozostałe osiągnięcia',
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
      'default_task_name': 'Zadanie',
      'select_days': 'Wybierz dni:',
      'icon': 'Ikona:',
      'edit_habit': 'Edytuj nawyk',
      'remove': 'Usuń',
      'continue_without_account': 'Kontynuuj bez konta',
      'pick_from_gallery': 'Wybierz z galerii',
      'take_photo': 'Zrób zdjęcie',
      'delete_avatar': 'Usuń awatar',
      'change_name': 'Zmień imię',
      'save': 'Zapisz',
      'email': 'Email',
      'cloud_sync': 'Dane synchronizowane z chmurą',
      'logout_from_account': 'Wyloguj się z konta',
      'logout_confirmation': 'Wylogować się z konta?',
      'select_date': 'Wybierz datę',
      'not_selected': 'Nie wybrano',
      'your_achievements': 'Twoje osiągnięcia',
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
      'edit': 'Редагувати',
      'priority_low': 'Низький',
      'priority_medium': 'Середній',
      'priority_high': 'Високий',
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
      'today': 'Сьогодні',
      'today_desc': 'Завдання на сьогодні',
      'habit_name': 'Назва звички',
      'description': 'Опис (опціонально)',
      'frequency': 'Частота',
      'confirm_clear_tasks': 'Ви впевнені, що хочете видалити всі завдання?',
      'confirm_clear_archive':
          'Ви впевнені, що хочете видалити всі заархівовані завдання?',
      'notifications': 'Сповіщення',
      'enable_notifications': 'Увімкнути сповіщення',
      'notifications_subtitle': 'Отримувати нагадування про завдання',
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
      'my_profile': 'Мій профіль',
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
      'night_owl': 'Нічна сова',
      'night_owl_desc': 'Створіть задачу після 22:00',
      'early_bird': 'Рання пташка',
      'early_bird_desc': 'Завершіть задачу до 8:00',
      'perfectionist': 'Перфекціоніст',
      'perfectionist_desc': 'Виконайте 100 задач',
      'streak_master': 'Майстер серій',
      'streak_master_desc': 'Виконуйте звичку 7 днів поспіль',
      'speed_runner': 'Швидкий старт',
      'speed_runner_desc': 'Виконайте задачу в день створення',
      'collector': 'Колекціонер',
      'collector_desc': 'Розблокуйте всі інші досягнення',
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
      'default_task_name': 'Завдання',
      'select_days': 'Виберіть дні:',
      'icon': 'Іконка:',
      'edit_habit': 'Редагувати звичку',
      'remove': 'Прибрати',
      'continue_without_account': 'Продовжити без акаунта',
      'pick_from_gallery': 'Вибрати з галереї',
      'take_photo': 'Зробити фото',
      'delete_avatar': 'Видалити аватарку',
      'change_name': 'Змінити ім\'я',
      'save': 'Зберегти',
      'email': 'Email',
      'cloud_sync': 'Дані синхронізуються з хмарою',
      'logout_from_account': 'Вийти з акаунту',
      'logout_confirmation': 'Вийти з акаунту?',
      'select_date': 'Вибрати дату',
      'not_selected': 'Не вибрано',
      'your_achievements': 'Ваші досягнення',
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
      'categories': 'Categories',
      'add_category': 'Add Category',
      'manage_categories': 'Manage Categories',
      'image_url': 'Image URL (optional)',
      'add_reminder': 'Add reminder',
      'reminder': 'Reminder',
      'favorites': 'Favorites',
      'favorite': 'Favorite',
      'cancel': 'Cancel',
      'add': 'Add',
      'delete': 'Delete',
      'edit': 'Edit',
      'priority_low': 'Low',
      'priority_medium': 'Medium',
      'priority_high': 'High',
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
      'today': 'Today',
      'today_desc': 'Tasks for today',
      'habit_name': 'Habit name',
      'description': 'Description (optional)',
      'frequency': 'Frequency',
      'confirm_clear_tasks': 'Are you sure you want to delete all tasks?',
      'confirm_clear_archive':
          'Are you sure you want to delete all archived tasks?',
      'notifications': 'Notifications',
      'enable_notifications': 'Enable notifications',
      'notifications_subtitle': 'Receive reminders about tasks',
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
      'my_profile': 'My Profile',
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
      'night_owl': 'Night Owl',
      'night_owl_desc': 'Create a task after 10 PM',
      'early_bird': 'Early Bird',
      'early_bird_desc': 'Complete a task before 8 AM',
      'perfectionist': 'Perfectionist',
      'perfectionist_desc': 'Complete 100 tasks',
      'streak_master': 'Streak Master',
      'streak_master_desc': 'Keep a habit for 7 days in a row',
      'speed_runner': 'Speed Runner',
      'speed_runner_desc': 'Complete a task on the same day',
      'collector': 'Collector',
      'collector_desc': 'Unlock all other achievements',
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
      'default_task_name': 'Task',
      'select_days': 'Select days:',
      'icon': 'Icon:',
      'edit_habit': 'Edit habit',
      'remove': 'Remove',
      'continue_without_account': 'Continue without account',
      'pick_from_gallery': 'Pick from gallery',
      'take_photo': 'Take photo',
      'delete_avatar': 'Delete avatar',
      'change_name': 'Change name',
      'save': 'Save',
      'email': 'Email',
      'cloud_sync': 'Data synced with cloud',
      'logout_from_account': 'Logout from account',
      'logout_confirmation': 'Logout from account?',
      'select_date': 'Select date',
      'not_selected': 'Not selected',
      'your_achievements': 'Your achievements',
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
      'categories': 'Kategorien',
      'add_category': 'Kategorie hinzufügen',
      'manage_categories': 'Kategorien verwalten',
      'image_url': 'Bild-URL (optional)',
      'add_reminder': 'Erinnerung hinzufügen',
      'reminder': 'Erinnerung',
      'favorites': 'Favoriten',
      'favorite': 'Favorit',
      'cancel': 'Abbrechen',
      'add': 'Hinzufügen',
      'delete': 'Löschen',
      'edit': 'Bearbeiten',
      'priority_low': 'Niedrig',
      'priority_medium': 'Mittel',
      'priority_high': 'Hoch',
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
      'today': 'Heute',
      'today_desc': 'Aufgaben für heute',
      'habit_name': 'Gewohnheitsname',
      'description': 'Beschreibung (optional)',
      'frequency': 'Häufigkeit',
      'confirm_clear_tasks':
          'Sind Sie sicher, dass Sie alle Aufgaben löschen möchten?',
      'confirm_clear_archive':
          'Sind Sie sicher, dass Sie alle archivierten Aufgaben löschen möchten?',
      'notifications': 'Benachrichtigungen',
      'enable_notifications': 'Benachrichtigungen aktivieren',
      'notifications_subtitle': 'Erinnerungen über Aufgaben erhalten',
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
      'my_profile': 'Mein Profil',
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
      'night_owl': 'Nachteule',
      'night_owl_desc': 'Erstelle eine Aufgabe nach 22:00',
      'early_bird': 'Frühaufsteher',
      'early_bird_desc': 'Erledige eine Aufgabe vor 8:00',
      'perfectionist': 'Perfektionist',
      'perfectionist_desc': 'Erledige 100 Aufgaben',
      'streak_master': 'Serien-Meister',
      'streak_master_desc': 'Halte eine Gewohnheit 7 Tage am Stück',
      'speed_runner': 'Schnellstarter',
      'speed_runner_desc': 'Erledige eine Aufgabe am selben Tag',
      'collector': 'Sammler',
      'collector_desc': 'Schalte alle anderen Erfolge frei',
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
      'default_task_name': 'Aufgabe',
      'select_days': 'Tage auswählen:',
      'icon': 'Symbol:',
      'edit_habit': 'Gewohnheit bearbeiten',
      'remove': 'Entfernen',
      'continue_without_account': 'Ohne Konto fortfahren',
      'pick_from_gallery': 'Aus Galerie wählen',
      'take_photo': 'Foto aufnehmen',
      'delete_avatar': 'Avatar löschen',
      'change_name': 'Namen ändern',
      'save': 'Speichern',
      'email': 'E-Mail',
      'cloud_sync': 'Daten mit Cloud synchronisiert',
      'logout_from_account': 'Vom Konto abmelden',
      'logout_confirmation': 'Vom Konto abmelden?',
      'select_date': 'Datum wählen',
      'not_selected': 'Nicht ausgewählt',
      'your_achievements': 'Ihre Erfolge',
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
      'categories': 'Categorías',
      'add_category': 'Añadir Categoría',
      'manage_categories': 'Gestionar Categorías',
      'image_url': 'URL de imagen (opcional)',
      'add_reminder': 'Añadir recordatorio',
      'reminder': 'Recordatorio',
      'favorites': 'Favoritos',
      'favorite': 'Favorito',
      'cancel': 'Cancelar',
      'add': 'Añadir',
      'delete': 'Eliminar',
      'edit': 'Editar',
      'priority_low': 'Baja',
      'priority_medium': 'Media',
      'priority_high': 'Alta',
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
      'today': 'Hoy',
      'today_desc': 'Tareas para hoy',
      'habit_name': 'Nombre del hábito',
      'description': 'Descripción (opcional)',
      'frequency': 'Frecuencia',
      'confirm_clear_tasks':
          '¿Estás seguro de que quieres eliminar todas las tareas?',
      'confirm_clear_archive':
          '¿Estás seguro de que quieres eliminar todas las tareas archivadas?',
      'notifications': 'Notificaciones',
      'enable_notifications': 'Activar notificaciones',
      'notifications_subtitle': 'Recibir recordatorios sobre tareas',
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
      'my_profile': 'Mi Perfil',
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
      'night_owl': 'Búho nocturno',
      'night_owl_desc': 'Crea una tarea después de las 22:00',
      'early_bird': 'Madrugador',
      'early_bird_desc': 'Completa una tarea antes de las 8:00',
      'perfectionist': 'Perfeccionista',
      'perfectionist_desc': 'Completa 100 tareas',
      'streak_master': 'Maestro de rachas',
      'streak_master_desc': 'Mantén un hábito durante 7 días seguidos',
      'speed_runner': 'Velocista',
      'speed_runner_desc': 'Completa una tarea el mismo día',
      'collector': 'Coleccionista',
      'collector_desc': 'Desbloquea todos los demás logros',
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
      'default_task_name': 'Tarea',
      'select_days': 'Seleccionar días:',
      'icon': 'Icono:',
      'edit_habit': 'Editar hábito',
      'remove': 'Eliminar',
      'continue_without_account': 'Continuar sin cuenta',
      'pick_from_gallery': 'Elegir de la galería',
      'take_photo': 'Tomar foto',
      'delete_avatar': 'Eliminar avatar',
      'change_name': 'Cambiar nombre',
      'save': 'Guardar',
      'email': 'Correo electrónico',
      'cloud_sync': 'Datos sincronizados con la nube',
      'logout_from_account': 'Cerrar sesión de la cuenta',
      'logout_confirmation': '¿Cerrar sesión de la cuenta?',
      'select_date': 'Seleccionar fecha',
      'not_selected': 'No seleccionado',
      'your_achievements': 'Tus logros',
    },
  };

  String translate(String key) {
    return _localizedValues[languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
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
  String get categories => translate('categories');
  String get addCategory => translate('add_category');
  String get manageCategories => translate('manage_categories');
  String get imageUrl => translate('image_url');
  String get addReminder => translate('add_reminder');
  String get favorites => translate('favorites');
  String get cancel => translate('cancel');
  String get add => translate('add');
  String get delete => translate('delete');
  String get edit => translate('edit');
  String get priorityLow => translate('priority_low');
  String get priorityMedium => translate('priority_medium');
  String get priorityHigh => translate('priority_high');
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
  String get today => translate('today');
  String get todayDesc => translate('today_desc');
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
  String get notificationsSubtitle => translate('notifications_subtitle');
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
  String get myProfile => translate('my_profile');
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
  String get nightOwl => translate('night_owl');
  String get nightOwlDesc => translate('night_owl_desc');
  String get earlyBird => translate('early_bird');
  String get earlyBirdDesc => translate('early_bird_desc');
  String get perfectionist => translate('perfectionist');
  String get perfectionistDesc => translate('perfectionist_desc');
  String get streakMaster => translate('streak_master');
  String get streakMasterDesc => translate('streak_master_desc');
  String get speedRunner => translate('speed_runner');
  String get speedRunnerDesc => translate('speed_runner_desc');
  String get collector => translate('collector');
  String get collectorDesc => translate('collector_desc');
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
  String get defaultTaskName => translate('default_task_name');
  String get selectDays => translate('select_days');
  String get icon => translate('icon');
  String get editHabit => translate('edit_habit');
  String get remove => translate('remove');
  String get continueWithoutAccount => translate('continue_without_account');
  String get pickFromGallery => translate('pick_from_gallery');
  String get takePhoto => translate('take_photo');
  String get deleteAvatar => translate('delete_avatar');
  String get changeName => translate('change_name');
  String get save => translate('save');
  String get email => translate('email');
  String get cloudSync => translate('cloud_sync');
  String get logoutFromAccount => translate('logout_from_account');
  String get logoutConfirmation => translate('logout_confirmation');
  String get selectDate => translate('select_date');
  String get notSelected => translate('not_selected');
  String get yourAchievements => translate('your_achievements');
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
  TimeOfDay? reminderTime; // Час нагадування

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
    this.reminderTime,
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
        'reminderHour': reminderTime?.hour,
        'reminderMinute': reminderTime?.minute,
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
      icon: IconData(map['iconCodePoint'] ?? Icons.check_circle.codePoint,
          fontFamily: 'MaterialIcons'),
      selectedDays: map['selectedDays'] != null
          ? List<int>.from(map['selectedDays'])
          : [1, 2, 3, 4, 5, 6, 7],
      reminderTime: map['reminderHour'] != null && map['reminderMinute'] != null
          ? TimeOfDay(hour: map['reminderHour'], minute: map['reminderMinute'])
          : null,
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
  String? customCategoryId;
  TaskPriority? priority;
  String? notes;
  String? imageUrl;
  DateTime createdAt;
  DateTime? completedAt;
  DateTime? reminderAt;
  DateTime? archivedAt;
  DateTime? dueDate;

  TaskItem({
    String? id,
    required this.name,
    this.completed = false,
    this.favorite = false,
    this.category = TaskCategory.other,
    this.customCategoryId,
    this.priority,
    this.notes,
    this.imageUrl,
    DateTime? createdAt,
    this.completedAt,
    this.reminderAt,
    this.archivedAt,
    this.dueDate,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'completed': completed,
        'favorite': favorite,
        'category': category.name,
        'customCategoryId': customCategoryId,
        'priority': priority?.name,
        'notes': notes,
        'imageUrl': imageUrl,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'reminderAt': reminderAt?.toIso8601String(),
        'archivedAt': archivedAt?.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
      };

  factory TaskItem.fromMap(Map<String, dynamic> m) {
    final map = Map<String, dynamic>.from(m);
    TaskCategory parseCat(String? v) {
      return TaskCategory.values.firstWhere(
        (c) => c.name == v,
        orElse: () => TaskCategory.other,
      );
    }

    TaskPriority? parsePriority(String? v) {
      if (v == null) return null;
      try {
        return TaskPriority.values.firstWhere((p) => p.name == v);
      } catch (_) {
        return null;
      }
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
      customCategoryId: map['customCategoryId']?.toString(),
      priority: parsePriority(map['priority']?.toString()),
      notes: map['notes']?.toString(),
      imageUrl: map['imageUrl']?.toString(),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      completedAt: parseDate(map['completedAt']),
      reminderAt: parseDate(map['reminderAt']),
      archivedAt: parseDate(map['archivedAt']),
      dueDate: parseDate(map['dueDate']),
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

  void _setTheme(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    await _saveTheme(mode);
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
      themeAnimationDuration: const Duration(milliseconds: 350),
      themeAnimationCurve: Curves.easeInOut,
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
        Locale('en'),
        Locale('de'),
        Locale('es'),
      ],
      locale: _locale,
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = snapshot.data?.session?.user;
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
              if (user != null || skipped) {
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
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _imageCtrl = TextEditingController();
  String? _selectedImageBase64;
  DateTime? _selectedReminder;
  DateTime? _selectedDueDate;
  bool _favorite = false;
  TaskPriority? _selectedPriority;

  final List<TaskItem> _items = [];
  final List<TaskItem> _archived = [];
  final List<Habit> _habits = [];
  List<CustomCategory> _customCategories = [];
  String _search = '';
  int _currentTabIndex = 0;
  String? _profileAvatarBase64;
  String _userName = '';
  bool _notificationsEnabled = true;
  bool _isDrawerOpen = false;
  bool _showCompletedTasks = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Calendar state
  DateTime _calendarMonth = DateTime.now();
  DateTime? _selectedDay;

  // Debouncing для збереження
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    _imageCtrl.dispose();
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

  Color _getPriorityColor(TaskPriority? priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.blue;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
      case null:
        return Colors.grey;
    }
  }

  int _calculateStreak(Habit habit) {
    if (habit.completedDates.isEmpty) return 0;

    final sortedDates = habit.completedDates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); // Сортуємо від найновішої

    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);

    int streak = 0;
    DateTime checkDate = todayNormalized;

    for (int i = 0; i < sortedDates.length; i++) {
      if (sortedDates[i] == checkDate) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (sortedDates[i] ==
              checkDate.subtract(const Duration(days: 1)) &&
          i == 0) {
        // Якщо сьогодні ще не виконано, перевіряємо від вчора
        checkDate = checkDate.subtract(const Duration(days: 1));
        if (sortedDates[i] == checkDate) {
          streak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        }
      } else if (sortedDates[i].isBefore(checkDate)) {
        break; // Розрив серії
      }
    }

    return streak;
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

      // Завантажуємо аватарку профілю
      final avatarData = cloudData?['profile_avatar'] as String? ??
          prefs.getString('profile_avatar');
      if (avatarData != null && avatarData.isNotEmpty) {
        setState(() {
          _profileAvatarBase64 = avatarData;
        });
      }

      // Завантажуємо ім'я користувача
      final userName = cloudData?['user_name'] as String? ??
          prefs.getString('user_name') ??
          '';
      if (mounted) {
        setState(() {
          _userName = userName;
        });
      }

      // Завантажуємо налаштування показу виконаних завдань
      final showCompleted = prefs.getBool('show_completed') ?? true;
      if (mounted) {
        setState(() {
          _showCompletedTasks = showCompleted;
        });
      }

      // Завантажуємо налаштування повідомлень
      final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      if (mounted) {
        setState(() {
          _notificationsEnabled = notificationsEnabled;
        });
      }

      // Плануємо нагадування для звичок
      _scheduleAllHabitReminders();
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

    // Зберігаємо аватарку профілю
    if (_profileAvatarBase64 != null) {
      await prefs.setString('profile_avatar', _profileAvatarBase64!);
    }

    // Зберігаємо ім'я користувача
    await prefs.setString('user_name', _userName);

    // Синхронізація з хмарою якщо користувач увійшов
    final authService = AuthService();
    if (authService.currentUser != null) {
      try {
        await authService.syncToCloud({
          'task_items': itemsRaw,
          'task_archived': archivedRaw,
          'habits': habitsRaw,
          'custom_categories': categoriesRaw,
          'profile_avatar': _profileAvatarBase64,
          'user_name': _userName,
          'last_sync': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        // Ігноруємо помилки синхронізації
      }
    }
  }

  void _scheduleHabitReminders(Habit habit) {
    if (habit.reminderTime == null || !habit.active) return;

    final now = DateTime.now();

    // Плануємо нагадування на наступні 7 днів
    for (int i = 0; i < 7; i++) {
      final date = now.add(Duration(days: i));
      final weekday = date.weekday;

      if (habit.selectedDays.contains(weekday)) {
        final scheduledDate = DateTime(
          date.year,
          date.month,
          date.day,
          habit.reminderTime!.hour,
          habit.reminderTime!.minute,
        );

        // Пропускаємо якщо час вже минув
        if (scheduledDate.isAfter(now) && _notificationsEnabled) {
          final notificationId = habit.id.hashCode + i;
          scheduleNotification(
            id: notificationId,
            title: 'Нагадування про звичку',
            body: habit.name,
            scheduledDate: scheduledDate,
          );

          // Додатковий лог для перевірки
          print('Scheduled habit reminder: ${habit.name} at $scheduledDate');
        }
      }
    }
  }

  void _cancelHabitReminders(Habit habit) {
    // Скасовуємо нагадування на 7 днів
    for (int i = 0; i < 7; i++) {
      final notificationId = habit.id.hashCode + i;
      cancelNotification(notificationId);
    }
  }

  void _scheduleAllHabitReminders() {
    for (final habit in _habits) {
      if (habit.reminderTime != null && habit.active) {
        _scheduleHabitReminders(habit);
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

  Future<void> _pickProfileAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 90,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _profileAvatarBase64 = base64Encode(bytes);
      });
      await _saveData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Аватарка оновлена!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _resetDialogFields() {
    _nameCtrl.clear();
    _notesCtrl.clear();
    _imageCtrl.clear();
    _selectedImageBase64 = null;
    _selectedReminder = null;
    _selectedDueDate = null;
    _favorite = false;
    _selectedPriority = null;
  }

  void _addItem() {
    final loc = AppLocalizations.of(context);
    final t = _nameCtrl.text.trim();
    final taskName =
        t.isEmpty ? (loc.translate('default_task_name') ?? 'Task') : t;

    final newTask = TaskItem(
      name: taskName,
      favorite: _favorite,
      category: TaskCategory.other,
      customCategoryId: null,
      priority: _selectedPriority,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      imageUrl: _selectedImageBase64 ??
          (_imageCtrl.text.trim().isEmpty ? null : _imageCtrl.text.trim()),
      reminderAt: _selectedReminder,
      dueDate: _selectedDueDate,
    );

    setState(() {
      _items.insert(0, newTask);
    });

    // Планування сповіщення
    if (_notificationsEnabled &&
        _selectedReminder != null &&
        _selectedReminder!.isAfter(DateTime.now())) {
      scheduleNotification(
        id: newTask.id.hashCode,
        title: 'Нагадування: $taskName',
        body: newTask.notes ?? 'Час виконати завдання!',
        scheduledDate: _selectedReminder!,
      );
    }

    _resetDialogFields();
    _saveData();
  }

  void _toggleCompleted(TaskItem it) {
    setState(() {
      it.completed = !it.completed;
      if (it.completed) {
        it.completedAt = DateTime.now();
      } else {
        it.completedAt = null;
      }
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

  void _openEditTaskDialog(TaskItem task) {
    final loc = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: task.name);
    final notesCtrl = TextEditingController(text: task.notes ?? '');
    bool favorite = task.favorite;
    TaskPriority? priority = task.priority;
    DateTime? dueDate = task.dueDate;
    DateTime? reminder = task.reminderAt;

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit Task Dialog',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInBack,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: StatefulBuilder(
              builder: (ctx, setDialogState) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: child,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.edit, color: Colors.blue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      loc.edit,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Назва завдання зі зірочкою
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: nameCtrl,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: loc.taskName,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              setDialogState(() {
                                favorite = !favorite;
                              });
                            },
                            borderRadius: BorderRadius.circular(50),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(
                                    begin: 0.0, end: favorite ? 1.0 : 0.0),
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.elasticOut,
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: 1.0 + (value * 0.2),
                                    child: Icon(
                                      favorite ? Icons.star : Icons.star_border,
                                      color: Color.lerp(Colors.grey.shade400,
                                          Colors.amber, value),
                                      size: 36,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Пріоритет
                      DropdownButtonFormField<TaskPriority?>(
                        value: priority,
                        decoration: InputDecoration(
                          labelText: loc.priority,
                          prefixIcon: const Icon(Icons.flag),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<TaskPriority?>(
                            value: null,
                            child: Text('—'),
                          ),
                          DropdownMenuItem<TaskPriority?>(
                            value: TaskPriority.low,
                            child: Row(
                              children: [
                                Icon(Icons.circle,
                                    color: Colors.blue, size: 12),
                                SizedBox(width: 8),
                                Text(loc.priorityLow),
                              ],
                            ),
                          ),
                          DropdownMenuItem<TaskPriority?>(
                            value: TaskPriority.medium,
                            child: Row(
                              children: [
                                Icon(Icons.circle,
                                    color: Colors.orange, size: 12),
                                SizedBox(width: 8),
                                Text(loc.priorityMedium),
                              ],
                            ),
                          ),
                          DropdownMenuItem<TaskPriority?>(
                            value: TaskPriority.high,
                            child: Row(
                              children: [
                                Icon(Icons.circle, color: Colors.red, size: 12),
                                SizedBox(width: 8),
                                Text(loc.priorityHigh),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() => priority = value);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Примітки
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: loc.notes,
                          hintText: loc.translate('additional_info') ??
                              'Додаткова інформація...',
                          prefixIcon: const Icon(Icons.note),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Дата виконання
                      OutlinedButton.icon(
                        icon: Icon(
                          dueDate != null
                              ? Icons.check_circle
                              : Icons.calendar_today,
                          color: dueDate != null ? Colors.green : null,
                        ),
                        label: Text(dueDate == null
                            ? loc.selectDate
                            : '📅 ${dueDate!.day}.${dueDate!.month}.${dueDate!.year}'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          backgroundColor:
                              dueDate != null ? Colors.green.shade50 : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate: dueDate ?? DateTime.now(),
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 365)),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365 * 5)),
                          );
                          if (date != null) {
                            setDialogState(() {
                              dueDate = date;
                              // Оновлюємо дату нагадування якщо воно вже встановлене
                              if (reminder != null) {
                                reminder = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  reminder!.hour,
                                  reminder!.minute,
                                );
                              }
                            });
                          }
                        },
                      ),
                      if (dueDate != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.clear, size: 16),
                            label: Text(loc.remove),
                            onPressed: () {
                              setDialogState(() => dueDate = null);
                            },
                          ),
                        ),
                      const SizedBox(height: 8),

                      // Нагадування
                      OutlinedButton.icon(
                        icon: Icon(
                          reminder != null ? Icons.check_circle : Icons.alarm,
                          color: reminder != null ? Colors.green : null,
                        ),
                        label: Text(reminder == null
                            ? loc.addReminder
                            : '⏰ ${reminder!.hour.toString().padLeft(2, '0')}:${reminder!.minute.toString().padLeft(2, '0')}'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          backgroundColor:
                              reminder != null ? Colors.blue.shade50 : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          // Використовуємо вибрану дату або сьогодні
                          final date = dueDate ?? DateTime.now();
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.fromDateTime(
                                reminder ?? DateTime.now()),
                          );
                          if (time != null) {
                            setDialogState(() {
                              reminder = DateTime(date.year, date.month,
                                  date.day, time.hour, time.minute);
                            });
                          }
                        },
                      ),
                      if (reminder != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.clear, size: 16),
                            label: Text(loc.remove),
                            onPressed: () {
                              setDialogState(() => reminder = null);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(loc.cancel),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: Text(loc.translate('save') ?? 'Зберегти'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final t = nameCtrl.text.trim();
                      if (t.isEmpty) return;
                      setState(() {
                        task.name = t;
                        task.favorite = favorite;
                        task.priority = priority;
                        task.notes = notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim();
                        task.dueDate = dueDate;
                        task.reminderAt = reminder;
                      });

                      // Скасувати старе сповіщення та запланувати нове
                      cancelNotification(task.id.hashCode);
                      if (_notificationsEnabled &&
                          reminder != null &&
                          reminder!.isAfter(DateTime.now())) {
                        scheduleNotification(
                          id: task.id.hashCode,
                          title: 'Нагадування: ${task.name}',
                          body: task.notes ?? 'Час виконати завдання!',
                          scheduledDate: reminder!,
                        );
                      }

                      _saveData();
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Використовуємо вибрану дату завдання або сьогодні
    final date = _selectedDueDate ?? DateTime.now();

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
      final showByCompleted = _showCompletedTasks || !it.completed;
      return matchesQuery && showByCompleted;
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

  void _showAddCategoryDialog() {
    final loc = AppLocalizations.of(context);
    final nameController = TextEditingController();
    IconData selectedIcon = Icons.label;
    Color selectedColor = Colors.blue;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.add_circle, color: Colors.blue),
              const SizedBox(width: 8),
              Text(loc.addCategory),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: loc.category,
                    hintText: 'Назва категорії',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 16),
                // Icon selector
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Icons.work,
                    Icons.shopping_cart,
                    Icons.home,
                    Icons.school,
                    Icons.sports_basketball,
                    Icons.favorite,
                    Icons.flight,
                    Icons.restaurant,
                    Icons.fitness_center,
                    Icons.movie,
                    Icons.music_note,
                    Icons.book,
                  ].map((icon) {
                    final isSelected = selectedIcon == icon;
                    return InkWell(
                      onTap: () {
                        setDialogState(() => selectedIcon = icon);
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? Colors.blue : Colors.grey,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Icon(icon, color: selectedColor),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Color selector
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Colors.blue,
                    Colors.red,
                    Colors.green,
                    Colors.orange,
                    Colors.purple,
                    Colors.pink,
                    Colors.teal,
                    Colors.amber,
                  ].map((color) {
                    final isSelected = selectedColor == color;
                    return InkWell(
                      onTap: () {
                        setDialogState(() => selectedColor = color);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isSelected ? Colors.black : Colors.transparent,
                            width: 3,
                          ),
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
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.cancel),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(loc.add),
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                setState(() {
                  _customCategories.add(CustomCategory(
                    name: nameController.text.trim(),
                    icon: selectedIcon,
                    color: selectedColor,
                  ));
                });
                _saveData();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${loc.category} "${nameController.text.trim()}" ${loc.add.toLowerCase()}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskDialog(AppLocalizations loc) {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.add_task, color: Colors.blue),
              const SizedBox(width: 8),
              Text(loc.addTask),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Назва завдання зі зірочкою
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        autofocus: true,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          hintText: loc.taskName,
                          border: const OutlineInputBorder(),
                          filled: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setDialogState(() {
                          _favorite = !_favorite;
                        });
                      },
                      borderRadius: BorderRadius.circular(50),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: _favorite ? 1.0 : 0.0),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: 1.0 + (value * 0.2),
                              child: Icon(
                                _favorite ? Icons.star : Icons.star_border,
                                color: Color.lerp(
                                    Colors.grey.shade400, Colors.amber, value),
                                size: 36,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Пріоритет
                DropdownButtonFormField<TaskPriority?>(
                  value: _selectedPriority,
                  decoration: InputDecoration(
                    labelText: loc.priority,
                    prefixIcon: const Icon(Icons.flag),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem<TaskPriority?>(
                      value: null,
                      child: Text(loc.notSelected),
                    ),
                    DropdownMenuItem<TaskPriority?>(
                      value: TaskPriority.low,
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: Colors.blue, size: 12),
                          SizedBox(width: 8),
                          Text('Низький'),
                        ],
                      ),
                    ),
                    DropdownMenuItem<TaskPriority?>(
                      value: TaskPriority.medium,
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: Colors.orange, size: 12),
                          SizedBox(width: 8),
                          Text('Середній'),
                        ],
                      ),
                    ),
                    DropdownMenuItem<TaskPriority?>(
                      value: TaskPriority.high,
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: Colors.red, size: 12),
                          SizedBox(width: 8),
                          Text('Високий'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() => _selectedPriority = value);
                    setState(() => _selectedPriority = value);
                  },
                ),
                const SizedBox(height: 16),

                // Примітки
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: loc.notes,
                    hintText: 'Додаткова інформація...',
                    prefixIcon: const Icon(Icons.note),
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Дата виконання
                OutlinedButton.icon(
                  icon: Icon(
                    _selectedDueDate != null
                        ? Icons.check_circle
                        : Icons.calendar_today,
                    color: _selectedDueDate != null ? Colors.green : null,
                  ),
                  label: Text(_selectedDueDate == null
                      ? loc.selectDate
                      : '📅 ${_selectedDueDate!.day}.${_selectedDueDate!.month}.${_selectedDueDate!.year}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor:
                        _selectedDueDate != null ? Colors.green.shade50 : null,
                  ),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDueDate ?? DateTime.now(),
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (date != null) {
                      setDialogState(() {
                        _selectedDueDate = date;
                        // Оновлюємо дату нагадування якщо воно вже встановлене
                        if (_selectedReminder != null) {
                          _selectedReminder = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            _selectedReminder!.hour,
                            _selectedReminder!.minute,
                          );
                        }
                      });
                    }
                  },
                ),
                if (_selectedDueDate != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.clear, size: 16),
                      label: Text(loc.remove),
                      onPressed: () {
                        setDialogState(() => _selectedDueDate = null);
                        setState(() => _selectedDueDate = null);
                      },
                    ),
                  ),
                const SizedBox(height: 8),

                // Нагадування
                OutlinedButton.icon(
                  icon: Icon(
                    _selectedReminder != null
                        ? Icons.check_circle
                        : Icons.alarm,
                    color: _selectedReminder != null ? Colors.green : null,
                  ),
                  label: Text(_selectedReminder == null
                      ? loc.addReminder
                      : '⏰ ${_selectedReminder!.day}.${_selectedReminder!.month} о ${_selectedReminder!.hour.toString().padLeft(2, '0')}:${_selectedReminder!.minute.toString().padLeft(2, '0')}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor:
                        _selectedReminder != null ? Colors.blue.shade50 : null,
                  ),
                  onPressed: () async {
                    await _pickReminder();
                    setDialogState(() {});
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(loc.cancel)),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              onPressed: _nameCtrl.text.trim().isEmpty
                  ? null
                  : () {
                      _addItem();
                      Navigator.of(ctx).pop();
                    },
              label: Text(loc.add),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(loc.appTitle),
        elevation: 0,
      ),
      drawerScrimColor: Colors.transparent,
      onDrawerChanged: (isOpened) {
        setState(() {
          _isDrawerOpen = isOpened;
        });
      },
      drawer: Drawer(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : Colors.white,
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
                  GestureDetector(
                    onTap: _pickProfileAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white,
                          backgroundImage: _profileAvatarBase64 != null
                              ? MemoryImage(base64Decode(_profileAvatarBase64!))
                              : null,
                          child: _profileAvatarBase64 == null
                              ? Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _userName.isNotEmpty ? _userName : loc.profile,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.today),
              title: Text(loc.today),
              subtitle: Text(loc.todayDesc),
              trailing: Text(
                '${_getTodayTasksCount()}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  _createRoute(
                    TodayTasksPage(
                      items: _items,
                      onToggle: (item) {
                        setState(() {
                          item.completed = !item.completed;
                          if (item.completed) {
                            item.completedAt = DateTime.now();
                          } else {
                            item.completedAt = null;
                          }
                        });
                        _saveData();
                      },
                      onDelete: (item) {
                        setState(() {
                          _items.remove(item);
                          _archived.add(item);
                        });
                        _saveData();
                      },
                      onEdit: (item) {
                        final loc = AppLocalizations.of(context);
                        _showTaskDialog(loc);
                      },
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(loc.myProfile),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  _createRoute(
                    ProfilePage(
                      avatarBase64: _profileAvatarBase64,
                      userName: _userName,
                      onUserNameChanged: (name) {
                        setState(() {
                          _userName = name;
                        });
                        _saveData();
                      },
                      onAvatarChanged: (avatar) {
                        setState(() {
                          _profileAvatarBase64 = avatar;
                        });
                        _saveData();
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events),
              title: Text(loc.achievements),
              onTap: () {
                Navigator.pop(context);
                final completedCount =
                    _items.where((item) => item.completed).length;
                final totalCount = _items.length + _archived.length;
                final activeHabitsCount = _habits.length;

                // Перевірка досягнень
                final hasNightTask = _items.any((item) {
                  if (item.createdAt == null) return false;
                  final hour = item.createdAt!.hour;
                  return hour >= 22 || hour < 6;
                });

                final hasEarlyTask = _items.any((item) {
                  if (!item.completed || item.completedAt == null) return false;
                  final hour = item.completedAt!.hour;
                  return hour < 8;
                });

                final hasSameDayTask = _items.any((item) {
                  if (!item.completed ||
                      item.createdAt == null ||
                      item.completedAt == null) return false;
                  final created = item.createdAt!;
                  final completed = item.completedAt!;
                  return created.year == completed.year &&
                      created.month == completed.month &&
                      created.day == completed.day;
                });

                int maxStreak = 0;
                for (final habit in _habits) {
                  int streak = _calculateStreak(habit);
                  if (streak > maxStreak) maxStreak = streak;
                }

                Navigator.push(
                  context,
                  _createRoute(
                    AchievementsPage(
                      totalTasks: totalCount,
                      completedTasks: completedCount,
                      habitsCount: activeHabitsCount,
                      hasNightTask: hasNightTask,
                      hasEarlyTask: hasEarlyTask,
                      hasSameDayTask: hasSameDayTask,
                      maxHabitStreak: maxStreak,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: Text(loc.statistics),
              onTap: () {
                Navigator.pop(context);

                // Підрахунок активності за останні 7 днів
                final weeklyActivity = <int>[];
                final now = DateTime.now();
                for (int i = 6; i >= 0; i--) {
                  final day = DateTime(now.year, now.month, now.day)
                      .subtract(Duration(days: i));
                  final count = _items.where((task) {
                    if (task.completedAt == null) return false;
                    final completed = task.completedAt!;
                    return completed.year == day.year &&
                        completed.month == day.month &&
                        completed.day == day.day;
                  }).length;
                  weeklyActivity.add(count);
                }

                Navigator.push(
                  context,
                  _createRoute(
                    StatisticsPage(
                      totalTasks: _items.length,
                      completedTasks: _items.where((t) => t.completed).length,
                      habitsCount: _habits.length,
                      activeHabitsStreak: _habits.isEmpty
                          ? 0
                          : _habits
                              .map((h) => _calculateStreak(h))
                              .reduce((a, b) => a > b ? a : b),
                      weeklyActivity: weeklyActivity,
                      archivedTasks: _archived.length,
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
                // Оновлюємо налаштування після повернення
                final prefs = await SharedPreferences.getInstance();
                final showCompleted = prefs.getBool('show_completed') ?? true;
                if (mounted) {
                  setState(() {
                    _showCompletedTasks = showCompleted;
                  });
                }
              },
            ),
          ],
        ),
      ),
      body: [
        _buildTasksTab(),
        _buildCalendarTab(),
        _buildHabitsTab(),
      ][_currentTabIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.task_alt),
            label: loc.tasks,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.calendar_today),
            label: loc.calendar,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite),
            label: loc.habits,
          ),
        ],
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton(
              onPressed: _openAddDialog,
              child: const Icon(Icons.add),
              tooltip: loc.addTask,
            )
          : _currentTabIndex == 2
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search), hintText: loc.search),
                onChanged: (v) => setState(() => _search = v),
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
                              ? '${it.reminderAt!.hour.toString().padLeft(2, '0')}:${it.reminderAt!.minute.toString().padLeft(2, '0')}'
                              : null;
                          return Dismissible(
                            key: ValueKey(it.id),
                            direction: DismissDirection.horizontal,
                            background: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: Alignment.centerLeft,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: const Icon(Icons.edit, color: Colors.white),
                            ),
                            secondaryBackground: Container(
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
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                _openEditTaskDialog(it);
                                return false;
                              }
                              return true;
                            },
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
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (it.notes != null &&
                                        it.notes!.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          it.notes!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.7),
                                          ),
                                        ),
                                      ),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 2,
                                      children: [
                                        if (it.priority != null)
                                          Chip(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              avatar: Icon(Icons.flag,
                                                  size: 14,
                                                  color: _getPriorityColor(
                                                      it.priority)),
                                              label: Text(
                                                  it.priority ==
                                                          TaskPriority.low
                                                      ? 'Низький'
                                                      : it.priority ==
                                                              TaskPriority
                                                                  .medium
                                                          ? 'Середній'
                                                          : 'Високий',
                                                  style: const TextStyle(
                                                      fontSize: 11))),
                                        if (it.dueDate != null)
                                          Chip(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              avatar: Icon(Icons.calendar_today,
                                                  size: 14,
                                                  color: it.dueDate!.isBefore(
                                                              DateTime.now()) &&
                                                          !it.completed
                                                      ? Colors.red
                                                      : null),
                                              label: Text(
                                                  '${it.dueDate!.day}.${it.dueDate!.month}.${it.dueDate!.year}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: it.dueDate!.isBefore(
                                                                DateTime
                                                                    .now()) &&
                                                            !it.completed
                                                        ? Colors.red
                                                        : null,
                                                    fontWeight: it.dueDate!
                                                                .isBefore(DateTime
                                                                    .now()) &&
                                                            !it.completed
                                                        ? FontWeight.bold
                                                        : null,
                                                  ))),
                                        if (due != null)
                                          Chip(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              avatar: const Icon(Icons.alarm,
                                                  size: 14),
                                              label: Text(due,
                                                  style: const TextStyle(
                                                      fontSize: 11))),
                                      ],
                                    ),
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
                // Selected day tasks
                if (_selectedDay != null) ...[
                  Text(
                    '${_selectedDay!.day} ${_monthName(_selectedDay!.month)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),

                  // Завдання
                  if (_getTasksForDay(_selectedDay!).isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.task_alt, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          loc.tasks,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ..._buildSelectedDayTasks(_selectedDay!),
                    const SizedBox(height: 16),
                  ],

                  // Звички
                  if (_getHabitsForDay(_selectedDay!).isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.repeat, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          loc.habits,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ..._buildSelectedDayHabits(_selectedDay!),
                  ],

                  // Якщо немає ні завдань, ні звичок
                  if (_getTasksForDay(_selectedDay!).isEmpty &&
                      _getHabitsForDay(_selectedDay!).isEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.event_busy,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                loc.emptyList,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

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

            // Всі завдання на цей день (для підрахунку кольору)
            final allTasksOnDay = _items
                .where((i) =>
                    i.dueDate != null &&
                    i.dueDate!.year == date.year &&
                    i.dueDate!.month == date.month &&
                    i.dueDate!.day == date.day)
                .toList();

            final completedOnDay =
                allTasksOnDay.where((i) => i.completed).length;
            final totalOnDay = allTasksOnDay.length;

            // Звички на цей день
            final weekday = date.weekday;
            final habitsOnDay = _habits
                .where((h) => h.active && h.selectedDays.contains(weekday))
                .toList();
            final completedHabitsOnDay = habitsOnDay
                .where((h) => h.completedDates.any((d) =>
                    d.year == date.year &&
                    d.month == date.month &&
                    d.day == date.day))
                .length;
            final totalHabitsOnDay = habitsOnDay.length;

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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dayNumber.toString(),
                      style: TextStyle(
                        fontWeight: isToday || isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                        color: isSelected ? Colors.white : null,
                      ),
                    ),
                    if (totalOnDay > 0 || totalHabitsOnDay > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Точка для завдань
                          if (totalOnDay > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 2, right: 2),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: completedOnDay == totalOnDay
                                    ? Colors.green
                                    : completedOnDay > 0
                                        ? Colors.orange
                                        : Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          // Точка для звичок
                          if (totalHabitsOnDay > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 2, left: 2),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: completedHabitsOnDay == totalHabitsOnDay
                                    ? Colors.green
                                    : completedHabitsOnDay > 0
                                        ? Colors.orange
                                        : Colors.purple,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
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

  List<TaskItem> _getTasksForDay(DateTime day) {
    return _items
        .where((i) =>
            i.dueDate != null &&
            i.dueDate!.year == day.year &&
            i.dueDate!.month == day.month &&
            i.dueDate!.day == day.day &&
            (_showCompletedTasks || !i.completed))
        .toList();
  }

  List<Habit> _getHabitsForDay(DateTime day) {
    final weekday = day.weekday; // 1=Monday, 7=Sunday
    return _habits
        .where((h) => h.active && h.selectedDays.contains(weekday))
        .toList();
  }

  List<Widget> _buildSelectedDayHabits(DateTime selectedDay) {
    final habitsForDay = _getHabitsForDay(selectedDay);
    final loc = AppLocalizations.of(context);

    return habitsForDay.map((habit) {
      final isCompleted = habit.completedDates.any((d) =>
          d.year == selectedDay.year &&
          d.month == selectedDay.month &&
          d.day == selectedDay.day);

      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: Icon(
            isCompleted ? Icons.check_circle : Icons.circle_outlined,
            color: isCompleted ? Colors.green : Colors.grey,
            size: 32,
          ),
          title: Text(
            habit.name,
            style: TextStyle(
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              color: isCompleted ? Colors.grey : null,
            ),
          ),
          subtitle: habit.description != null && habit.description!.isNotEmpty
              ? Text(habit.description!,
                  maxLines: 1, overflow: TextOverflow.ellipsis)
              : null,
          trailing:
              Icon(habit.icon, color: Theme.of(context).colorScheme.primary),
          onTap: () {
            setState(() {
              if (isCompleted) {
                habit.completedDates.removeWhere((d) =>
                    d.year == selectedDay.year &&
                    d.month == selectedDay.month &&
                    d.day == selectedDay.day);
              } else {
                habit.completedDates.add(selectedDay);
              }
            });
            _saveData();
          },
        ),
      );
    }).toList();
  }

  List<Widget> _buildSelectedDayTasks(DateTime selectedDay) {
    final tasksForDay = _getTasksForDay(selectedDay);

    if (tasksForDay.isEmpty) {
      return [];
    }

    final loc = AppLocalizations.of(context);

    return tasksForDay
        .map((it) => Dismissible(
              key: ValueKey('calendar_${it.id}'),
              direction: DismissDirection.horizontal,
              background: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.edit, color: Colors.white),
              ),
              secondaryBackground: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  // Редагування
                  _openEditTaskDialog(it);
                  return false;
                } else {
                  // Видалення
                  return true;
                }
              },
              onDismissed: (direction) {
                setState(() {
                  _items.remove(it);
                });
                _saveData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${loc.deletedTask}: ${it.name}'),
                    behavior: SnackBarBehavior.floating,
                    action: SnackBarAction(
                      label: loc.undo,
                      onPressed: () {
                        setState(() {
                          _items.add(it);
                        });
                        _saveData();
                      },
                    ),
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
                      if (it.priority != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getPriorityColor(it.priority),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            it.priority == TaskPriority.low
                                ? 'Низький'
                                : it.priority == TaskPriority.medium
                                    ? 'Середній'
                                    : 'Високий',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (it.favorite)
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                    ],
                  ),
                  onTap: () => setState(() {
                    it.completed = !it.completed;
                    if (it.completed) {
                      it.completedAt = DateTime.now();
                    } else {
                      it.completedAt = null;
                    }
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
                  direction: DismissDirection.horizontal,
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.edit, color: Colors.white),
                  ),
                  secondaryBackground: Container(
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
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      _openEditHabitDialog(habit);
                      return false;
                    }
                    return true;
                  },
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
                              Text(
                                  '${AppLocalizations.of(context).translate('days') ?? 'Дні'}: ',
                                  style: const TextStyle(fontSize: 11)),
                              ...[
                                AppLocalizations.of(context).mon,
                                AppLocalizations.of(context).tue,
                                AppLocalizations.of(context).wed,
                                AppLocalizations.of(context).thu,
                                AppLocalizations.of(context).fri,
                                AppLocalizations.of(context).sat,
                                AppLocalizations.of(context).sun
                              ].asMap().entries.map((entry) {
                                final dayNumber = entry.key + 1;
                                final isSelected =
                                    habit.selectedDays.contains(dayNumber);
                                return Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black,
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
                          if (habit.reminderTime != null)
                            Text(
                              '⏰ ${habit.reminderTime!.hour.toString().padLeft(2, '0')}:${habit.reminderTime!.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.blue),
                            ),
                        ],
                      ),
                      trailing: habit.isActiveToday()
                          ? GestureDetector(
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
                            )
                          : const Icon(Icons.remove_circle_outline,
                              color: Colors.grey),
                      onTap: () {
                        if (habit.isActiveToday()) {
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
                        }
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  int _getTodayTasksCount() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _items.where((item) {
      if (item.dueDate == null) return false;
      final dueDay = DateTime(
        item.dueDate!.year,
        item.dueDate!.month,
        item.dueDate!.day,
      );
      return dueDay.isAtSameMomentAs(today);
    }).length;
  }

  void _openAddHabitDialog() {
    final loc = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var selectedFreq = HabitFrequency.daily;
    var selectedIcon = Icons.check_circle;
    var selectedDays = <int>[1, 2, 3, 4, 5, 6, 7]; // For daily frequency
    TimeOfDay? selectedReminderTime;

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

    final dayNames = [
      loc.mon,
      loc.tue,
      loc.wed,
      loc.thu,
      loc.fri,
      loc.sat,
      loc.sun
    ];

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
                        if (f == HabitFrequency.daily) {
                          selectedDays = [1, 2, 3, 4, 5, 6, 7];
                        } else if (f == HabitFrequency.weekly) {
                          selectedDays = [];
                        }
                      });
                    }
                  },
                ),
                if (selectedFreq == HabitFrequency.weekly) ...[
                  const SizedBox(height: 16),
                  Text(loc.selectDays,
                      style: Theme.of(context).textTheme.labelLarge),
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
                            color: isSelected ? Colors.white : Colors.grey[200],
                            border: isSelected
                                ? Border.all(
                                    color: Theme.of(context).primaryColor,
                                    width: 3,
                                  )
                                : null,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              dayNames[index],
                              style: TextStyle(
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
                const SizedBox(height: 16),
                Text(loc.icon, style: Theme.of(context).textTheme.labelLarge),
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
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey[200],
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
                const SizedBox(height: 16),
                // Нагадування
                OutlinedButton.icon(
                  icon: Icon(
                    selectedReminderTime != null
                        ? Icons.check_circle
                        : Icons.alarm,
                    color: selectedReminderTime != null ? Colors.green : null,
                  ),
                  label: Text(selectedReminderTime == null
                      ? loc.addReminder
                      : '⏰ ${selectedReminderTime!.hour.toString().padLeft(2, '0')}:${selectedReminderTime!.minute.toString().padLeft(2, '0')}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: selectedReminderTime != null
                        ? Colors.blue.shade50
                        : null,
                  ),
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedReminderTime ??
                          const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (time != null) {
                      setState(() => selectedReminderTime = time);
                    }
                  },
                ),
                if (selectedReminderTime != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Прибрати'),
                      onPressed: () {
                        setState(() => selectedReminderTime = null);
                      },
                    ),
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
                final newHabit = Habit(
                  name: name,
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  frequency: selectedFreq,
                  icon: selectedIcon,
                  selectedDays: selectedDays,
                  reminderTime: selectedReminderTime,
                );
                this.setState(() {
                  _habits.add(newHabit);
                });
                _saveData();

                // Плануємо нагадування
                if (selectedReminderTime != null) {
                  _scheduleHabitReminders(newHabit);
                }

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
    TimeOfDay? selectedReminderTime = habit.reminderTime;

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

    final dayNames = [
      loc.mon,
      loc.tue,
      loc.wed,
      loc.thu,
      loc.fri,
      loc.sat,
      loc.sun
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(loc.editHabit),
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
                        if (f == HabitFrequency.daily) {
                          selectedDays = [1, 2, 3, 4, 5, 6, 7];
                        } else if (f == HabitFrequency.weekly) {
                          selectedDays = [];
                        }
                      });
                    }
                  },
                ),
                if (selectedFreq == HabitFrequency.weekly) ...[
                  const SizedBox(height: 16),
                  Text(loc.selectDays,
                      style: Theme.of(context).textTheme.labelLarge),
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
                            color: isSelected ? Colors.white : Colors.grey[200],
                            border: isSelected
                                ? Border.all(
                                    color: Theme.of(context).primaryColor,
                                    width: 3,
                                  )
                                : null,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              dayNames[index],
                              style: TextStyle(
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
                const SizedBox(height: 16),
                Text(loc.icon, style: Theme.of(context).textTheme.labelLarge),
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
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey[200],
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
                const SizedBox(height: 16),
                // Нагадування
                OutlinedButton.icon(
                  icon: Icon(
                    selectedReminderTime != null
                        ? Icons.check_circle
                        : Icons.alarm,
                    color: selectedReminderTime != null ? Colors.green : null,
                  ),
                  label: Text(selectedReminderTime == null
                      ? loc.addReminder
                      : '⏰ ${selectedReminderTime!.hour.toString().padLeft(2, '0')}:${selectedReminderTime!.minute.toString().padLeft(2, '0')}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: selectedReminderTime != null
                        ? Colors.blue.shade50
                        : null,
                  ),
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedReminderTime ??
                          const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (time != null) {
                      setState(() => selectedReminderTime = time);
                    }
                  },
                ),
                if (selectedReminderTime != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Прибрати'),
                      onPressed: () {
                        setState(() => selectedReminderTime = null);
                      },
                    ),
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

                // Скасовуємо старі нагадування
                _cancelHabitReminders(habit);

                this.setState(() {
                  habit.name = name;
                  habit.description = descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim();
                  habit.frequency = selectedFreq;
                  habit.icon = selectedIcon;
                  habit.selectedDays = selectedDays;
                  habit.reminderTime = selectedReminderTime;
                });
                _saveData();

                // Плануємо нові нагадування
                if (selectedReminderTime != null) {
                  _scheduleHabitReminders(habit);
                }

                Navigator.of(ctx).pop();
              },
              child: Text(loc.translate('save') ?? 'Зберегти'),
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
                  size: 16, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface)),
              ),
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

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_isLogin) {
        await _authService.signIn(email, password);
      } else {
        await _authService.signUp(email, password);
        _showMessage('✅ Успішно зареєстровано!');
      }
    } catch (e) {
      String message = 'Помилка';
      final errorMsg = e.toString().toLowerCase();

      if (errorMsg.contains('user not found') ||
          errorMsg.contains('invalid login') ||
          errorMsg.contains('invalid_credentials')) {
        message = 'Невірний email або пароль';
      } else if (errorMsg.contains('invalid password') ||
          errorMsg.contains('wrong password')) {
        message = 'Невірний пароль';
      } else if (errorMsg.contains('already registered') ||
          errorMsg.contains('already in use') ||
          errorMsg.contains('user_already_exists')) {
        message = 'Email вже використовується';
      } else if (errorMsg.contains('weak password') ||
          errorMsg.contains('password is too short') ||
          errorMsg.contains('password should be at least')) {
        message = 'Пароль занадто слабкий (мінімум 6 символів)';
      } else if (errorMsg.contains('invalid email') ||
          errorMsg.contains('invalid_email') ||
          errorMsg.contains('unable to validate email') ||
          errorMsg.contains('invalid format')) {
        message = 'Невірний формат email. Перевірте правильність введення';
      } else if (errorMsg.contains('email not confirmed')) {
        message = 'Підтвердіть email. Перевірте пошту';
      } else {
        message = 'Помилка входу. Спробуйте ще раз';
      }
      _showMessage(message);
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

// Сторінка вхідних завдань
class InboxPage extends StatelessWidget {
  final List<TaskItem> items;
  final void Function(TaskItem) onToggle;
  final void Function(TaskItem) onDelete;
  final void Function(TaskItem) onEdit;

  const InboxPage({
    super.key,
    required this.items,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final inboxItems = items.where((item) => !item.completed).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.inbox),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
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
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.inbox,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      loc.inbox,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  loc.inboxDesc,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pending_actions,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${inboxItems.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            loc.toDo,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Список завдань
          Expanded(
            child: inboxItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Всі завдання виконано! 🎉',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Додайте нові завдання',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: inboxItems.length,
                    itemBuilder: (ctx, i) {
                      final item = inboxItems[i];
                      return Dismissible(
                        key: Key(item.id),
                        background: Container(
                          color: Colors.green,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          child: const Icon(Icons.check, color: Colors.white),
                        ),
                        secondaryBackground: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.startToEnd) {
                            onToggle(item);
                            return false;
                          }
                          return true;
                        },
                        onDismissed: (direction) {
                          onDelete(item);
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Checkbox(
                              value: item.completed,
                              onChanged: (_) => onToggle(item),
                            ),
                            title: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.notes != null &&
                                    item.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.notes!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (item.priority != null) ...[
                                      Icon(
                                        Icons.flag,
                                        size: 16,
                                        color: _getPriorityColor(item.priority),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.priority == TaskPriority.low
                                            ? 'Низький'
                                            : item.priority ==
                                                    TaskPriority.medium
                                                ? 'Середній'
                                                : 'Високий',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                    if (item.dueDate != null) ...[
                                      if (item.priority != null)
                                        const SizedBox(width: 12),
                                      Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: _isOverdue(item.dueDate!)
                                            ? Colors.red
                                            : Colors.blue,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDueDate(item.dueDate!),
                                        style: TextStyle(
                                          color: _isOverdue(item.dueDate!)
                                              ? Colors.red
                                              : Colors.blue,
                                          fontWeight: _isOverdue(item.dueDate!)
                                              ? FontWeight.bold
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => onEdit(item),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(TaskPriority? priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.blue;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
      case null:
        return Colors.grey;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'work':
      case 'Work':
      case 'Робота':
        return Colors.blue;
      case 'personal':
      case 'Personal':
      case 'Особисте':
        return Colors.green;
      case 'Home':
      case 'Дім':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  bool _isOverdue(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.isBefore(today);
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dueDay = DateTime(date.year, date.month, date.day);

    if (dueDay.isAtSameMomentAs(today)) {
      return 'Сьогодні';
    } else if (dueDay.isAtSameMomentAs(tomorrow)) {
      return 'Завтра';
    } else if (dueDay.isBefore(today)) {
      final diff = today.difference(dueDay).inDays;
      return 'Прострочено на $diff дн.';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }
}

// Сторінка завдань на сьогодні
class TodayTasksPage extends StatelessWidget {
  final List<TaskItem> items;
  final void Function(TaskItem) onToggle;
  final void Function(TaskItem) onDelete;
  final void Function(TaskItem) onEdit;

  const TodayTasksPage({
    super.key,
    required this.items,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  List<TaskItem> _getTodayTasks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return items.where((item) {
      if (item.dueDate == null) return false;
      final dueDay = DateTime(
        item.dueDate!.year,
        item.dueDate!.month,
        item.dueDate!.day,
      );
      return dueDay.isAtSameMomentAs(today);
    }).toList();
  }

  Color _getPriorityColor(TaskPriority? priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.blue;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
      case null:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final todayTasks = _getTodayTasks();
    final completedToday = todayTasks.where((t) => t.completed).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.today),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header з інформацією про сьогоднішній день
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.secondary,
                  Theme.of(context).colorScheme.primary,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.today,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      loc.today,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDate(DateTime.now(), context),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatChip(
                      context,
                      Icons.task_alt,
                      '$completedToday/${todayTasks.length}',
                      loc.completed,
                    ),
                    const SizedBox(width: 12),
                    if (todayTasks.length - completedToday > 0)
                      _buildStatChip(
                        context,
                        Icons.pending_actions,
                        '${todayTasks.length - completedToday}',
                        loc.toDo,
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Список завдань
          Expanded(
            child: todayTasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Немає завдань на сьогодні',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Додайте завдання з датою на сьогодні',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: todayTasks.length,
                    itemBuilder: (ctx, i) {
                      final item = todayTasks[i];
                      return Dismissible(
                        key: Key(item.id),
                        background: Container(
                          color: Colors.green,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          child: const Icon(Icons.check, color: Colors.white),
                        ),
                        secondaryBackground: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.startToEnd) {
                            onToggle(item);
                            return false;
                          }
                          return true;
                        },
                        onDismissed: (direction) {
                          onDelete(item);
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Checkbox(
                              value: item.completed,
                              onChanged: (_) => onToggle(item),
                            ),
                            title: Text(
                              item.name,
                              style: TextStyle(
                                decoration: item.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.notes != null &&
                                    item.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.notes!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (item.priority != null) ...[
                                      Icon(
                                        Icons.flag,
                                        size: 16,
                                        color: _getPriorityColor(item.priority),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.priority == TaskPriority.low
                                            ? 'Низький'
                                            : item.priority ==
                                                    TaskPriority.medium
                                                ? 'Середній'
                                                : 'Високий',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => onEdit(item),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date, BuildContext context) {
    final loc = AppLocalizations.of(context);
    final days = [
      loc.mon,
      loc.tue,
      loc.wed,
      loc.thu,
      loc.fri,
      loc.sat,
      loc.sun
    ];
    final months = [
      loc.january,
      loc.february,
      loc.march,
      loc.april,
      loc.may,
      loc.june,
      loc.july,
      loc.august,
      loc.september,
      loc.october,
      loc.november,
      loc.december
    ];

    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Робота':
      case 'Work':
        return Colors.blue;
      case 'Особисте':
      case 'Personal':
        return Colors.green;
      case 'Дім':
      case 'Home':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class StatisticsPage extends StatelessWidget {
  final int totalTasks;
  final int completedTasks;
  final int habitsCount;
  final int activeHabitsStreak;
  final List<int> weeklyActivity; // Активність за останні 7 днів
  final int archivedTasks;

  const StatisticsPage({
    super.key,
    required this.totalTasks,
    required this.completedTasks,
    required this.habitsCount,
    required this.activeHabitsStreak,
    this.weeklyActivity = const [0, 0, 0, 0, 0, 0, 0],
    this.archivedTasks = 0,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final completionRate =
        totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 0;
    final maxActivity = weeklyActivity.isEmpty
        ? 1
        : weeklyActivity.reduce((a, b) => a > b ? a : b);
    final weekDays = [
      loc.mon,
      loc.tue,
      loc.wed,
      loc.thu,
      loc.fri,
      loc.sat,
      loc.sun
    ];

    // Визначаємо дні тижня для відображення
    final today = DateTime.now().weekday; // 1 = Monday, 7 = Sunday
    final orderedDays = <String>[];
    for (int i = 6; i >= 0; i--) {
      final dayIndex = (today - 1 - i) % 7;
      orderedDays.add(weekDays[dayIndex < 0 ? dayIndex + 7 : dayIndex]);
    }

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

              // Графік активності за тиждень
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_up,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            loc.monthStatistics,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 120,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(7, (index) {
                            final activity = weeklyActivity.length > index
                                ? weeklyActivity[index]
                                : 0;
                            final height = maxActivity > 0
                                ? (activity / maxActivity * 80).clamp(4.0, 80.0)
                                : 4.0;
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  activity.toString(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: 32,
                                  height: height,
                                  decoration: BoxDecoration(
                                    color: activity > 0
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  orderedDays[index],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: index == 6
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.shade600,
                                    fontWeight: index == 6
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

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
                        '$completedTasks / $totalTasks ${loc.tasksCompleted}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
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

class ProfilePage extends StatefulWidget {
  final String? avatarBase64;
  final String userName;
  final void Function(String) onUserNameChanged;
  final void Function(String?) onAvatarChanged;

  const ProfilePage({
    super.key,
    this.avatarBase64,
    required this.userName,
    required this.onUserNameChanged,
    required this.onAvatarChanged,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late String _currentName;
  String? _currentAvatar;

  @override
  void initState() {
    super.initState();
    _currentName = widget.userName;
    _currentAvatar = widget.avatarBase64;
  }

  Future<void> _pickAvatar() async {
    final loc = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Вибрати з галереї'),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 80,
                );
                if (picked != null) {
                  final bytes = await picked.readAsBytes();
                  final base64 = base64Encode(bytes);
                  setState(() {
                    _currentAvatar = base64;
                  });
                  widget.onAvatarChanged(base64);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Аватарку змінено'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Зробити фото'),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 80,
                );
                if (picked != null) {
                  final bytes = await picked.readAsBytes();
                  final base64 = base64Encode(bytes);
                  setState(() {
                    _currentAvatar = base64;
                  });
                  widget.onAvatarChanged(base64);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Аватарку змінено'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
            if (_currentAvatar != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Видалити аватарку',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentAvatar = null;
                  });
                  widget.onAvatarChanged(null);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Аватарку видалено'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _currentName);
    final loc = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Змінити ім\'я'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: loc.user,
            hintText: 'Введіть ваше ім\'я',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              setState(() {
                _currentName = newName;
              });
              widget.onUserNameChanged(newName);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ім\'я успішно змінено'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final displayName = _currentName.isEmpty ? loc.user : _currentName;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.profile),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Градієнтний header з аватаркою
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
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white,
                            backgroundImage: _currentAvatar != null
                                ? MemoryImage(base64Decode(_currentAvatar!))
                                : null,
                            child: _currentAvatar == null
                                ? Icon(
                                    Icons.person,
                                    size: 70,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _showEditNameDialog,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TaskFlow • ${DateTime.now().year}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Інформація про акаунт
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.account,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<User?>(
                    future:
                        Future.value(Supabase.instance.client.auth.currentUser),
                    builder: (context, snapshot) {
                      final user = snapshot.data;
                      if (user != null) {
                        return Column(
                          children: [
                            Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  child: const Icon(Icons.email,
                                      color: Colors.white),
                                ),
                                title: const Text('Email'),
                                subtitle: Text(user.email ?? ''),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green,
                                  child: const Icon(Icons.cloud_done,
                                      color: Colors.white),
                                ),
                                title: Text(loc.account),
                                subtitle: Text(loc.cloudSync),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              color: Colors.red.shade50,
                              child: ListTile(
                                leading:
                                    const Icon(Icons.logout, color: Colors.red),
                                title: Text(
                                  loc.logout,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: const Text('Вийти з акаунту'),
                                onTap: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Вийти з акаунту?'),
                                      content: const Text(
                                          'Дані залишаться збережені в хмарі'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: Text(loc.cancel),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: Text(loc.logout),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && context.mounted) {
                                    await AuthService().signOut();
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.remove('auth_skipped');
                                    if (context.mounted) {
                                      Navigator.of(context)
                                          .popUntil((route) => route.isFirst);
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange,
                              child: const Icon(Icons.cloud_off,
                                  color: Colors.white),
                            ),
                            title: Text(loc.localMode),
                            subtitle: Text(loc.localModeDesc),
                            trailing: ElevatedButton(
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
}

// Нова сторінка для досягнень
class AchievementsPage extends StatelessWidget {
  final int totalTasks;
  final int completedTasks;
  final int habitsCount;
  final bool hasNightTask;
  final bool hasEarlyTask;
  final bool hasSameDayTask;
  final int maxHabitStreak;

  const AchievementsPage({
    super.key,
    required this.totalTasks,
    required this.completedTasks,
    required this.habitsCount,
    this.hasNightTask = false,
    this.hasEarlyTask = false,
    this.hasSameDayTask = false,
    this.maxHabitStreak = 0,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.achievements),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      size: 64,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      loc.achievements,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_unlockedCount()} з ${_totalAchievements()} розблоковано',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                loc.yourAchievements,
                style: Theme.of(context).textTheme.titleLarge,
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
                Icons.diamond,
                loc.perfectionist,
                loc.perfectionistDesc,
                completedTasks >= 100,
              ),
              const SizedBox(height: 12),
              _buildAchievementCard(
                context,
                Icons.favorite,
                loc.habitMaster,
                loc.habitMasterDesc,
                habitsCount >= 5,
              ),
              const SizedBox(height: 12),
              _buildAchievementCard(
                context,
                Icons.local_fire_department,
                loc.streakMaster,
                loc.streakMasterDesc,
                maxHabitStreak >= 7,
              ),
              const SizedBox(height: 12),
              _buildAchievementCard(
                context,
                Icons.nightlight_round,
                loc.nightOwl,
                loc.nightOwlDesc,
                hasNightTask,
              ),
              const SizedBox(height: 12),
              _buildAchievementCard(
                context,
                Icons.wb_sunny,
                loc.earlyBird,
                loc.earlyBirdDesc,
                hasEarlyTask,
              ),
              const SizedBox(height: 12),
              _buildAchievementCard(
                context,
                Icons.bolt,
                loc.speedRunner,
                loc.speedRunnerDesc,
                hasSameDayTask,
              ),
              const SizedBox(height: 12),
              _buildAchievementCard(
                context,
                Icons.star,
                loc.collector,
                loc.collectorDesc,
                _unlockedCount() >= 9,
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _unlockedCount() {
    int count = 0;
    if (totalTasks > 0) count++;
    if (completedTasks >= 10) count++;
    if (completedTasks >= 50) count++;
    if (completedTasks >= 100) count++;
    if (habitsCount >= 5) count++;
    if (maxHabitStreak >= 7) count++;
    if (hasNightTask) count++;
    if (hasEarlyTask) count++;
    if (hasSameDayTask) count++;
    return count;
  }

  int _totalAchievements() => 10;

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
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            radius: 30,
            backgroundColor: unlocked
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            child: Icon(
              icon,
              size: 30,
              color: unlocked ? Colors.white : Colors.grey.shade500,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: unlocked ? null : Colors.grey.shade600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              description,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          trailing: unlocked
              ? const Icon(Icons.check_circle, color: Colors.green, size: 32)
              : const Icon(Icons.lock_outline, color: Colors.grey, size: 32),
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
  late ThemeMode _currentTheme;

  @override
  void initState() {
    super.initState();
    _currentTheme = widget.themeMode;
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
    _changeTheme(ThemeMode.system);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Налаштування скинуто')),
      );
    }
  }

  void _changeTheme(ThemeMode mode) {
    setState(() {
      _currentTheme = mode;
    });
    widget.onThemeChanged(mode);
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
                  groupValue: _currentTheme,
                  onChanged: (v) => _changeTheme(ThemeMode.light),
                ),
                onTap: () => _changeTheme(ThemeMode.light),
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: Text(loc.darkTheme),
                trailing: Radio<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: _currentTheme,
                  onChanged: (v) => _changeTheme(ThemeMode.dark),
                ),
                onTap: () => _changeTheme(ThemeMode.dark),
              ),
              ListTile(
                leading: const Icon(Icons.phone_android),
                title: Text(loc.systemTheme),
                trailing: Radio<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: _currentTheme,
                  onChanged: (v) => _changeTheme(ThemeMode.system),
                ),
                onTap: () => _changeTheme(ThemeMode.system),
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
                subtitle: Text(loc.notificationsSubtitle),
                value: _notificationsEnabled,
                onChanged: (val) {
                  setState(() => _notificationsEnabled = val);
                  _saveSetting('notifications_enabled', val);
                },
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
              _buildLanguageTile(context, 'English', 'en', currentLocale,
                  widget.onLanguageChanged),
              _buildLanguageTile(context, 'Deutsch', 'de', currentLocale,
                  widget.onLanguageChanged),
              _buildLanguageTile(context, 'Español', 'es', currentLocale,
                  widget.onLanguageChanged),
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











