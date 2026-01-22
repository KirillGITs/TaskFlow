"""
Moduł widoków dla aplikacji wyszukiwania.
Zawiera endpointy API do wyszukiwania artykułów i pobierania plików PDF.
"""

import os
import json
import urllib.parse
from django.http import JsonResponse, HttpResponseNotFound, FileResponse
from django.views.decorators.csrf import csrf_exempt
from django.conf import settings
from .models import SearchQuery, FoundArticle
from .tasks import perform_search


@csrf_exempt
def search_view(request):
    """
    Endpoint do inicjalizacji wyszukiwania artykułów.
    Przyjmuje żądanie POST z parametrami 'query' i 'site'.
    Zwraca ID wyszukiwania i status 'pending'.
    """
    # Sprawdzenie czy żądanie jest typu POST
    if request.method != "POST":
        return JsonResponse({"error": "POST required"}, status=405)

    # Parsowanie danych JSON z żądania
    try:
        data = json.loads(request.body.decode())
    except Exception:
        return JsonResponse({"error": "invalid json"}, status=400)

    # Pobranie parametrów zapytania
    query = data.get("query")
    site = data.get("site")
    
    # Walidacja wymaganych parametrów
    if not query or not site:
        return JsonResponse({"error": "query and site required"}, status=400)

    # Utworzenie rekordu wyszukiwania w bazie danych
    search = SearchQuery.objects.create(query=query, site=site, status="pending")

    # Uruchomienie asynchronicznego zadania Celery
    perform_search.delay(search.id)

    return JsonResponse({"search_id": search.id, "status": "pending"})


def search_status_view(request, search_id):
    """
    Endpoint do sprawdzania statusu wyszukiwania.
    Zwraca status wyszukiwania i listę znalezionych artykułów.
    """
    # Pobranie obiektu wyszukiwania z bazy danych
    try:
        search = SearchQuery.objects.get(id=search_id)
    except SearchQuery.DoesNotExist:
        return JsonResponse({"error": "search not found"}, status=404)

    # Pobranie wszystkich znalezionych artykułów
    results = FoundArticle.objects.filter(search=search)
    items = []
    
    # Przygotowanie listy wyników
    for fa in results:
        file_url = None
        # Generowanie URL do pobrania pliku PDF
        if fa.downloaded and fa.pdf_filename:
            file_url = f"/api/files/{urllib.parse.quote(fa.pdf_filename)}"
        items.append({
            "id": fa.id,
            "title": fa.title,
            "url": fa.url,
            "downloaded": fa.downloaded,
            "file_url": file_url,
        })

    return JsonResponse({
        "search_id": search.id,
        "status": search.status,
        "results": items,
    })


def file_view(request, filename):
    """Udostępnianie plików PDF z katalogu media/articles."""
    # Odkodowanie nazwy pliku z URL
    filename = urllib.parse.unquote(filename)
    filename = os.path.basename(filename)
    
    # Walidacja nazwy pliku (zabezpieczenie przed path traversal)
    if not filename or ".." in filename or "/" in filename or "\\" in filename:
        return HttpResponseNotFound()
    
    # Ścieżka do katalogu z artykułami
    articles_dir = os.path.join(settings.MEDIA_ROOT, "articles")
    filepath = os.path.join(articles_dir, filename)
    
    # Normalizacja ścieżki i sprawdzenie bezpieczeństwa
    filepath = os.path.normpath(filepath)
    articles_dir = os.path.normpath(articles_dir)
    if not filepath.startswith(articles_dir):
        return HttpResponseNotFound()
    
    # Sprawdzenie czy plik istnieje
    if not os.path.exists(filepath):
        return HttpResponseNotFound()
    
    # Zwrócenie pliku jako odpowiedź HTTP
    try:
        file_handle = open(filepath, "rb")
        response = FileResponse(file_handle, as_attachment=True, filename=filename)
        response['Content-Type'] = 'application/pdf'
        return response
    except Exception:
        return HttpResponseNotFound()
