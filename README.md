# WaziBot Mobile — Flutter App

## Phase 1 Complete ✅

Mobile companion app for WaziBot AI Business OS.

---

## Architecture

```
lib/
├── main.dart                          # App entry point, Riverpod root
├── core/
│   ├── api/
│   │   └── api_client.dart            # Dio HTTP client + auth interceptor + token refresh
│   ├── auth/
│   │   ├── auth_models.dart           # AuthTokens, AuthUser
│   │   └── auth_service.dart          # JWT storage, AuthNotifier, AuthState
│   ├── constants/
│   │   └── app_constants.dart         # Base URL, storage keys, config
│   ├── router/
│   │   └── app_router.dart            # GoRouter config, redirect logic, More screen
│   └── theme/
│       └── app_theme.dart             # M3 dark + light themes, WaziBot brand palette
│
├── features/
│   ├── auth/presentation/screens/
│   │   ├── splash_screen.dart         # Animated logo, auth redirect
│   │   └── login_screen.dart          # Login form, JWT flow
│   ├── home/presentation/screens/
│   │   └── home_screen.dart           # Business header, stats grid, health score, quick actions
│   ├── inbox/presentation/screens/
│   │   ├── inbox_screen.dart          # Conversation list, search, unread badges
│   │   └── conversation_screen.dart   # Chat bubbles, message bar, send
│   ├── orders/presentation/screens/
│   │   ├── orders_screen.dart         # Tabbed by status, search
│   │   └── order_detail_screen.dart   # Items, total, Accept/Reject/Complete actions
│   ├── analytics/presentation/screens/
│   │   └── analytics_screen.dart      # KPI grid, health bar, weekly bar chart
│   ├── products/presentation/screens/
│   │   ├── products_screen.dart       # Product list, search, delete
│   │   └── add_product_screen.dart    # Add with image upload
│   ├── qr/presentation/screens/
│   │   └── qr_screen.dart             # QR generation, share, download
│   └── settings/presentation/screens/
│       └── settings_screen.dart       # Theme toggle, notifications, web redirect modals
│
└── shared/
    ├── models/
    │   └── business_models.dart       # BusinessProfile, DashboardStats, Order, Product, Conversation, Message
    └── widgets/
        ├── main_shell.dart            # Bottom NavigationBar shell (5 tabs)
        ├── stat_card.dart             # Reusable KPI card
        └── loading_shimmer.dart       # Shimmer skeleton loader
```

---

## Backend API endpoints consumed (Phase 1)

| Screen | Endpoint |
|--------|----------|
| Login | `POST /auth/login` |
| Token refresh | `POST /auth/refresh` |
| Home / Profile | `GET /me` |
| Home / Stats | `GET /analytics/stats` |
| Inbox | `GET /chat/conversations` |
| Conversation | `GET /chat/conversations/{phone}` → `GET /chat/messages/{id}` |
| Send message | `POST /chat/send` |
| Close conversation | `POST /chat/conversations/{id}/close` |
| Orders | `GET /orders` |
| Update order | `PUT /orders/{id}/status` |
| Products | `GET /products` |
| Add product | `POST /products` |
| Upload image | `POST /products/upload-image` |
| Delete product | `DELETE /products/{id}` |
| Store URL / QR | `GET /me` (store_url field) |

---

## Setup instructions

### 1. Prerequisites
- Flutter SDK ≥ 3.3.0 (`flutter --version`)
- Android Studio or Xcode for emulator
- Node: not required

### 2. Install dependencies
```bash
cd wazibot_mobile
flutter pub get
```

### 3. Create asset directories
```bash
mkdir -p assets/images assets/icons assets/animations assets/fonts
```

Download Inter font from https://fonts.google.com/specimen/Inter and place in `assets/fonts/`:
- `Inter-Regular.ttf`
- `Inter-Medium.ttf`
- `Inter-SemiBold.ttf`
- `Inter-Bold.ttf`

### 4. Run the app
```bash
flutter run
```

### 5. Build for Android
```bash
flutter build apk --release
```

### 6. Build for iOS
```bash
flutter build ios --release
```

---

## No backend changes required ✅

This app is purely a consumer of the existing WaziBot REST API.
The backend at `https://wazibot-api-assistant.onrender.com` is used as-is.

---

## Phase 2 (next)

- Firebase Cloud Messaging (push notifications)
- Offline caching (shared_preferences + local DB)
- Mobile scanner (QR scanning)
- Product image full edit flow
- Customer profile screen
- Analytics export
- Onboarding flow for new users
