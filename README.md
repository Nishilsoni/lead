# OceanCRM Lead Management - Flutter Application

A production-ready Flutter mobile application for managing CRM leads, built as a test task for Ocean Technolab. The app features full CRUD operations (Create, Read, Update, Delete) with a modern, polished UI and integrates with the OceanCRM Python REST API.

## Features

- **Authentication** — Email/password login with secure token persistence
- **Lead Listing** — Paginated list with infinite scroll, pull-to-refresh
- **Search** — Real-time debounced search across leads
- **Stage Filtering** — Dynamic filter chips fetched from API
- **Lead Details** — Full lead information with gradient hero header
- **Create Lead** — Multi-section form with dynamic dropdowns (stage, source, products, assignee)
- **Edit Lead** — Pre-populated edit form
- **Delete Lead** — Confirmation dialog with swipe-to-delete gesture
- **Swipe Actions** — Slide left to delete, slide right to edit
- **Shimmer Loading** — Skeleton loaders for smooth UX during data fetches
- **Copy to Clipboard** — Tap phone/email in detail view to copy

## Architecture

```
lib/
├── main.dart                          # Entry point with MultiProvider
├── core/
│   ├── constants/
│   │   ├── api_constants.dart         # API endpoints & org config
│   │   └── app_theme.dart             # Material 3 theme with Inter font
│   ├── network/
│   │   └── api_client.dart            # Dio singleton + auth interceptor
│   └── utils/
│       ├── date_formatter.dart        # Date display utilities
│       └── snackbar_helper.dart       # Styled snackbar messages
├── models/
│   ├── auth.dart                      # AuthCredentials, LoginResponse
│   ├── lead.dart                      # Lead, Business, Product, Source, etc.
│   └── paginated_response.dart        # Generic paginated response wrapper
├── services/
│   ├── auth_service.dart              # Login, logout, token refresh
│   └── lead_service.dart              # Lead CRUD + supporting resources
├── providers/
│   ├── auth_provider.dart             # Auth state management
│   └── lead_provider.dart             # Lead list, search, filter, CRUD state
└── screens/
    ├── login/
    │   └── login_screen.dart          # Branded login with animation
    ├── leads/
    │   ├── lead_list_screen.dart       # Main listing with search + filters
    │   ├── lead_detail_screen.dart     # Full lead detail view
    │   └── lead_form_screen.dart       # Shared create/edit form
    └── widgets/
        ├── lead_card.dart             # Rich card with swipe actions
        ├── stage_badge.dart           # Color-coded stage pill
        ├── shimmer_loading.dart       # Skeleton loader
        └── empty_state.dart           # Empty/error state widget
```

## Tech Stack

| Library | Purpose |
|---|---|
| `provider` | State management via ChangeNotifier |
| `dio` | HTTP client with interceptors |
| `flutter_secure_storage` | Secure token persistence |
| `flutter_slidable` | Swipe-to-edit/delete gestures |
| `shimmer` | Skeleton loading animations |
| `google_fonts` | Inter font family |
| `intl` | Date formatting |

## Getting Started

### Prerequisites
- Flutter SDK ^3.10.7
- Android Studio / Xcode
- Active internet connection (connects to test API)

### Setup
```bash
# Install dependencies
flutter pub get

# Run on connected device / emulator
flutter run

# Build APK
flutter build apk --debug
```

### Demo Credentials
```
Email:    demo@oceantechnolab.com
Password: 7859993590
```

## API Integration

- **Base URL**: `https://api-test.crm.oceantechnolab.com/api`
- **Auth**: Bearer token via `/v1/auth/login`
- **Org Header**: `x-org-id` injected on all lead requests
- **Endpoints**: Leads CRUD, Stages, Products, Sources, Users

## Design Decisions

1. **Provider over BLoC** — Simpler setup appropriate for the scope; clean separation of concerns
2. **Dio interceptors** — Automatic token injection and org-id header without per-request boilerplate
3. **Dynamic dropdowns** — Stages, sources, products fetched from API (not hardcoded)
4. **Debounced search** — 400ms debounce prevents excessive API calls
5. **Swipe gestures** — Discoverable CRUD actions via flutter_slidable
6. **Color-coded stages** — Visual distinction for lead pipeline at a glance

## Code Quality

- `flutter analyze` passes with **zero issues**
- Clean architecture separation (models → services → providers → screens)
- Strongly-typed models with JSON serialization
- Comprehensive error handling with user-friendly messages
