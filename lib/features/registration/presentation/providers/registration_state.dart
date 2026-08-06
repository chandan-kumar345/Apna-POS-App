enum RegistrationStatus {
  initial,
  submitting,
  success,
  otpVerificationPending,
  error,
}

class RegistrationState {
  final RegistrationStatus status;
  final String? profilePhotoPath;
  final String? registeredEmail;
  final String? errorMessage;

  const RegistrationState({
    required this.status,
    this.profilePhotoPath,
    this.registeredEmail,
    this.errorMessage,
  });

  factory RegistrationState.initial() => const RegistrationState(status: RegistrationStatus.initial);

  RegistrationState copyWith({
    RegistrationStatus? status,
    String? profilePhotoPath,
    String? registeredEmail,
    String? errorMessage,
  }) {
    return RegistrationState(
      status: status ?? this.status,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
      registeredEmail: registeredEmail ?? this.registeredEmail,
      errorMessage: errorMessage,
    );
  }
}
