# Firebase Authentication and Firestore Persistence Walkthrough

I have implemented Firebase Authentication for the login process and Cloud Firestore persistence for user and restaurant data during onboarding.

## Changes Made

### 1. Cloud Firestore Integration
- **Created [firestore_service.dart](file:///C:/Users/Chandan Yaduvanshi/OneDrive/Documents/Apna POS app/apna_pos/lib/core/services/firestore_service.dart):** A new service dedicated to saving and retrieving `UserModel` and `RestaurantModel` from Cloud Firestore.
- **Updated [database_service.dart](file:///C:/Users/Chandan Yaduvanshi/OneDrive/Documents/Apna POS app/apna_pos/lib/core/database/database_service.dart):** Modified to automatically sync local data changes to Firestore during login, profile updates, and restaurant onboarding.

### 2. Firebase Authentication
- **ID Refactor:** Refactored `UserEntity`, `IAuthRepository`, and `SessionManager` to use `String` IDs (Firebase UIDs) instead of `int` hash codes. This ensures a 1:1 mapping between Firebase Auth and Firestore documents.
- **Phone Auth:** Updated the [LoginScreen](file:///C:/Users/Chandan Yaduvanshi/OneDrive/Documents/Apna POS app/apna_pos/lib/features/auth/login_screen.dart) to use native Firebase Phone Authentication for OTP verification instead of the previous mock/SMS Horizon implementation.
- **Email Auth:** Ensured Email/Password login correctly uses Firebase Auth and syncs the resulting user profile to Firestore.

### 3. Onboarding Persistence
- All data provided during the onboarding process (Full Name, Phone, Company Name, etc.) is now persisted to the `users` and `restaurants` collections in Cloud Firestore via the [CreateProfileScreen](file:///C:/Users/Chandan Yaduvanshi/OneDrive/Documents/Apna POS app/apna_pos/lib/features/auth/create_profile_screen.dart) and [BusinessDetailsScreen](file:///C:/Users/Chandan Yaduvanshi/OneDrive/Documents/Apna POS app/apna_pos/lib/features/onboarding/business_details_screen.dart).

## Verification Results

- **Firestore Sync:** `DatabaseService` now triggers `_firestoreService.saveUser()` and `_firestoreService.saveRestaurant()` upon relevant updates.
- **Phone Auth:** The `LoginScreen` now correctly calls `authRepo.sendOtp` and `authRepo.verifyOtp`.
- **Session Management:** `SessionManager` successfully stores the Firebase UID String for persistent sessions.
