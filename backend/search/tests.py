"""
Moduł testów jednostkowych dla aplikacji wyszukiwania.
Zawiera testy dla widoków i funkcjonalności wyszukiwania.
"""

import json
from django.test import TestCase, Client
from unittest.mock import patch
from .models import SearchQuery, FoundArticle


class SearchViewTests(TestCase):
    """
    Testy dla widoku wyszukiwania.
    Sprawdza poprawność tworzenia rekordów i zwracania wyników.
    """
    
    def test_search_view_creates_records_and_returns_results(self):
        """
        Test sprawdzający czy widok wyszukiwania poprawnie:
        - Tworzy rekordy w bazie danych
        - Zwraca wyniki wyszukiwania
        """
        # Utworzenie klienta testowego
        client = Client()
        
        # Przygotowanie danych testowych
        payload = {"query": "chopin", "site": "rzeczpospolita.pl"}
        fake_results = [
            {"title": "Article 1", "url": "https://rzeczpospolita.pl/article1", "pdf_filename": "a1.pdf", "downloaded": True},
            {"title": "Article 2", "url": "https://rzeczpospolita.pl/article2", "pdf_filename": None, "downloaded": False},
        ]
        
        # Mockowanie funkcji wyszukiwania
        with patch("search.views.search_and_find_pdfs", return_value=fake_results):
            # Wysłanie żądania POST
            resp = client.post("/api/search/", data=json.dumps(payload), content_type="application/json")
            
            # Sprawdzenie odpowiedzi
            self.assertEqual(resp.status_code, 200)
            data = resp.json()
            self.assertIn("results", data)
            self.assertEqual(len(data["results"]), 2)
            
            # Sprawdzenie czy rekordy zostały utworzone w bazie danych
            self.assertTrue(SearchQuery.objects.filter(query="chopin").exists())
            self.assertEqual(FoundArticle.objects.filter(search__query="chopin").count(), 2)
