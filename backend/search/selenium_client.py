"""
Moduł klienta Selenium do wyszukiwania artykułów i generowania plików PDF.
Ten moduł zawiera funkcje do automatycznego przeglądania stron internetowych,
wyszukiwania artykułów i zapisywania ich jako pliki PDF.
"""

# Importy standardowych bibliotek Pythona
import os
import re
import time
import base64
import urllib.parse
import logging

# Importy Selenium do automatyzacji przeglądarki
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, WebDriverException

# Importy do obsługi żądań HTTP i konfiguracji Django
import requests
from django.conf import settings

# Konfiguracja loggera dla tego modułu
logger = logging.getLogger(__name__)

# URL serwera Selenium (zdalny WebDriver)
SELENIUM_URL = os.environ.get("SELENIUM_URL", "http://selenium:4444/wd/hub")

# Ustawienie katalogu głównego dla mediów
try:
    MEDIA_ROOT = getattr(settings, 'MEDIA_ROOT', str(settings.BASE_DIR / "media"))
except Exception:
    MEDIA_ROOT = os.environ.get("MEDIA_ROOT", "/app/media")

# Katalog do przechowywania pobranych artykułów
ARTICLES_DIR = os.path.join(MEDIA_ROOT, "articles")
os.makedirs(ARTICLES_DIR, exist_ok=True)


def sanitize_filename(name):
    safe = "".join(c for c in name if c.isalnum() or c in " .-_()")
    safe = safe.replace(" ", "_")
    return safe[:200]


def download_pdf(url, filename=None, timeout=30):
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        resp = requests.get(url, stream=True, timeout=timeout, headers=headers)
        resp.raise_for_status()
        
        if not filename:
            parsed = urllib.parse.urlparse(url)
            filename = os.path.basename(parsed.path) or f"article_{int(time.time())}.pdf"
        
        filename = sanitize_filename(filename)
        if not filename.endswith('.pdf'):
            filename += '.pdf'
            
        dest = os.path.join(ARTICLES_DIR, filename)
        with open(dest, "wb") as f:
            for chunk in resp.iter_content(8192):
                if chunk:
                    f.write(chunk)
        return filename
    except Exception as exc:
        logger.exception("Failed to download PDF from %s", url)
        return None


def save_page_as_pdf(driver, title, url=None):
    """Generowanie PDF z bieżącej strony za pomocą print_page() lub zapisanie HTML."""
    try:
        title_safe = sanitize_filename(title or "article")
        filename = f"{title_safe}_{int(time.time())}.pdf"
        dest = os.path.join(ARTICLES_DIR, filename)
        
        try:
            pdf_data = driver.execute_cdp_cmd('Page.printToPDF', {
                'format': 'A4',
                'printBackground': True,
                'marginTop': 0.4,
                'marginBottom': 0.4,
                'marginLeft': 0.4,
                'marginRight': 0.4,
            })
            pdf_content = base64.b64decode(pdf_data['data'])
            with open(dest, "wb") as f:
                f.write(pdf_content)
            logger.info("Generated PDF using CDP: %s", filename)
            return filename
        except Exception as e:
            logger.warning("CDP printToPDF failed: %s, trying print_page", str(e))
        
        try:
            pdf_base64 = driver.print_page()
            pdf_content = base64.b64decode(pdf_base64)
            with open(dest, "wb") as f:
                f.write(pdf_content)
            logger.info("Generated PDF using print_page: %s", filename)
            return filename
        except Exception as e:
            logger.warning("print_page failed: %s, saving as HTML", str(e))
        
        try:
            from weasyprint import HTML
            html_doc = HTML(string=page_source)
            html_doc.write_pdf(dest)
            logger.info("Generated PDF using weasyprint: %s", filename)
            return filename
        except ImportError:
            logger.warning("weasyprint not available")
        except Exception as e:
            logger.warning("weasyprint failed: %s", str(e))
        
        html_filename = f"{title_safe}_{int(time.time())}.html"
        html_dest = os.path.join(ARTICLES_DIR, html_filename)
        
        page_source = driver.page_source
        with open(html_dest, "w", encoding="utf-8") as f:
            f.write(page_source)
        
        logger.info("Saved HTML: %s (PDF generation failed)", html_filename)
        
        return html_filename
        
    except Exception as exc:
        logger.exception("Failed to save page: %s", str(exc))
        return None


