"""
Konfiguracja panelu administracyjnego Django dla aplikacji wyszukiwania.
Rejestruje modele SearchQuery i FoundArticle w panelu admina.
"""

from django.contrib import admin
from .models import SearchQuery, FoundArticle


@admin.register(SearchQuery)
class SearchQueryAdmin(admin.ModelAdmin):
    """
    Konfiguracja wyświetlania modelu SearchQuery w panelu admina.
    """
    # Kolumny wyświetlane w liście
    list_display = ("id", "query", "site", "status", "created_at")
    # Pola tylko do odczytu
    readonly_fields = ("created_at",)


@admin.register(FoundArticle)
class FoundArticleAdmin(admin.ModelAdmin):
    """
    Konfiguracja wyświetlania modelu FoundArticle w panelu admina.
    """
    # Kolumny wyświetlane w liście
    list_display = ("id", "title", "url", "downloaded", "pdf_filename", "created_at")
    # Pola tylko do odczytu
    readonly_fields = ("created_at",)
