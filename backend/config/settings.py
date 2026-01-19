"""
Ustawienia Django dla projektu hello_fullstack.
Zawiera konfigurację bazy danych, aplikacji, middleware i innych ustawień.
"""

import os
from pathlib import Path

# Ścieżka bazowa projektu
BASE_DIR = Path(__file__).resolve().parent.parent

# Klucz tajny (w produkcji należy użyć zmiennej środowiskowej)
SECRET_KEY = "dummy-secret-key-for-hello-project"

# Tryb debugowania (wyłączyć w produkcji)
DEBUG = True

# Lista dozwolonych hostów
ALLOWED_HOSTS = ["*"]

# Lista zainstalowanych aplikacji Django
INSTALLED_APPS = [
    "django.contrib.admin",           # Panel administracyjny
    "django.contrib.auth",            # System uwierzytelniania
    "django.contrib.contenttypes",    # Framework typów zawartości
    "django.contrib.sessions",        # Framework sesji
    "django.contrib.messages",        # Framework wiadomości
    "django.contrib.staticfiles",     # Obsługa plików statycznych
    "rest_framework",                 # Django REST Framework
    "corsheaders",                    # Obsługa CORS
    "search",                         # Aplikacja wyszukiwania
]

# Lista middleware Django
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",          # Middleware bezpieczeństwa
    "corsheaders.middleware.CorsMiddleware",                  # Middleware CORS
    "django.contrib.sessions.middleware.SessionMiddleware",   # Middleware sesji
    "django.middleware.common.CommonMiddleware",              # Wspólny middleware
    "django.middleware.csrf.CsrfViewMiddleware",              # Ochrona CSRF
    "django.contrib.auth.middleware.AuthenticationMiddleware", # Uwierzytelnianie
    "django.contrib.messages.middleware.MessageMiddleware",   # Wiadomości
    "django.middleware.clickjacking.XFrameOptionsMiddleware", # Ochrona przed clickjacking
]

# Główny moduł konfiguracji URL
ROOT_URLCONF = "config.urls"

# Konfiguracja szablonów
TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

# Konfiguracja WSGI
WSGI_APPLICATION = "config.wsgi.application"

# Konfiguracja bazy danych PostgreSQL
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.getenv("DB_NAME", "hello_db"),         # Nazwa bazy danych
        "USER": os.getenv("DB_USER", "hello_user"),       # Użytkownik bazy danych
        "PASSWORD": os.getenv("DB_PASSWORD", "hello_pass"), # Hasło
        "HOST": os.getenv("DB_HOST", "db"),               # Host bazy danych
        "PORT": os.getenv("DB_PORT", "5432"),             # Port
    }
}

# Walidatory haseł (puste dla uproszczenia)
AUTH_PASSWORD_VALIDATORS = []

# Ustawienia lokalizacji
LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

# Konfiguracja plików statycznych
STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

# Konfiguracja plików mediów
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

# Domyślny typ pola auto
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# Konfiguracja CORS - dozwolone źródła
CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://frontend:3000",
    "http://localhost:80",
]

# Zezwolenie na przesyłanie credentials w żądaniach CORS
CORS_ALLOW_CREDENTIALS = True

# Zezwolenie na wszystkie źródła CORS (tylko do rozwoju)
CORS_ALLOW_ALL_ORIGINS = True

# Konfiguracja Celery - broker komunikatów
CELERY_BROKER_URL = os.environ.get('CELERY_BROKER_URL', 'redis://localhost:6379/0')
# Backend wyników Celery
CELERY_RESULT_BACKEND = os.environ.get('CELERY_RESULT_BACKEND', 'redis://localhost:6379/0')
# Akceptowane formaty zawartości
CELERY_ACCEPT_CONTENT = ['json']
# Format serializacji zadań
CELERY_TASK_SERIALIZER = 'json'
# Format serializacji wyników
CELERY_RESULT_SERIALIZER = 'json'
# Strefa czasowa Celery
CELERY_TIMEZONE = 'UTC'