def handle_cookie_consent(driver):
    """Próba zaakceptowania wyskakujących okienek zgody na pliki cookie."""
    consent_xpaths = [
        "//button[contains(text(), 'Akceptuję')]",
        "//button[contains(text(), 'AKCEPTUJĘ')]",
        "//button[contains(text(), 'Zgadzam się')]",
        "//button[contains(text(), 'Przejdź do serwisu')]",
        "//button[contains(text(), 'przechodzę')]",
        "//button[contains(text(), 'OK')]",
        "//a[contains(text(), 'Akceptuję')]",
        "//a[contains(text(), 'Przejdź')]",
        "//button[contains(@class, 'accept')]",
        "//button[contains(@class, 'consent')]",
        "//button[contains(@id, 'accept')]",
    ]
    
    for xpath in consent_xpaths:
        try:
            elements = driver.find_elements(By.XPATH, xpath)
            for elem in elements:
                if elem.is_displayed():
                    elem.click()
                    logger.info("Clicked consent button: %s", xpath)
                    time.sleep(1)
                    return True
        except Exception:
            continue
    
    try:
        buttons = driver.find_elements(By.TAG_NAME, "button")
        for btn in buttons:
            try:
                text = btn.text.lower()
                if any(word in text for word in ['akceptuj', 'zgadzam', 'accept', 'agree', 'przejdź']):
                    if btn.is_displayed():
                        btn.click()
                        logger.info("Clicked button: %s", btn.text)
                        time.sleep(1)
                        return True
            except Exception:
                continue
    except Exception:
        pass
    
    return False


def is_valid_article_url(url, site):
    """Sprawdzenie, czy URL jest prawidłowym artykułem z docelowej strony."""
    if not url:
        return False
    
    site_lower = site.lower().replace('www.', '')
    
    url_lower = url.lower()
    
    if site_lower not in url_lower:
        return False
    
    exclude_patterns = [
        '/szukaj', '/search', '/wyszukiwanie',
        '/tag/', '/kategoria/', '/category/',
        '/autor/', '/author/',
        '/login', '/register', '/rejestracja',
        '/kontakt', '/contact',
        '/regulamin', '/polityka',
        '/reklama', '/newsletter', '/rss',
        'javascript:', '#',
        '/cdn-cgi/',
        'google.com',
        'doubleclick',
    ]
    
    for pattern in exclude_patterns:
        if pattern in url_lower:
            return False
    
    return True


def get_site_search_url(site, query):
    """Pobieranie URL wyszukiwania dla określonej strony."""
    site_lower = site.lower().replace('www.', '')
    
    search_urls = {
        'rzeczpospolita.pl': f'https://www.rzeczpospolita.pl/szukaj?q={urllib.parse.quote_plus(query)}',
        'rp.pl': f'https://www.rp.pl/szukaj?q={urllib.parse.quote_plus(query)}',
        'wp.pl': f'https://szukaj.wp.pl/?q={urllib.parse.quote_plus(query)}',
        'onet.pl': f'https://szukaj.onet.pl/?q={urllib.parse.quote_plus(query)}',
        'gazeta.pl': f'https://szukaj.gazeta.pl/szukaj/0,0.html?q={urllib.parse.quote_plus(query)}',
        'tvn24.pl': f'https://tvn24.pl/szukaj?query={urllib.parse.quote_plus(query)}',
        'polsatnews.pl': f'https://www.polsatnews.pl/szukaj/?query={urllib.parse.quote_plus(query)}',
        'interia.pl': f'https://www.interia.pl/szukaj?q={urllib.parse.quote_plus(query)}',
    }
    
    for known_site, url_template in search_urls.items():
        if known_site in site_lower:
            return url_template
    
    return f'https://www.{site}/szukaj?q={urllib.parse.quote_plus(query)}'


