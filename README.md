# ServiceSphere 🛠️📍

![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue?logo=flutter)
![Firebase](https://img.shields.io/badge/Backend-Firebase-orange?logo=firebase)
![Status](https://img.shields.io/badge/Status-Closed%20Testing%20(Alpha)-green)
![License](https://img.shields.io/badge/License-MIT-purple)

**ServiceSphere** is a hyperlocal home services marketplace that bridges the gap between customers and local service professionals (Electricians, Plumbers, Cleaners) in real-time. Built with **Flutter** and **Firebase**, it features a decentralized "Uber-style" job dispatch system, ensuring instant connections and secure transactions.

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

## 🧠 Technical Challenges Conquered

Building a multi-sided marketplace requires precise data synchronization and scalable state management. 
* **Real-Time Job Dispatch:** Engineered a "Broadcast-and-Claim" system utilizing Firebase Cloud Functions and Firestore real-time listeners. When a user requests a service, the backend instantly calculates proximity and broadcasts the job to all online, qualified agents within the radius. The first to claim it locks the transaction, utilizing Firestore transactions to prevent double-booking.
* **State Management Strategy:** Implemented **Provider** paired with an **MVVM (Model-View-ViewModel)** architecture. This decoupled the UI from the heavy backend business logic, ensuring smooth 60fps scrolling even when live-tracking agents on the map.
* **Secure Ecosystem:** Handled complex role-based access control (RBAC) across three distinct interfaces (User, Agent, Admin) using custom Firebase Auth claims.

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

## 📂 Explore My Other Work

I specialize in end-to-end Flutter development. Check out my other featured project:
* **[PharmaFinder]([link-to-repo]):** A medical store discovery and delivery platform featuring distinct User, Admin, and Rider interfaces.

---

## 👨‍💻 About the Developer

Hi, I'm Dhairya Dudakiya. I hold a B.Tech in Computer Engineering and currently work as a **Freelance Flutter Developer**. I specialize in building complex, cross-platform mobile ecosystems from architecture planning to final app store deployment. 

📫 **Open for Freelance Projects:** If you need a custom mobile solution, an MVP, or backend integration, let's connect! 
* **LinkedIn:** [Your Profile Link]
* **Email:** [Your Email Address]

---

> “Code is like humor. When you have to explain it, it’s bad.” – Cory House

Thanks for visiting! 🚀
