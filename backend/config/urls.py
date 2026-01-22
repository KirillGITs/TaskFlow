"""
Główna konfiguracja tras URL dla projektu Django.
Definiuje główne endpointy dla panelu admina i API.
"""

from django.contrib import admin
from django.urls import path, include

# Lista głównych tras URL projektu
urlpatterns = [
    # Panel administracyjny Django
    path("admin/", admin.site.urls),
    # Trasy API aplikacji search
    path("api/", include("search.urls")),
]
