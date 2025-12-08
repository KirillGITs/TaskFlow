import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() => runApp(const TaskManagerApp());

enum TaskCategory { work, personal, home, other }

enum HabitFrequency { daily, weekly, monthly }

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
      icon: IconData(iconCodePoint, fontFamily: 'MaterialIcons'),
      color: Color(map['color'] as int? ?? Colors.blue.value),
    );
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
      'habit_name': 'Nazwa nawyku',
      'description': 'Opis (opcjonalnie)',
      'frequency': 'Częstotliwość',
      'confirm_clear_tasks': 'Czy na pewno chcesz usunąć wszystkie zadania?',
      'confirm_clear_archive':
          'Czy na pewno chcesz usunąć wszystkie zarchiwizowane zadania?',
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
      'habit_name': 'Назва звички',
      'description': 'Опис (опціонально)',
      'frequency': 'Частота',
      'confirm_clear_tasks': 'Ви впевнені, що хочете видалити всі завдання?',
      'confirm_clear_archive':
          'Ви впевнені, що хочете видалити всі заархівовані завдання?',
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
      'habit_name': 'Название привычки',
      'description': 'Описание (опционально)',
      'frequency': 'Частота',
      'confirm_clear_tasks': 'Вы уверены, что хотите удалить все задачи?',
      'confirm_clear_archive':
          'Вы уверены, что хотите удалить все архивированные задачи?',
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
      'habit_name': 'Habit name',
      'description': 'Description (optional)',
      'frequency': 'Frequency',
      'confirm_clear_tasks': 'Are you sure you want to delete all tasks?',
      'confirm_clear_archive':
          'Are you sure you want to delete all archived tasks?',
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
      'habit_name': 'Gewohnheitsname',
      'description': 'Beschreibung (optional)',
      'frequency': 'Häufigkeit',
      'confirm_clear_tasks':
          'Sind Sie sicher, dass Sie alle Aufgaben löschen möchten?',
      'confirm_clear_archive':
          'Sind Sie sicher, dass Sie alle archivierten Aufgaben löschen möchten?',
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
      'habit_name': 'Nombre del hábito',
      'description': 'Descripción (opcional)',
      'frequency': 'Frecuencia',
      'confirm_clear_tasks':
          '¿Estás seguro de que quieres eliminar todas las tareas?',
      'confirm_clear_archive':
          '¿Estás seguro de que quieres eliminar todas las tareas archivadas?',
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

  Habit({
    String? id,
    required this.name,
    this.description,
    this.frequency = HabitFrequency.daily,
    this.active = true,
    DateTime? createdAt,
    List<DateTime>? completedDates,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now(),
        completedDates = completedDates ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'frequency': frequency.name,
        'active': active,
        'createdAt': createdAt.toIso8601String(),
        'completedDates':
            completedDates.map((d) => d.toIso8601String()).toList(),
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
    );
  }

  bool isCompletedToday() {
    final today = DateTime.now();
    return completedDates.any((d) =>
        d.year == today.year && d.month == today.month && d.day == today.day);
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
    final savedLang = prefs.getString('language') ?? 'pl';
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
      home: TaskListPage(
          onThemeChanged: _setTheme,
          onLanguageChanged: _setLanguage,
          themeMode: _themeMode),
      debugShowCheckedModeBanner: false,
    );
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itemsRaw = prefs.getStringList('task_items') ?? [];
      final archivedRaw = prefs.getStringList('task_archived') ?? [];
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

      final habitsRaw = prefs.getStringList('habits') ?? [];
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

      final categoriesRaw = prefs.getStringList('custom_categories') ?? [];
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
    _saveData();
  }

  void _toggleFavorite(TaskItem it) {
    setState(() {
      it.favorite = !it.favorite;
    });
    _saveData();
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
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _imageCtrl,
                      decoration: const InputDecoration(
                          labelText: 'URL zdjęcia (opcjonalnie)'),
                      enabled: _selectedImageBase64 == null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _selectedImageBase64 != null
                          ? Icons.check_circle
                          : Icons.photo_library,
                      color: _selectedImageBase64 != null ? Colors.green : null,
                    ),
                    tooltip: _selectedImageBase64 != null
                        ? 'Zdjęcie wybrane'
                        : 'Wybierz zdjęcie',
                    onPressed: _pickImage,
                  ),
                  if (_selectedImageBase64 != null)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      tooltip: 'Usuń zdjęcie',
                      onPressed: () =>
                          setState(() => _selectedImageBase64 = null),
                    ),
                ],
              ),
              if (_selectedImageBase64 != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(_selectedImageBase64!),
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
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
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: loc.settings,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => SettingsPage(
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
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTasksTab(),
          _buildCalendarTab(),
          _buildHabitsTab(),
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
    const months = [
      'Styczeń',
      'Luty',
      'Marzec',
      'Kwiecień',
      'Maj',
      'Czerwiec',
      'Lipiec',
      'Sierpień',
      'Wrzesień',
      'Październik',
      'Listopad',
      'Grudzień'
    ];
    return months[month - 1];
  }

  Widget _buildCalendarGrid(int daysInMonth, int firstWeekday, DateTime today) {
    const dayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];

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
        .map((it) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Icon(
                  it.completed ? Icons.check_circle : Icons.circle_outlined,
                  color: it.completed ? Colors.green : Colors.grey,
                  size: 32,
                ),
                title: Text(
                  it.name,
                  style: it.completed
                      ? const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey)
                      : null,
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
                      const Icon(Icons.star, color: Colors.amber, size: 20),
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
                      leading: Icon(
                        habit.isCompletedToday()
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: Colors.red,
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
                          const SizedBox(height: 4),
                          Text('${loc.streak}: $streak ${loc.days}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      trailing: GestureDetector(
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
                      ),
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
                this.setState(() {
                  _habits.add(Habit(
                    name: name,
                    description: descCtrl.text.trim().isEmpty
                        ? null
                        : descCtrl.text.trim(),
                    frequency: selectedFreq,
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
                this.setState(() {
                  habit.name = name;
                  habit.description = descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim();
                  habit.frequency = selectedFreq;
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

class SettingsPage extends StatelessWidget {
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
                  groupValue: themeMode,
                  onChanged: (v) => onThemeChanged(v!),
                ),
                onTap: () => onThemeChanged(ThemeMode.light),
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: Text(loc.darkTheme),
                trailing: Radio<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (v) => onThemeChanged(v!),
                ),
                onTap: () => onThemeChanged(ThemeMode.dark),
              ),
              ListTile(
                leading: const Icon(Icons.phone_android),
                title: Text(loc.systemTheme),
                trailing: Radio<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (v) => onThemeChanged(v!),
                ),
                onTap: () => onThemeChanged(ThemeMode.system),
              ),
            ],
          ),
          const Divider(),
          _buildSection(
            context,
            loc.language,
            Icons.language,
            [
              _buildLanguageTile(
                  context, 'Polski', 'pl', currentLocale, onLanguageChanged),
              _buildLanguageTile(context, 'Українська', 'uk', currentLocale,
                  onLanguageChanged),
              _buildLanguageTile(
                  context, 'Русский', 'ru', currentLocale, onLanguageChanged),
              _buildLanguageTile(
                  context, 'English', 'en', currentLocale, onLanguageChanged),
              _buildLanguageTile(
                  context, 'Deutsch', 'de', currentLocale, onLanguageChanged),
              _buildLanguageTile(
                  context, 'Español', 'es', currentLocale, onLanguageChanged),
            ],
          ),
          const Divider(),
          _buildSection(
            context,
            loc.category,
            Icons.category,
            [
              ListTile(
                leading: const Icon(Icons.add_circle),
                title: Text(loc.addTask.replaceAll(
                    loc.tasks.toLowerCase(), loc.category.toLowerCase())),
                subtitle: Text(
                    '${customCategories.length} ${loc.category.toLowerCase()}'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => CategoriesManagementPage(
                        categories: customCategories,
                        onSave: onCategoriesChanged,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const Divider(),
          _buildSection(
            context,
            loc.data,
            Icons.storage,
            [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(loc.statistics),
                subtitle: Text(
                    '${loc.totalTasks}: $totalTasks\n${loc.archive}: $archivedCount'),
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
                      onClearAll();
                      Navigator.pop(context);
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: Text(loc.clearArchive),
                subtitle:
                    Text('${loc.delete} $archivedCount ${loc.archivedTasks}'),
                enabled: archivedCount > 0,
                onTap: archivedCount > 0
                    ? () {
                        _showConfirmDialog(
                          context,
                          loc.clearArchive,
                          loc.confirmClearArchive,
                          () {
                            onClearArchived();
                            Navigator.pop(context);
                          },
                        );
                      }
                    : null,
              ),
            ],
          ),
          const Divider(),
          _buildSection(
            context,
            'O aplikacji',
            Icons.info,
            [
              const ListTile(
                leading: Icon(Icons.task_alt),
                title: Text('TaskFlow'),
                subtitle: Text('Wersja 2.0.0\nTwoja lista zadań'),
              ),
            ],
          ),
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
