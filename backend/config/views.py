"""
Widoki konfiguracyjne projektu.
Zawiera podstawowy widok testowy do sprawdzenia połączenia z bazą danych.
"""

from django.http import JsonResponse
from django.db import connection


def hello(request):
    """
    Prosty widok testowy sprawdzający połączenie z PostgreSQL.
    Wykonuje zapytanie do bazy danych i zwraca odpowiedź JSON.
    """
    # Proste zapytanie do PostgreSQL w celu sprawdzenia połączenia
    with connection.cursor() as cursor:
        cursor.execute("SELECT 'Hello from PostgreSQL!'")
        row = cursor.fetchone()
    return JsonResponse({"message": row[0]})
