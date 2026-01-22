"""
Moduł zadań asynchronicznych Celery dla aplikacji wyszukiwania.
Zawiera zadania do wykonywania wyszukiwań w tle.
"""

from celery import shared_task
from .selenium_client import search_and_find_pdfs
from .models import SearchQuery, FoundArticle


@shared_task
def perform_search(search_id):
    """
    Asynchroniczne zadanie do wyszukiwania artykułów.
    Wykonuje wyszukiwanie za pomocą Selenium i zapisuje wyniki w bazie danych.
    
    Args:
        search_id: ID zapytania wyszukiwania w bazie danych
    """
    try:
        # Pobranie obiektu wyszukiwania i aktualizacja statusu
        search = SearchQuery.objects.get(id=search_id)
        search.status = "running"
        search.save()

        # Wykonanie wyszukiwania za pomocą klienta Selenium
        results = search_and_find_pdfs(search.query, search.site)
        
        # Zapisanie znalezionych artykułów w bazie danych
        for r in results:
            FoundArticle.objects.create(
                search=search,
                title=r.get("title") or "(no title)",
                url=r.get("url"),
                pdf_filename=r.get("pdf_filename"),
                downloaded=r.get("downloaded", False),
            )
        
        # Aktualizacja statusu na zakończone
        search.status = "done"
        search.save()
    except Exception as exc:
        # W przypadku błędu - aktualizacja statusu i ponowne zgłoszenie wyjątku
        search.status = "error"
        search.save()
        raise exc