# Tutorix Project Structure

This project follows a structured architecture for both backend and frontend.

## Backend (Node.js/Express/TypeScript)
Located in `/backend`.

- `src/index.ts`: Entry point of the application.
- `src/lib/`: Contains modular libraries/features.
  - `auth/`: Authentication module.
    - `auth.route.ts`: API routes for authentication.
    - `auth.controller.ts`: Request handlers.
    - `auth.service.ts`: Business logic and external service integrations.
- `src/shared/`: Shared utilities, middlewares, and constants.

## Frontend (Flutter/Dart)
Located in `/frontend`.

- `lib/main.dart`: Entry point of the Flutter app.
- `lib/auth/`: Authentication related components.
  - `model/`: Data models (e.g., User).
  - `screens/`: UI screens (Login, Signup).
  - `services/`: Business logic for auth (API calls).
  - `widgets/`: Reusable UI components.
- `lib/config/`: Configuration files.
  - `api/`: API endpoint configurations.
  - `themes/`: Application themes and styles.

## Guidelines
1. **Separation of Concerns**: Keep business logic in services and UI in screens/widgets.
2. **Modular Architecture**: New features should be added as modules under `src/lib/` (backend) and `lib/` (frontend).
3. **Consistent Naming**: Use `.service.ts`, `.controller.ts`, `.route.ts` suffixes for backend and similar descriptive names for frontend.
