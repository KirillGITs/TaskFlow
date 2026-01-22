"""
Moduł modeli bazy danych dla aplikacji wyszukiwania.
Zawiera definicje modeli SearchQuery i FoundArticle.
"""

from django.db import models


class SearchQuery(models.Model):
    """
    Model reprezentujący zapytanie wyszukiwania.
    Przechowuje informacje o słowie kluczowym, stronie i statusie wyszukiwania.
    """
    # Słowo kluczowe wyszukiwania
    query = models.CharField(max_length=200)
    # Strona internetowa do przeszukania
    site = models.CharField(max_length=200)
    # Status wyszukiwania (pending, running, done, error)
    status = models.CharField(max_length=20, default="pending")
    # Data i czas utworzenia zapytania
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.query} @ {self.site} ({self.status})"


class FoundArticle(models.Model):
    """
    Model reprezentujący znaleziony artykuł.
    Przechowuje informacje o tytule, URL, pliku PDF i statusie pobrania.
    """
    # Powiązanie z zapytaniem wyszukiwania
    search = models.ForeignKey(SearchQuery, related_name="results", on_delete=models.CASCADE)
    # Tytuł artykułu
    title = models.CharField(max_length=500)
    # Adres URL artykułu
    url = models.URLField(max_length=1000)
    # Nazwa pliku PDF (jeśli został pobrany)
    pdf_filename = models.CharField(max_length=500, blank=True, null=True)
    # Czy artykuł został pobrany
    downloaded = models.BooleanField(default=False)
    # Data i czas znalezienia artykułu
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.title} - {self.url}"