def search_and_find_pdfs(query, site, max_results=10):
    """
    Wyszukiwanie artykułów na określonej stronie za pomocą własnej wyszukiwarki.
    Otwiera znalezione artykuły i zapisuje je jako pliki PDF.
    """
    options = webdriver.ChromeOptions()
    options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1920,1080")
    options.add_argument("--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

    driver = None
    found = []
    
    try:
        driver = webdriver.Remote(command_executor=SELENIUM_URL, options=options)
        wait = WebDriverWait(driver, 20)

        search_url = get_site_search_url(site, query)
        
        logger.info("Searching on site: %s", search_url)
        
        try:
            driver.get(search_url)
            wait.until(EC.presence_of_element_located((By.TAG_NAME, "body")))
            time.sleep(3)
            
            handle_cookie_consent(driver)
            time.sleep(2)
            
            site_lower = site.lower()
            if 'onet.pl' in site_lower:
                search_inputs = driver.find_elements(By.CSS_SELECTOR, "input[type='text'], input[name='q'], input[class*='search']")
                for inp in search_inputs:
                    try:
                        if inp.is_displayed():
                            inp.clear()
                            inp.send_keys(query)
                            inp.send_keys(Keys.RETURN)
                            logger.info("Entered query in search box")
                            time.sleep(4)
                            break
                    except Exception:
                        continue
            
        except TimeoutException:
            logger.warning("Timeout loading search page")
            return found

        links = []
        
        result_selectors = [
            ".gsc-result a.gs-title",
            ".gsc-webResult a",
            ".gs-title a",
            ".gsc-thumbnail-inside a",
            "article a",
            "article h2 a",
            "article h3 a",
            ".search-results a",
            ".search-result a",
            "[class*='search'] article a",
            "[class*='result'] a",
            ".teaser a",
            ".teaser__title a",
            "[class*='teaser'] a",
            "[class*='article'] h2 a",
            "[class*='article'] h3 a",
            "main article a",
            "main h2 a",
            "main h3 a",
            ".content h2 a",
            ".content h3 a",
        ]
        
        for selector in result_selectors:
            try:
                elements = driver.find_elements(By.CSS_SELECTOR, selector)
                for elem in elements:
                    try:
                        href = elem.get_attribute("href")
                        text = elem.text.strip()
                        
                        if href and is_valid_article_url(href, site):
                            if text and len(text) > 15:
                                links.append((text, href))
                                logger.debug("Found link: %s -> %s", text[:50], href)
                    except Exception:
                        continue
            except Exception:
                continue
        
        if not links:
            logger.info("No results with specific selectors, trying all links")
            all_anchors = driver.find_elements(By.TAG_NAME, "a")
            for a in all_anchors:
                try:
                    href = a.get_attribute("href")
                    text = a.text.strip()
                    
                    if href and is_valid_article_url(href, site):
                        nav_words = ['menu', 'serwisy', 'zaloguj', 'subskrybuj', 'newsletter', 
                                   'kontakt', 'regulamin', 'reklama', 'strona główna', 'więcej',
                                   'opinie', 'home', 'login']
                        if text and len(text) > 20:
                            if not any(nav in text.lower() for nav in nav_words):
                                links.append((text, href))
                except Exception:
                    continue
        
        seen = set()
        unique_links = []
        for text, href in links:
            if href not in seen:
                seen.add(href)
                unique_links.append((text, href))
        
        links = unique_links[:max_results]
        logger.info("Found %d article links to process", len(links))

        for title, article_url in links:
            article = {
                "title": title or article_url,
                "url": article_url,
                "pdf_filename": None,
                "downloaded": False
            }
            
            try:
                logger.info("Processing article: %s", article_url)
                driver.get(article_url)
                wait.until(EC.presence_of_element_located((By.TAG_NAME, "body")))
                time.sleep(2)
                
                handle_cookie_consent(driver)
                time.sleep(1)
                
                pdf_link = None
                page_anchors = driver.find_elements(By.TAG_NAME, "a")
                for pa in page_anchors:
                    try:
                        href = pa.get_attribute("href")
                        if href and ".pdf" in href.lower():
                            pdf_link = urllib.parse.urljoin(driver.current_url, href)
                            break
                    except Exception:
                        continue
                
                if pdf_link:
                    filename = download_pdf(pdf_link, title)
                    if filename:
                        article["pdf_filename"] = filename
                        article["downloaded"] = True
                        logger.info("Downloaded PDF: %s", filename)
                else:
                    filename = save_page_as_pdf(driver, title, article_url)
                    if filename:
                        article["pdf_filename"] = filename
                        article["downloaded"] = True
                
            except TimeoutException:
                logger.warning("Timeout loading article: %s", article_url)
            except Exception as exc:
                logger.exception("Error processing article %s: %s", article_url, str(exc))
            
            found.append(article)
        
    except WebDriverException as exc:
        logger.exception("Selenium WebDriver error: %s", str(exc))
        raise
    except Exception as exc:
        logger.exception("Unexpected error in search: %s", str(exc))
        raise
    finally:
        if driver:
            try:
                driver.quit()
            except Exception:
                logger.exception("Error closing WebDriver")

    return found
