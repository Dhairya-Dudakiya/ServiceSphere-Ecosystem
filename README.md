# ServiceSphere 🛠️📍

![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue?logo=flutter)
![Firebase](https://img.shields.io/badge/Backend-Firebase-orange?logo=firebase)
![Status](https://img.shields.io/badge/Status-Closed%20Testing%20(Alpha)-green)
![License](https://img.shields.io/badge/License-MIT-purple)

**ServiceSphere** is a hyperlocal home services marketplace that bridges the gap between customers and local service professionals (Electricians, Plumbers, Cleaners) in real-time. Built with **Flutter** and **Firebase**, it features a decentralised "Uber-style" job dispatch system, ensuring instant connections and secure transactions.

---

## 📱 Project Overview

* **App Name:** ServiceSphere
* **Domain:** Hyperlocal Marketplace / On-Demand Services
* **Target Region:** Rajkot, Gujarat (Pilot)
* **Current Status:** Closed Testing (Alpha) on Google Play Store

### 🚀 The Problem
The local home services market is unorganized. Finding a reliable electrician or plumber during an emergency is difficult, often relying on word-of-mouth. Service professionals struggle with inconsistent daily work.

### 💡 The Solution
ServiceSphere provides a dual-app ecosystem:
1.  **User App:** For customers to book services instantly.
2.  **Partner App:** For agents to receive job alerts and manage earnings.
3.  **Admin Panel:** For verification and platform management.

---

## ✨ Key Features

### 👤 User Application
* **Instant Booking:** "Book Now" feature to request immediate help.
* **Live Tracking:** Real-time agent tracking using **Google Maps API**.
* **Secure Payments:** Integrated Wallet System for seamless transactions.
* **Verified Reviews:** Rate and review agents after job completion.

### 👷 Partner Application (Agent)
* **Broadcast Job Feed:** Real-time "Broadcast-and-Claim" job alerts (similar to Uber).
* **Navigation:** One-click redirection to Google Maps for customer location.
* **Earnings Dashboard:** Track daily, weekly, and monthly income.
* **Availability Toggle:** Switch between Online/Offline modes.

### 🛡️ Admin Panel
* **KYC Verification:** Manual approval of Agent ID proofs (Aadhaar/PAN).
* **Service Management:** Dynamic control of service categories and pricing.

---

## 🛠️ Tech Stack

| Component | Technology |
| :--- | :--- |
| **Frontend** | Flutter (Dart) |
| **Backend** | Firebase (Firestore, Cloud Functions) |
| **Auth** | Firebase Auth (Google Sign-In, Phone Auth) |
| **Maps** | Google Maps SDK, Geocoding API |
| **State Mgmt** | Provider |
| **Architecture**| MVVM / Feature-First |

---

## 📸 Screenshots

| User Home | Live Tracking | Agent Job Alert | Earnings |
|:---:|:---:|:---:|:---:|
| <img src="assets/screenshots/user_home.png" width="200"> | <img src="assets/screenshots/tracking.png" width="200"> | <img src="assets/screenshots/job_alert.png" width="200"> | <img src="assets/screenshots/earnings.png" width="200"> |

*(Note: Add your actual screenshot images to an `assets/screenshots/` folder in your repo)*

---

## ⚙️ Installation & Setup

To run this project locally, follow these steps:

### Prerequisites
* Flutter SDK (v3.0+)
* Dart SDK
* Android Studio / VS Code
* Firebase Project Setup

### Steps
1.  **Clone the repository**
    ```bash
    git clone [https://github.com/Dhairya-Dudakiya/ServiceSphere.git](https://github.com/Dhairya-Dudakiya/ServiceSphere.git)
    cd ServiceSphere
    ```

2.  **Install Dependencies**
    ```bash
    flutter pub get
    ```

3.  **Firebase Configuration**
    * Download `google-services.json` from your Firebase Console.
    * Place it in `android/app/`.

4.  **API Keys**
    * Create a `secrets.dart` file (or add to `local.properties`) to store your Google Maps API Key.

5.  **Run the App**
    ```bash
    flutter run
    ```

---

## 👥 Team

* **Dhairya Dudakiya** - *Team Lead & Full Stack Developer*
* **Dhruv Manavadariya** - *Frontend & UI/UX*
* **Parth Gohel** - *Backend Support & Testing*

---

## 📞 Contact

If you have any questions or suggestions, feel free to reach out:

* **Email:** dhairyadudakiya52056@gmail.com
* **LinkedIn:** [Dhairya Dudakiya](https://www.linkedin.com/in/dhairya-dudakiya)

---

> This project was developed as a Final Year B.Tech Project at Marwadi University.
