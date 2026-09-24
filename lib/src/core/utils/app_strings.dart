import '../services/language_service.dart';

class AppStrings {
  static SupportedLanguage get _currentLanguage =>
      LanguageService.instance.currentLanguage;

  // App Information
  static String get appName => "EL-Saver";
  static String get appSlogan {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Pemutar Video Ultimate Anda";
      case SupportedLanguage.english:
        return "Your Ultimate Video Saver";
    }
  }

  // UI Elements
  static String get videoLink {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Tautan video";
      case SupportedLanguage.english:
        return "Video link";
    }
  }

  static String get inputLinkFieldText {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Tempel tautan video di sini";
      case SupportedLanguage.english:
        return "Paste video link here";
    }
  }

  static String get download {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Unduh";
      case SupportedLanguage.english:
        return "Download";
    }
  }

  static String get paste {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Tempel";
      case SupportedLanguage.english:
        return "Paste";
    }
  }

  static String get downloading {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Mengunduh...";
      case SupportedLanguage.english:
        return "Downloading...";
    }
  }

  static String get downloads {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Unduhan";
      case SupportedLanguage.english:
        return "Downloads";
    }
  }

  static String get videoLinkRequired {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Tautan video diperlukan";
      case SupportedLanguage.english:
        return "Video link is Required";
    }
  }

  static String get downloadSuccess {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Unduhan berhasil";
      case SupportedLanguage.english:
        return "Download success";
    }
  }

  static String get play {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Putar";
      case SupportedLanguage.english:
        return "Play";
    }
  }

  static String get retryDownload {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Coba unduh lagi";
      case SupportedLanguage.english:
        return "Retry download";
    }
  }

  static String get downloadFall {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Unduhan gagal";
      case SupportedLanguage.english:
        return "Download failed";
    }
  }

  static String get permissionsRequired {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Izin diperlukan, Silakan terima izin dan coba lagi";
      case SupportedLanguage.english:
        return "Permissions is required, Please accept permissions and try again";
    }
  }

  static String get oldDownloads {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Unduhan Lama";
      case SupportedLanguage.english:
        return "Old Downloads";
    }
  }

  static String get darkMode {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Mode Gelap";
      case SupportedLanguage.english:
        return "Dark Mode";
    }
  }

  static String get lightMode {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Mode Terang";
      case SupportedLanguage.english:
        return "Light Mode";
    }
  }

  // Language Settings
  static String get language {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Bahasa";
      case SupportedLanguage.english:
        return "Language";
    }
  }

  static String get languageSettings {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Pengaturan Bahasa";
      case SupportedLanguage.english:
        return "Language Settings";
    }
  }

  static String get chooseLanguage {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Pilih Bahasa";
      case SupportedLanguage.english:
        return "Choose Language";
    }
  }

  static String get supportedPlatforms {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Platform yang Didukung:";
      case SupportedLanguage.english:
        return "Supported Platforms:";
    }
  }

  // Recent Downloads
  static String get recentDownloads {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Unduhan Terbaru";
      case SupportedLanguage.english:
        return "Recent Downloads";
    }
  }

  static String get viewAll {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Lihat Semua";
      case SupportedLanguage.english:
        return "View All";
    }
  }

  static String get noDownloadsYet {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Belum ada unduhan";
      case SupportedLanguage.english:
        return "No downloads yet";
    }
  }

  // Update Dialog
  static String get updateAvailable {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Update Tersedia!";
      case SupportedLanguage.english:
        return "Update Available!";
    }
  }

  static String get downloadAndInstall {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Download & Install";
      case SupportedLanguage.english:
        return "Download & Install";
    }
  }

  static String get later {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Nanti saja";
      case SupportedLanguage.english:
        return "Later";
    }
  }

  static String get checkUpdate {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Periksa Update";
      case SupportedLanguage.english:
        return "Check for Update";
    }
  }

  static String get appUpToDate {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Aplikasi sudah versi terbaru!";
      case SupportedLanguage.english:
        return "App is up to date!";
    }
  }

  static String get appInfo {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Info Aplikasi";
      case SupportedLanguage.english:
        return "App Info";
    }
  }

  // Helper method to get localized platform name
  static String getPlatformName(String platform) {
    if (_currentLanguage == SupportedLanguage.indonesian) {
      switch (platform.toLowerCase()) {
        case 'facebook':
          return 'Facebook';
        case 'instagram':
          return 'Instagram';
        case 'threads':
          return 'Threads';
        case 'tiktok':
          return 'TikTok';
        case 'youtube':
          return 'YouTube';
        case 'youtubemusic':
          return 'YouTube Music';
        case 'twitter':
          return 'Twitter/X';
        case 'bilibili':
          return 'Bilibili';
        default:
          return platform;
      }
    }
    return platform; // English names are already correct
  }
}
