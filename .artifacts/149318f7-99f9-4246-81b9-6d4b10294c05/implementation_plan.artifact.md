# Firebase Authentication and Onboarding Data Persistence

This plan outlines the implementation of Firebase Authentication for login (Phone & Email) and saving user onboarding data to Cloud Firestore.

## User Review Required

> [!IMPORTANT]
> The phone login will be switched from SMS Horizon to Firebase Phone Authentication. This requires the app to be correctly configured in the Firebase Console with Phone Auth enabled.

## Proposed Changes

### Core Services

#### [NEW] [firestore_service.dart](file:///C:/Users/Chandan Yaduvanshi/OneDrive/Documents/Apna POS app/apna_pos/lib/core/services/firestore_service.dart)
Create a new service to handle Firestore operations:
- `saveUser(UserModel user)`: Save or update user profile in `users` collection.
- `saveRestaurant(RestaurantModel restaurant)`: Save or update restaurant details in `restaurants` collection.

#### [MODIFY] [database_service.dart](file:///C:/Users/Chandan Yaduvanshi/OneDrive/Documents/Apna POS app/apna_pos/lib/core/database/database_service.dart)
Integrate `FirestoreService` into `DatabaseService`:
- Update `saveActiveUser` to also save to Firestore.
- Update `saveRestaurantOnboarding` to also save to Firestore.
- Update `updateUserProfile` and `updateBusinessName` to sync with Firestore.

### Authentication

#### [MODIFY] [login_screen.dart](file:///C:/Users/Chandan Yaduvanshi/OneDrive/Documents/Apna POS app/apna_pos/lib/features/auth/login_screen.dart)
- Update `_showPhoneOtpVerificationDialog` to use `FirebaseAuthRepository`'s `sendOtp` and `verifyOtp` instead of the mock/third-party SMS service.
- Ensure `_handleAuthAction` correctly handles the Firebase Auth response and saves the user to Firestore via `DatabaseService`.

#### [MODIFY] [firebase_auth_repository.dart](file:///C:/Users/Chandan Yaduvanshi/OneDrive/Documents/Apna POS app/apna_pos/lib/features/auth/data/repositories/firebase_auth_repository.dart)
- Ensure `verifyOtp` returns a `UserEntity` that includes the Firebase UID.

### Onboarding

#### [MODIFY] [business_details_screen.dart](file:///C:/Users/Chandan Yaduvanshi/OneDrive/Documents/Apna POS app/apna_pos/lib/features/onboarding/business_details_screen.dart)
- Ensure that when "Next" is pressed, the data is saved through `DatabaseService`, which will now also sync to Firestore.

## Verification Plan

### Automated Tests
- No automated tests planned for this UI/Service integration, but manual verification will be thorough.

### Manual Verification
- **Login Flow:**
    - Test Email/Password login. Verify user is logged in and data exists in local state and (if possible to check) Firestore.
    - Test Phone login (if Firebase project is configured).
- **Onboarding Flow:**
    - Complete onboarding screens.
    - Check if `RestaurantModel` data is saved to Firestore under the user's ID or a generated restaurant ID.
