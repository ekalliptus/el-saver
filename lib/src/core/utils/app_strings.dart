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

  // --- Downloads screen: filter & sort --------------------------------------

  static String get filterSort {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Filter & Urutkan";
      case SupportedLanguage.english:
        return "Filter & Sort";
    }
  }

  static String get filterSortDownloads {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Filter & Urutkan Unduhan";
      case SupportedLanguage.english:
        return "Filter & Sort Downloads";
    }
  }

  static String get sortBy {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Urutkan:";
      case SupportedLanguage.english:
        return "Sort by:";
    }
  }

  static String get filterByPlatform {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Filter berdasarkan Platform:";
      case SupportedLanguage.english:
        return "Filter by Platform:";
    }
  }

  static String get allPlatforms {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Semua Platform";
      case SupportedLanguage.english:
        return "All Platforms";
    }
  }

  static String get newestFirst {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Terbaru";
      case SupportedLanguage.english:
        return "Newest First";
    }
  }

  static String get oldestFirst {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Terlama";
      case SupportedLanguage.english:
        return "Oldest First";
    }
  }

  static String get byPlatform {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Berdasarkan Platform";
      case SupportedLanguage.english:
        return "By Platform";
    }
  }

  // --- Downloads screen: items -----------------------------------------------

  static String get downloadPaused {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Unduhan Dijeda";
      case SupportedLanguage.english:
        return "Download Paused";
    }
  }

  static String get openDownloadedFile {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Buka file yang diunduh";
      case SupportedLanguage.english:
        return "Open downloaded file";
    }
  }

  static String get deleteDownload {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Hapus Unduhan";
      case SupportedLanguage.english:
        return "Delete Download";
    }
  }

  static String get deleteDownloadMessage {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Hapus unduhan ini dari riwayat dan hapus filenya?";
      case SupportedLanguage.english:
        return "Do you want to delete this download from history and remove the file?";
    }
  }

  static String get cancel {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Batal";
      case SupportedLanguage.english:
        return "Cancel";
    }
  }

  static String get removeFromHistory {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Hapus dari Riwayat";
      case SupportedLanguage.english:
        return "Remove from History";
    }
  }

  static String get deleteFile {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Hapus File";
      case SupportedLanguage.english:
        return "Delete File";
    }
  }

  static String get delete {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Hapus";
      case SupportedLanguage.english:
        return "Delete";
    }
  }

  static String get deleteFilePermanentlyMessage {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Hapus file unduhan ini secara permanen? Tindakan ini tidak dapat dibatalkan.";
      case SupportedLanguage.english:
        return "Delete this downloaded file permanently? This cannot be undone.";
    }
  }

  static String get justNow {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Baru saja";
      case SupportedLanguage.english:
        return "Just now";
    }
  }

  static String minutesAgo(int minutes) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "${minutes}m lalu";
      case SupportedLanguage.english:
        return "${minutes}m ago";
    }
  }

  static String hoursAgo(int hours) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "${hours}j lalu";
      case SupportedLanguage.english:
        return "${hours}h ago";
    }
  }

  static String daysAgo(int days) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "${days}h lalu";
      case SupportedLanguage.english:
        return "${days}d ago";
    }
  }

  static String get calculating {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Menghitung...";
      case SupportedLanguage.english:
        return "Calculating...";
    }
  }

  static String get downloaded {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Diunduh";
      case SupportedLanguage.english:
        return "Downloaded";
    }
  }

  static String get downloadedVideo {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Video Terunduh";
      case SupportedLanguage.english:
        return "Downloaded Video";
    }
  }

  static String get unknownSize {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Ukuran tidak diketahui";
      case SupportedLanguage.english:
        return "Unknown size";
    }
  }

  static String get unknownTime {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Waktu tidak diketahui";
      case SupportedLanguage.english:
        return "Unknown time";
    }
  }

  static String get fileNotFound {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "File tidak ditemukan";
      case SupportedLanguage.english:
        return "File not found";
    }
  }

  static String get noAppCanOpenFile {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Tidak ada aplikasi yang dapat membuka file ini.";
      case SupportedLanguage.english:
        return "No app can open this file.";
    }
  }

  static String get closeImageViewer {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Tutup penampil gambar";
      case SupportedLanguage.english:
        return "Close image viewer";
    }
  }

  static String get imagePreview {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Pratinjau Gambar";
      case SupportedLanguage.english:
        return "Image preview";
    }
  }

  static String get downloadedImagePreview {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Pratinjau gambar yang diunduh";
      case SupportedLanguage.english:
        return "Downloaded image preview";
    }
  }

  static String get unableToDisplayImage {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Tidak dapat menampilkan gambar ini.";
      case SupportedLanguage.english:
        return "Unable to display this image.";
    }
  }

  static String get savingToGallery {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Menyimpan ke galeri...";
      case SupportedLanguage.english:
        return "Saving to gallery...";
    }
  }

  static String get savedToGallery {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Tersimpan ke galeri!";
      case SupportedLanguage.english:
        return "Saved to gallery!";
    }
  }

  static String videoPlayFailed(String error) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Gagal memutar video: $error";
      case SupportedLanguage.english:
        return "Failed to play video: $error";
    }
  }

  // --- Downloader screen -----------------------------------------------------

  static String loginRequiredTitle(String platformName) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Login dulu ke $platformName";
      case SupportedLanguage.english:
        return "Log in to $platformName first";
    }
  }

  static String loginRequiredExplanation(String platformName) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "$platformName menolak video diambil tanpa sesi login. "
            "Ini aturan platformnya (konten private atau pembatasan bot), "
            "bukan gangguan di aplikasi.";
      case SupportedLanguage.english:
        return "$platformName refuses to fetch the video without a login "
            "session. That's the platform's rule (private content or bot "
            "restrictions), not a problem with the app.";
    }
  }

  static String loginRequiredInstruction(String platformName) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Login sekali lewat situs resmi $platformName di aplikasi "
            "ini. Sesinya dipakai khusus untuk mengambil video, dan kamu "
            "bisa logout kapan saja.";
      case SupportedLanguage.english:
        return "Log in once through the official $platformName site inside "
            "this app. The session is only used to fetch videos, and you "
            "can log out anytime.";
    }
  }

  static String get notNow {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Nanti";
      case SupportedLanguage.english:
        return "Not now";
    }
  }

  static String loginToPlatform(String platformName) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Login ke $platformName";
      case SupportedLanguage.english:
        return "Log in to $platformName";
    }
  }

  static String get failedToFetchVideo {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Gagal mengambil video";
      case SupportedLanguage.english:
        return "Failed to fetch video";
    }
  }

  static String get premiumActive {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Premium aktif";
      case SupportedLanguage.english:
        return "Premium active";
    }
  }

  static String get buyPremiumNoAds {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Beli Premium - tanpa iklan";
      case SupportedLanguage.english:
        return "Buy Premium - ad-free";
    }
  }

  static String qualityOptionsAvailable(int count) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "$count opsi kualitas tersedia";
      case SupportedLanguage.english:
        return "$count quality option${count == 1 ? '' : 's'} available";
    }
  }

  static String get selectQuality {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Pilih Kualitas";
      case SupportedLanguage.english:
        return "Select Quality";
    }
  }

  static String durationMinSec(int minutes, int seconds) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "$minutes mnt $seconds dtk";
      case SupportedLanguage.english:
        return "$minutes min $seconds sec";
    }
  }

  static String durationSec(int seconds) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "$seconds dtk";
      case SupportedLanguage.english:
        return "$seconds sec";
    }
  }

  static String get audioMp3 {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Audio (MP3)";
      case SupportedLanguage.english:
        return "Audio (MP3)";
    }
  }

  static String get sourceNoLongerAvailable {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Sumber unduhan tidak tersedia lagi";
      case SupportedLanguage.english:
        return "Download source is no longer available";
    }
  }

  static String get cobaltYoutubeAuthRequired {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Video ini membutuhkan autentikasi YouTube di server. Hubungi admin server Cobalt untuk konfigurasi cookies YouTube.";
      case SupportedLanguage.english:
        return "This video requires YouTube authentication on the server. Contact the Cobalt server admin to configure YouTube cookies.";
    }
  }

  static String get invalidOrUnsupportedLink {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Link tidak valid atau tidak didukung.";
      case SupportedLanguage.english:
        return "Invalid or unsupported link.";
    }
  }

  static String get cannotAccessContent {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Tidak bisa mengakses konten. Video mungkin private, dihapus, atau platform membutuhkan cookies di server.";
      case SupportedLanguage.english:
        return "Cannot access this content. The video may be private, deleted, or the platform requires cookies on the server.";
    }
  }

  static String get tunnelNotValidForVideo {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Tunnel tidak valid untuk video ini.";
      case SupportedLanguage.english:
        return "The stream link is not valid for this video.";
    }
  }

  static String get serverCannotProcessVideo {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Server tidak bisa memproses video ini. Coba video lain atau hubungi admin server.";
      case SupportedLanguage.english:
        return "The server cannot process this video. Try another video or contact the server admin.";
    }
  }

  static String get failedToExtractAudio {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Gagal mengekstrak audio";
      case SupportedLanguage.english:
        return "Failed to extract audio";
    }
  }

  static String get failedToPrepareMedia {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Gagal menyiapkan media";
      case SupportedLanguage.english:
        return "Failed to prepare media";
    }
  }

  static String get mediaUrlEmpty {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Media URL kosong";
      case SupportedLanguage.english:
        return "Media URL is empty";
    }
  }

  static String get videoLinkEmpty {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Tautan video tidak boleh kosong";
      case SupportedLanguage.english:
        return "Video link cannot be empty";
    }
  }

  static String get savePathEmpty {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Path penyimpanan tidak boleh kosong";
      case SupportedLanguage.english:
        return "Save path cannot be empty";
    }
  }

  static String get downloadFailedFileNotCreated {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Unduhan gagal: File tidak berhasil dibuat";
      case SupportedLanguage.english:
        return "Download failed: File was not created";
    }
  }

  static String get downloadFailedFileEmpty {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Unduhan gagal: File kosong";
      case SupportedLanguage.english:
        return "Download failed: File is empty";
    }
  }

  static String authRequiredMessage(String platformName) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Video $platformName tidak bisa diambil karena platformnya menolak akses tanpa login (konten private atau dibatasi anti-bot). Login sekali saja, setelah itu video bisa diunduh otomatis.";
      case SupportedLanguage.english:
        return "The video on $platformName can't be fetched because the platform refuses access without login (private content or anti-bot restrictions). Log in once, after that videos can be downloaded automatically.";
    }
  }

  // --- Accounts & cookies ----------------------------------------------------

  static String get accountsAndCookies {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Akun & Cookies";
      case SupportedLanguage.english:
        return "Accounts & Cookies";
    }
  }

  static String get loginSuccessSynced {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Login berhasil & cookies tersinkronisasi ke server!";
      case SupportedLanguage.english:
        return "Login successful & cookies synced to server!";
    }
  }

  static String get loginSuccessLocalSyncFailed {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Login berhasil! Cookies tersimpan lokal. (Server sync gagal)";
      case SupportedLanguage.english:
        return "Login successful! Cookies saved locally. (Server sync failed)";
    }
  }

  static String get logoutSuccess {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Logout berhasil";
      case SupportedLanguage.english:
        return "Logout successful";
    }
  }

  static String get logoutLocalSyncFailed {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Logout lokal berhasil, tapi server belum konfirmasi. Coba logout lagi nanti.";
      case SupportedLanguage.english:
        return "Local logout successful, but the server hasn't confirmed. Try logging out again later.";
    }
  }

  static String get accountsInfoMessage {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Login ke platform untuk download konten yang membutuhkan autentikasi. Cookies disimpan terenkripsi di perangkat dan disinkronkan ke server Cobalt.";
      case SupportedLanguage.english:
        return "Log in to platforms to download content that requires authentication. Cookies are stored encrypted on your device and synced to the Cobalt server.";
    }
  }

  static String logoutFrom(String name) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Logout dari $name?";
      case SupportedLanguage.english:
        return "Log out from $name?";
    }
  }

  static String get logoutConfirmContent {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Sesi login akan dihapus dari perangkat ini dan server. Video yang sudah terunduh tidak terhapus.";
      case SupportedLanguage.english:
        return "Your login session will be removed from this device and the server. Already-downloaded videos will not be deleted.";
    }
  }

  static String get logout {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Logout";
      case SupportedLanguage.english:
        return "Logout";
    }
  }

  static String get privacyPolicy {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Kebijakan Privasi";
      case SupportedLanguage.english:
        return "Privacy Policy";
    }
  }

  static String get termsOfService {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Ketentuan Layanan";
      case SupportedLanguage.english:
        return "Terms of Service";
    }
  }

  static String get version {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Versi";
      case SupportedLanguage.english:
        return "Version";
    }
  }

  static String get packageLabel {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Package";
      case SupportedLanguage.english:
        return "Package";
    }
  }

  static String get loggedIn {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Logged in";
      case SupportedLanguage.english:
        return "Logged in";
    }
  }

  static String loggedInWith(String username) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Logged in ($username)";
      case SupportedLanguage.english:
        return "Logged in ($username)";
    }
  }

  static String get notLoggedIn {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Belum login";
      case SupportedLanguage.english:
        return "Not logged in";
    }
  }

  static String get login {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Login";
      case SupportedLanguage.english:
        return "Login";
    }
  }

  static String get waitingForLogin {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Menunggu login...";
      case SupportedLanguage.english:
        return "Waiting for login...";
    }
  }

  static String platformNotSupported(String platform) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Login $platform belum didukung di aplikasi.";
      case SupportedLanguage.english:
        return "Login for $platform is not supported in the app yet.";
    }
  }

  static String get manualLoginInstruction {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Login di halaman ini, lalu tekan tombol 'Selesai Login'.";
      case SupportedLanguage.english:
        return "Log in on this page, then press the 'Finish Login' button.";
    }
  }

  static String get loginDetectedExtracting {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Login terdeteksi, mengambil cookies...";
      case SupportedLanguage.english:
        return "Login detected, extracting cookies...";
    }
  }

  static String get cookiesNotAvailable {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Cookies belum tersedia.";
      case SupportedLanguage.english:
        return "Cookies not available yet.";
    }
  }

  static String get loginNotDetected {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Login belum terdeteksi. Pastikan sudah sign-in, lalu tekan 'Selesai Login'.";
      case SupportedLanguage.english:
        return "Login not detected. Make sure you're signed in, then press 'Finish Login'.";
    }
  }

  static String get extractCookiesFailed {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Gagal mengambil cookies.";
      case SupportedLanguage.english:
        return "Failed to extract cookies.";
    }
  }

  static String loginTitle(String name) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Login $name";
      case SupportedLanguage.english:
        return "Log in to $name";
    }
  }

  static String get extractingCookies {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Mengambil cookies...";
      case SupportedLanguage.english:
        return "Extracting cookies...";
    }
  }

  static String get finishLogin {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Selesai Login";
      case SupportedLanguage.english:
        return "Finish Login";
    }
  }

  // --- WhatsApp status -------------------------------------------------------

  static String get whatsappStatus {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Status WhatsApp";
      case SupportedLanguage.english:
        return "WhatsApp Status";
    }
  }

  static String get statusSavedToGallery {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Status tersimpan ke galeri ✔";
      case SupportedLanguage.english:
        return "Status saved to gallery ✔";
    }
  }

  static String get filePermissionNeeded {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Butuh izin akses file";
      case SupportedLanguage.english:
        return "File access permission needed";
    }
  }

  static String get whatsappPermissionMessage {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Status WhatsApp tersimpan di folder tersembunyi WhatsApp. Aktifkan izin \"All files access\" untuk EL-Saver agar aplikasi bisa membacanya.";
      case SupportedLanguage.english:
        return "WhatsApp statuses are stored in a hidden WhatsApp folder. Enable the \"All files access\" permission for EL-Saver so the app can read them.";
    }
  }

  static String get grantPermission {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Berikan Izin";
      case SupportedLanguage.english:
        return "Grant Permission";
    }
  }

  static String get loadFailed {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Gagal memuat";
      case SupportedLanguage.english:
        return "Failed to load";
    }
  }

  static String get tryAgain {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Coba Lagi";
      case SupportedLanguage.english:
        return "Try Again";
    }
  }

  static String get noStatusYet {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Belum ada status";
      case SupportedLanguage.english:
        return "No statuses yet";
    }
  }

  static String get emptyStatusGuide {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "1. Buka WhatsApp, lihat status temanmu\n2. Kembali ke sini dan tarik ke bawah untuk refresh\n\nStatus hanya tersedia selama 24 jam di WhatsApp.";
      case SupportedLanguage.english:
        return "1. Open WhatsApp and view your friends' statuses\n2. Come back here and pull down to refresh\n\nStatuses are only available for 24 hours on WhatsApp.";
    }
  }

  static String get cannotPlayMedia {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Tidak bisa memutar media ini. File mungkin sudah terhapus dari WhatsApp.";
      case SupportedLanguage.english:
        return "Can't play this media. The file may have been deleted from WhatsApp.";
    }
  }

  // --- Premium purchase ------------------------------------------------------

  static String get loadPackagesFailed {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Tidak bisa memuat paket. Periksa koneksi internet lalu coba lagi.";
      case SupportedLanguage.english:
        return "Can't load packages. Check your internet connection and try again.";
    }
  }

  static String get createOrderFailed {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Gagal membuat order. Coba lagi.";
      case SupportedLanguage.english:
        return "Failed to create order. Try again.";
    }
  }

  static String get paymentConfirmed {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Pembayaran terkonfirmasi! Premium aktif 🎉";
      case SupportedLanguage.english:
        return "Payment confirmed! Premium is active 🎉";
    }
  }

  static String get paymentNotConfirmedYet {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Belum terkonfirmasi. Kami terus memeriksa otomatis.";
      case SupportedLanguage.english:
        return "Not confirmed yet. We'll keep checking automatically.";
    }
  }

  static String get checkStatusFailed {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Gagal memeriksa status. Coba lagi.";
      case SupportedLanguage.english:
        return "Failed to check status. Try again.";
    }
  }

  static String get buyPremium {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Beli Premium";
      case SupportedLanguage.english:
        return "Buy Premium";
    }
  }

  static String get premiumInfoCard {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Premium = tanpa iklan, sekali bayar untuk perangkat ini. Pilih paket, bayar, dan lisensi terpasang otomatis — tanpa memasukkan kode manual.";
      case SupportedLanguage.english:
        return "Premium = no ads, one-time payment for this device. Pick a package, pay, and the license is installed automatically — no manual code entry.";
    }
  }

  static String get activeForeverOnDevice {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Aktif selamanya di perangkat ini";
      case SupportedLanguage.english:
        return "Active forever on this device";
    }
  }

  static String activeDaysOnDevice(int days) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Aktif $days hari di perangkat ini";
      case SupportedLanguage.english:
        return "Active for $days days on this device";
    }
  }

  static String get scanToPay {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Scan dengan GoPay / DANA / OVO / m-banking";
      case SupportedLanguage.english:
        return "Scan with GoPay / DANA / OVO / m-banking";
    }
  }

  static String totalLabel(String amount) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Total: $amount";
      case SupportedLanguage.english:
        return "Total: $amount";
    }
  }

  static String orderNumber(String orderId) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Nomor pesanan: $orderId";
      case SupportedLanguage.english:
        return "Order number: $orderId";
    }
  }

  static String orderTitle(String packageName) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Pesanan $packageName";
      case SupportedLanguage.english:
        return "Order: $packageName";
    }
  }

  static String get waitingForPayment {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Menunggu pembayaran. Lisensi akan aktif otomatis begitu pembayaran terdeteksi.";
      case SupportedLanguage.english:
        return "Waiting for payment. The license will activate automatically once payment is detected.";
    }
  }

  static String get iAlreadyPaidCheckNow {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Saya Sudah Bayar — Cek Sekarang";
      case SupportedLanguage.english:
        return "I've Already Paid — Check Now";
    }
  }

  static String get cancelOrder {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Batalkan";
      case SupportedLanguage.english:
        return "Cancel";
    }
  }

  // --- Permissions nudge & update dialog --------------------------------------

  static String get completeAppPermissions {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Lengkapi izin aplikasi";
      case SupportedLanguage.english:
        return "Complete App Permissions";
    }
  }

  static String get permissionNudgeContent {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Versi baru EL-Saver butuh izin tambahan: akses media (fitur Status WhatsApp) dan akses file lengkap. Tanpa itu, sebagian fitur tidak berfungsi.\n\nAktifkan sekarang? Prosesnya cepat, tinggal ikuti beberapa halaman pengaturan.";
      case SupportedLanguage.english:
        return "The new version of EL-Saver needs additional permissions: media access (WhatsApp Status feature) and full file access. Without them, some features won't work.\n\nActivate now? It's quick — just follow a few settings pages.";
    }
  }

  static String get activateNow {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Aktifkan Sekarang";
      case SupportedLanguage.english:
        return "Activate Now";
    }
  }

  static String get downloadingUpdate {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Mengunduh Update...";
      case SupportedLanguage.english:
        return "Downloading Update...";
    }
  }

  static String get waitingForInstaller {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Menunggu installer...";
      case SupportedLanguage.english:
        return "Waiting for installer...";
    }
  }

  static String get failed {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Gagal";
      case SupportedLanguage.english:
        return "Failed";
    }
  }

  static String get installerPopupInstruction {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Ikuti popup installer yang muncul di layar untuk menyelesaikan pembaruan. Aplikasi jangan ditutup sampai install selesai.";
      case SupportedLanguage.english:
        return "Follow the installer popup on screen to complete the update. Don't close the app until the installation is finished.";
    }
  }

  static String versionUpgrade(String from, String to) {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "v$from → v$to";
      case SupportedLanguage.english:
        return "v$from → v$to";
    }
  }

  static String get doNotCloseThisDialog {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Jangan tutup dialog ini";
      case SupportedLanguage.english:
        return "Don't close this dialog";
    }
  }

  static String get reopenInstaller {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Buka Installer Lagi";
      case SupportedLanguage.english:
        return "Reopen Installer";
    }
  }

  static String get close {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Tutup";
      case SupportedLanguage.english:
        return "Close";
    }
  }

  static String get installManually {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Install Manual";
      case SupportedLanguage.english:
        return "Install Manually";
    }
  }

  static String get cannotOpenSystemInstaller {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Tidak bisa membuka installer sistem. Coba lagi.";
      case SupportedLanguage.english:
        return "Can't open the system installer. Try again.";
    }
  }

  static String get downloadFailedRetry {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Download gagal. Coba lagi.";
      case SupportedLanguage.english:
        return "Download failed. Try again.";
    }
  }

  static String get cannotOpenInstaller {
    switch (_currentLanguage) {
      case SupportedLanguage.indonesian:
        return "Tidak bisa membuka installer";
      case SupportedLanguage.english:
        return "Can't open the installer";
    }
  }
}
