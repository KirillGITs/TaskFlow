/**
 * Punkt wejściowy aplikacji React.
 * Inicjalizuje aplikację i renderuje główny komponent App.
 */

import React from "react";
import { createRoot } from "react-dom/client";
import App from "./App";

// Pobranie głównego kontenera DOM
const container = document.getElementById("root");

// Utworzenie korzenia React (React 18+)
const root = createRoot(container);

// Renderowanie głównego komponentu aplikacji
root.render(<App />);
