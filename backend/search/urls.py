"""
Konfiguracja tras URL dla aplikacji wyszukiwania.
Definiuje endpointy API dla wyszukiwania, statusu i pobierania plików.
"""

from django.urls import path
from . import views

# Lista tras URL dla aplikacji search
urlpatterns = [
    # Endpoint główny wyszukiwania (POST)
    path("", views.search_view, name="search"),
    # Alternatywny endpoint wyszukiwania (POST)
    path("search/", views.search_view, name="search_search"),
    # Endpoint sprawdzania statusu wyszukiwania (GET)
    path("search/<int:search_id>/", views.search_status_view, name="search_status"),
    # Endpoint pobierania plików PDF (GET)
    path("files/<str:filename>", views.file_view, name="file_view"),
]
