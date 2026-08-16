import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'registration_state.dart';
import '../../domain/entities/user_registration_entity.dart';
import '../../data/datasources/registration_remote_datasource.dart';
import '../../../../core/database/database_service.dart';

import '../../../../core/network/api_client.dart';

final dioProvider = Provider<Dio>((ref) {
  return ApiClient().dio;
});

final registrationDataSourceProvider = Provider<IRegistrationRemoteDataSource>((ref) {
  return RegistrationRemoteDataSource(ref.watch(dioProvider));
});

final registrationNotifierProvider =
    StateNotifierProvider<RegistrationNotifier, RegistrationState>((ref) {
  return RegistrationNotifier(ref.watch(registrationDataSourceProvider));
});

class RegistrationNotifier extends StateNotifier<RegistrationState> {
  final IRegistrationRemoteDataSource _dataSource;
  final ImagePicker _imagePicker = ImagePicker();

  RegistrationNotifier(this._dataSource) : super(RegistrationState.initial());

  Future<void> pickProfilePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image != null) {
        state = state.copyWith(profilePhotoPath: image.path);
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> registerUser(UserRegistrationEntity entity) async {
    state = state.copyWith(status: RegistrationStatus.submitting, errorMessage: null);

    try {
      final db = DatabaseService();
      await db.registerUser(
        name: entity.fullName,
        email: entity.email,
        password: entity.password,
        pin: '1234',
        phone: entity.phone,
        profileImage: entity.profilePhotoPath,
        onboardingDetails: '${entity.businessName} - ${entity.businessType}',
      );

      state = state.copyWith(
        status: RegistrationStatus.otpVerificationPending,
        registeredEmail: entity.email,
      );
    } catch (e) {
      state = state.copyWith(
        status: RegistrationStatus.error,
        errorMessage: 'Registration failed: ${e.toString().replaceAll("Exception: ", "")}',
      );
    }
  }

  Future<bool> verifyOtp(String code) async {
    state = state.copyWith(status: RegistrationStatus.submitting);
    final email = state.registeredEmail ?? 'user@apnapos.com';
    
    final verified = await _dataSource.verifyOtp(email, code, 'REGISTRATION');
    if (verified) {
      state = state.copyWith(status: RegistrationStatus.success);
      return true;
    } else {
      state = state.copyWith(
        status: RegistrationStatus.error,
        errorMessage: 'Invalid or expired OTP code',
      );
      return false;
    }
  }
}
