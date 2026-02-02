# Bilsene! 🦊

**Bilsene!** is a modern, open-source, and high-performance iOS adaptation of the classic "Heads Up!" party game. Developed by **Two Tails Studios**.

Built from scratch using SwiftUI and CoreMotion technologies, following the **MVVM** architecture patterns.

![Platform](https://img.shields.io/badge/Platform-iOS-blue)
![Language](https://img.shields.io/badge/Language-Swift_5-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## 🚀 Features

* **Motion Control (CoreMotion):** Processes accelerometer and gyroscope data to detect device tilt (Pass/Correct mechanics).
* **Smart Bag Algorithm:** A custom randomization algorithm that prevents the same words from appearing repeatedly until the pool is exhausted.
* **Remote Configuration:** Word pools are fetched dynamically via GitHub Gist in JSON format, allowing content updates without requiring an app update.
* **MVVM Architecture:** Clean code structure separating logic (ViewModel) from UI (View), improving readability and maintainability.
* **Custom Categories:** Users can create their own word packs and save them persistently using `UserDefaults`.
* **Team Mode:** A competitive round-based system with score tracking for two teams.
* **Game History:** Detailed summary at the end of the game showing which words were guessed correctly or passed.

## 🛠 Tech Stack & Frameworks

* **SwiftUI:** Declarative UI design for a modern interface.
* **Combine:** Handling asynchronous events and state changes.
* **CoreMotion:** Processing raw sensor data for gesture recognition.
* **AudioToolbox:** Managing sound effects and Haptic Feedback.
* **URLSession & Codable:** Efficient networking and JSON parsing.

## 📂 Project Structure

The project is organized into a modular structure to ensure scalability:

```text
Bilsene
├── Models
│   └── GameModels.swift    # Data structures (Category, GameResult)
├── ViewModels
│   └── GameEngine.swift    # Core game logic and State Management (ObservableObject)
├── Views
│   ├── ContentView.swift   # Main game interface and navigation
│   └── HelperViews.swift   # Reusable UI components (Buttons, Backgrounds)
└── Resources
    └── Assets.xcassets     # Visual assets, Pixel Art icons, and logos


📸 Screenshots
(Screenshots coming soon)

👨‍💻 Developer
Ilke Saykı - Lead Developer
Two Tails Studios

This project was developed for educational and portfolio purposes.
