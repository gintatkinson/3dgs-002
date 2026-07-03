/// Central holder for application-wide constants.
///
/// Every UI layer reads the app and window title from here so that a single
/// change propagates everywhere. Alternative: [StringResources] for
/// user-facing strings that need runtime override.
///
/// No file should hardcode its own copy of the application title.
class AppConfig {
  AppConfig._();
  static const String title = 'Platform Console';
  static const String windowTitle = 'Platform Console';
}
