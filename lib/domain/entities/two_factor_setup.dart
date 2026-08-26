/// Données de démarrage d'activation 2FA — réponse de `POST /api/auth/2fa/setup`.
///
/// Correspond exactement à `TwoFactorService.demarrerActivation` (backend) :
/// un secret TOTP à associer dans l'application d'authentification, l'URI
/// `otpauth://` correspondante et un QR code PNG en data URI base64.
class TwoFactorSetup {
  final String secret;
  final String otpAuthUrl;
  final String? qrCodeImage;

  const TwoFactorSetup({
    required this.secret,
    required this.otpAuthUrl,
    this.qrCodeImage,
  });

  factory TwoFactorSetup.fromJson(Map<String, dynamic> json) {
    return TwoFactorSetup(
      secret: json['secret'] ?? '',
      otpAuthUrl: json['otpAuthUrl'] ?? '',
      qrCodeImage: json['qrCodeImage'],
    );
  }
}
