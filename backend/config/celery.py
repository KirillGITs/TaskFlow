"""
Konfiguracja Celery dla projektu Django.
Celery jest używany do wykonywania zadań asynchronicznych w tle.
"""

import os
from celery import Celery

# Ustawienie domyślnego modułu ustawień Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

# Utworzenie instancji aplikacji Celery
app = Celery('config')

# Ładowanie konfiguracji z ustawień Django
# Użycie stringa oznacza, że worker nie musi serializować
# obiektu konfiguracji do procesów potomnych
app.config_from_object('django.conf:settings', namespace='CELERY')

# Automatyczne wykrywanie zadań ze wszystkich zarejestrowanych aplikacji Django
app.autodiscover_tasks()


@app.task(bind=True)
def debug_task(self):
    """Zadanie debugujące - wyświetla informacje o żądaniu."""
    print(f'Request: {self.request!r}')