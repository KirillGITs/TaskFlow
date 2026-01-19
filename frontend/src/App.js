/**
 * Główny komponent aplikacji do wyszukiwania artykułów.
 * Umożliwia wyszukiwanie artykułów na polskich portalach informacyjnych
 * i pobieranie ich jako pliki PDF.
 */

import { useState } from "react";

function App() {
  // Stan dla słowa kluczowego wyszukiwania
  const [query, setQuery] = useState("");
  // Stan dla wybranej strony internetowej
  const [site, setSite] = useState("onet.pl");
  // Stan dla wyników wyszukiwania
  const [results, setResults] = useState(null);
  // Stan ładowania
  const [loading, setLoading] = useState(false);
  // Stan błędów
  const [error, setError] = useState(null);
  // ID aktualnego wyszukiwania
  const [searchId, setSearchId] = useState(null);

  /**
   * Funkcja odpytująca status wyszukiwania.
   * Sprawdza czy wyszukiwanie jest zakończone i aktualizuje wyniki.
   * @param {number} id - ID wyszukiwania
   */
  const pollSearchStatus = async (id) => {
    try {
      // Wysłanie żądania GET do sprawdzenia statusu
      const res = await fetch(`/api/search/${id}/`);
      const data = await res.json();

      // Obsługa błędów odpowiedzi
      if (!res.ok) {
        throw new Error(data.error || "Failed to get status");
      }

      // Sprawdzenie statusu wyszukiwania
      if (data.status === "done") {
        // Wyszukiwanie zakończone - aktualizacja wyników
        setResults(data.results || []);
        setLoading(false);
      } else if (data.status === "error") {
        // Błąd wyszukiwania
        setError("Search failed");
        setLoading(false);
      } else {
        // Wyszukiwanie w toku - ponowne odpytanie za 2 sekundy
        setTimeout(() => pollSearchStatus(id), 2000);
      }
    } catch (err) {
      // Obsługa błędów sieciowych
      setError(err.message || "Error polling search status");
      setLoading(false);
    }
  };

  /**
   * Funkcja inicjująca wyszukiwanie.
   * Wysyła żądanie POST z parametrami wyszukiwania.
   * @param {Event} e - Event formularza
   */
  const doSearch = async (e) => {
    e.preventDefault();

    // Reset stanów
    setLoading(true);
    setError(null);
    setResults(null);
    setSearchId(null);

    try {
      // Wysłanie żądania wyszukiwania
      const res = await fetch("/api/search/", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ query, site }),
      });

      const data = await res.json();

      // Obsługa błędów odpowiedzi
      if (!res.ok) {
        throw new Error(data.error || "Search failed");
      }

      // Zapisanie ID wyszukiwania i rozpoczęcie odpytywania
      setSearchId(data.search_id);
      pollSearchStatus(data.search_id);
    } catch (err) {
      // Obsługa błędów sieciowych
      setError(err.message || "Error occurred during search");
      setLoading(false);
    }
  };

  return (
    <div style={{ maxWidth: 1000, margin: "0 auto", padding: "20px", fontFamily: "'Segoe UI', Tahoma, Geneva, Verdana, sans-serif", backgroundColor: "#f8f9fa", minHeight: "100vh" }}>
      {/* Sekcja formularza wyszukiwania */}
      <div style={{ backgroundColor: "white", borderRadius: "12px", padding: "30px", boxShadow: "0 4px 6px rgba(0,0,0,0.1)", marginBottom: "20px" }}>

        {/* Formularz wyszukiwania */}
        <form onSubmit={doSearch} style={{ marginBottom: 20 }}>
          {/* Pole wprowadzania słowa kluczowego */}
          <div style={{ marginBottom: 10 }}>
            <label style={{ display: "block", marginBottom: 5, fontWeight: "bold" }}>
              Słowo kluczowe:
            </label>
            <input
              placeholder='np. "ukraina", "chopin", "ekonomia"'
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              style={{ width: "100%", padding: 10, fontSize: 16, border: "1px solid #ccc", borderRadius: 4 }}
            />
          </div>

          {/* Przycisk wyszukiwania */}
          <button
            type="submit"
            disabled={loading || !query}
            style={{
              padding: "14px 40px",
              fontSize: 18,
              fontWeight: "600",
              backgroundColor: loading ? "#6c757d" : "#007bff",
              color: "white",
              border: "none",
              borderRadius: 8,
              cursor: loading ? "not-allowed" : "pointer",
              transition: "all 0.3s",
              boxShadow: loading ? "none" : "0 4px 8px rgba(0,123,255,0.3)"
            }}
          >
            {loading ? "⏳ Szukam..." : "🔍 Szukaj"}
          </button>
        </form>

        {/* Komunikat o trwającym wyszukiwaniu */}
        {loading && searchId && (
          <div style={{ padding: 15, backgroundColor: "#fff3cd", borderRadius: 4, marginBottom: 15 }}>
            ⏳ Wyszukiwanie w toku... (ID: {searchId})
            <br />
            <small>Proszę czekać, Selenium przeszukuje stronę i generuje PDF...</small>
          </div>
        )}

        {/* Komunikat o błędzie */}
        {error && (
          <div style={{ padding: 15, backgroundColor: "#f8d7da", color: "#721c24", borderRadius: 4, marginBottom: 15 }}>
            ❌ Błąd: {error}
          </div>
        )}

      </div>

      {/* Sekcja wyników wyszukiwania */}
      {results && (
        <div style={{ backgroundColor: "white", borderRadius: "12px", padding: "30px", boxShadow: "0 4px 6px rgba(0,0,0,0.1)" }}>
          <div>
            {/* Nagłówek z liczbą wyników */}
            <h2 style={{ color: "#2c3e50", marginBottom: "20px", textAlign: "center", fontSize: "2em", fontWeight: "300" }}>📄 Wyniki wyszukiwania ({results.length})</h2>

            {/* Komunikat o braku wyników */}
            {results.length === 0 && (
              <div style={{
                padding: "40px",
                backgroundColor: "#f8f9fa",
                borderRadius: "8px",
                textAlign: "center",
                color: "#6c757d",
                fontSize: "1.1em"
              }}>
                😔 Nie znaleziono artykułów dla podanego zapytania.
                <br />
                Spróbuj zmienić słowa kluczowe lub wybrać inną stronę.
              </div>
            )}

            {/* Lista znalezionych artykułów */}
            <ul style={{ listStyle: "none", padding: 0 }}>
              {results.map((r) => (
                <li key={r.id} style={{
                  marginBottom: 15,
                  padding: 15,
                  backgroundColor: "#f8f9fa",
                  borderRadius: 4,
                  border: "1px solid #dee2e6"
                }}>
                  {/* Tytuł artykułu z linkiem */}
                  <div style={{ marginBottom: 8 }}>
                    <a
                      href={r.url}
                      target="_blank"
                      rel="noreferrer"
                      style={{ color: "#007bff", textDecoration: "none", fontWeight: "bold" }}
                    >
                      {r.title}
                    </a>
                  </div>
                  {/* Przycisk pobierania PDF lub komunikat o niedostępności */}
                  <div>
                    {r.downloaded ? (
                      <a
                        href={r.file_url}
                        style={{
                          display: "inline-block",
                          padding: "5px 15px",
                          backgroundColor: "#28a745",
                          color: "white",
                          textDecoration: "none",
                          borderRadius: 4,
                          fontSize: 14
                        }}
                      >
                        📥 Pobierz PDF
                      </a>
                    ) : (
                      <span style={{ color: "#6c757d" }}>⚠️ PDF niedostępny</span>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
