class ApiConfig {
  // Cobalt API instances - app tries each in order until one works
  // Add your own self-hosted instance at the top for best reliability
  // Docker: https://github.com/imputnet/cobalt
  static const List<String> cobaltInstances = [
    // Self-hosted: has synced cookies, best for login-gated content
    "https://api.ekalliptus.com",
    // Public no-auth instances (verified live) - fallback
    "https://co.eepy.today",
    "https://co.otomir23.me",
  ];

  // Per-request timeouts (seconds). Short connect timeout so dead
  // instances are skipped fast instead of hanging the fallback chain.
  static const int cobaltConnectTimeoutSeconds = 6;
  static const int cobaltReceiveTimeoutSeconds = 20;

  // yt-dlp /info is only quality discovery — keep it short so a slow/broken
  // extractor fails fast instead of blocking the whole fetch for minutes.
  // The heavy /download (server-side merge) still uses its own long timeout.
  static const int ytdlpInfoTimeoutSeconds = 30;

  // Cobalt API key (UUID key registered in the instance's keys.json)
  static const String cobaltApiKey =
      "5f22dee6-3789-438b-bb57-9349e9ec0ceb";

  // Secret shared with the backend services (FastAPI X-Api-Key)
  static const String backendApiKey = "S3B1XAbtnEvVm34MvRHM4kokQVW8dre0";

  // Cookie sync server behind the api.ekalliptus.com TLS reverse proxy.
  static const String cookieSyncUrl = "https://api.ekalliptus.com/cookie-sync";
  static const String cookieSyncApiKey = backendApiKey;

  // yt-dlp API behind the api.ekalliptus.com TLS reverse proxy.
  static const String ytdlpApiUrl = "https://api.ekalliptus.com/ytdlp";
  static const String ytdlpApiKey = backendApiKey;

  // TikWM fallback for TikTok (free, no auth)
  static const bool useTikwmFallback = true;

  // Video quality preference sent to Cobalt
  static const String videoQuality = "1080";

  // Download settings
  static const bool enableRetryOnFailure = true;
  static const int maxRetryAttempts = 3;
  static const int retryDelaySeconds = 2;
  static const bool enableDebugLogs = true;

  // Quality preferences
  static const bool preferHighQuality = true;
  static const bool supportImageGalleries = true;

  // Error messages
  static const String networkError =
      "Network connection error. Please check your internet connection.";
  static const String unsupportedPlatform =
      "This platform is not yet supported. We're working on adding support!";
  static const String rateLimitError =
      "Rate limit exceeded. Please wait a moment and try again.";
  static const String invalidUrlError =
      "Invalid URL format. Please check the link and try again.";
  static const String videoNotFound =
      "Video not found or is private. Please check if the content is publicly available.";
  static const String allApisFailed =
      "All download services failed. Try again later or use a different link.";
}
