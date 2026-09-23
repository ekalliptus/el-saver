package com.ekalliptus.saver

import android.app.PictureInPictureParams
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageInstaller
import android.content.res.Configuration
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Rational
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "pip_service"
    private val MEDIA_STORE_CHANNEL = "media_store"
    private val THUMBNAIL_CHANNEL = "video_thumbnail"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isPipSupported" -> {
                    result.success(isPipSupported())
                }
                "enterPipMode" -> {
                    val aspectRatio = call.argument<Double>("aspectRatio") ?: 16.0 / 9.0
                    val title = call.argument<String>("title") ?: "EL-Saver"
                    val subtitle = call.argument<String>("subtitle") ?: "Video Player"

                    result.success(enterPipMode(aspectRatio, title, subtitle))
                }
                "updatePipParams" -> {
                    val aspectRatio = call.argument<Double>("aspectRatio") ?: 16.0 / 9.0
                    val title = call.argument<String>("title") ?: "EL-Saver"
                    val subtitle = call.argument<String>("subtitle") ?: "Video Player"

                    updatePipParams(aspectRatio, title, subtitle)
                    result.success(null)
                }
                "exitPipMode" -> {
                    exitPipMode()
                    result.success(null)
                }
                "installApk" -> {
                    val apkPath = call.argument<String>("apkPath")
                    if (apkPath != null) {
                        try {
                            installApk(apkPath)
                            result.success(true)
                        } catch (e: Exception) {
                            e.printStackTrace()
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            THUMBNAIL_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method != "thumbnailFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val videoPath = call.argument<String>("video")
            val maxWidth = (call.argument<Number>("maxWidth") ?: 0).toInt()
            val quality = (call.argument<Number>("quality") ?: 50).toInt()
            if (videoPath.isNullOrBlank()) {
                result.error("INVALID_PATH", "Video file path is required.", null)
                return@setMethodCallHandler
            }

            try {
                val path = generateThumbnail(videoPath, maxWidth, quality)
                result.success(path)
            } catch (e: Exception) {
                result.error("THUMBNAIL_FAILED", e.message ?: "Unable to generate thumbnail.", null)
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MEDIA_STORE_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method != "saveAudio") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val filePath = call.argument<String>("filePath")
            if (filePath.isNullOrBlank()) {
                result.error("INVALID_PATH", "Audio file path is required.", null)
                return@setMethodCallHandler
            }

            try {
                saveAudioToMusic(filePath)
                result.success(null)
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("SAVE_AUDIO_FAILED", e.message ?: "Unable to save audio.", null)
            }
        }
    }

    // Extracts a poster frame and writes it as PNG into the app cache dir.
    private fun generateThumbnail(videoPath: String, maxWidth: Int, quality: Int): String {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(videoPath)
            var bitmap = retriever.getFrameAtTime(
                0,
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC
            ) ?: throw IllegalStateException("No frame could be extracted.")

            if (maxWidth in 1 until bitmap.width) {
                val scaledHeight = bitmap.height * maxWidth / bitmap.width
                bitmap = android.graphics.Bitmap.createScaledBitmap(
                    bitmap, maxWidth, scaledHeight, true
                )
            }

            val cacheDir = cacheDir.resolve("video_thumbnails").apply { mkdirs() }
            val target = File.createTempFile("thumb_", ".png", cacheDir)
            target.outputStream().use { out ->
                @Suppress("DEPRECATION")
                bitmap.compress(
                    android.graphics.Bitmap.CompressFormat.PNG,
                    quality.coerceIn(0, 100),
                    out
                )
            }
            bitmap.recycle()
            return target.absolutePath
        } finally {
            retriever.release()
        }
    }

    private fun saveAudioToMusic(filePath: String) {
        val source = File(filePath)
        if (!source.isFile) {
            throw IllegalArgumentException("Audio file not found: $filePath")
        }
        if (source.length() == 0L) {
            throw IllegalArgumentException("Audio file is empty.")
        }

        val extension = source.extension.lowercase()
        val mimeType = when (extension) {
            "mp3" -> "audio/mpeg"
            "m4a" -> "audio/mp4"
            "aac" -> "audio/aac"
            "wav" -> "audio/wav"
            "ogg" -> "audio/ogg"
            "opus" -> "audio/opus"
            "flac" -> "audio/flac"
            "amr" -> "audio/amr"
            else -> throw IllegalArgumentException("Unsupported audio file type: .$extension")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveAudioWithMediaStore(source, mimeType)
        } else {
            saveLegacyAudio(source, mimeType)
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun saveAudioWithMediaStore(source: File, mimeType: String) {
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, source.name)
            put(MediaStore.Audio.Media.MIME_TYPE, mimeType)
            put(
                MediaStore.Audio.Media.RELATIVE_PATH,
                "${Environment.DIRECTORY_MUSIC}/EL-Saver"
            )
            put(MediaStore.Audio.Media.IS_PENDING, 1)
        }
        val resolver = contentResolver
        val uri = resolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Unable to create Music entry.")

        try {
            resolver.openOutputStream(uri)?.use { output ->
                FileInputStream(source).use { input -> input.copyTo(output) }
            } ?: throw IllegalStateException("Unable to open Music entry.")
            resolver.update(uri, ContentValues().apply {
                put(MediaStore.Audio.Media.IS_PENDING, 0)
            }, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
    }

    @Suppress("DEPRECATION")
    private fun saveLegacyAudio(source: File, mimeType: String) {
        val directory = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC),
            "EL-Saver"
        )
        if (!directory.exists() && !directory.mkdirs()) {
            throw IllegalStateException("Unable to create Music/EL-Saver.")
        }

        var target = File(directory, source.name)
        var suffix = 1
        while (target.exists()) {
            target = File(directory, "${source.nameWithoutExtension}_$suffix.${source.extension}")
            suffix++
        }
        FileInputStream(source).use { input ->
            FileOutputStream(target).use { output -> input.copyTo(output) }
        }
        MediaScannerConnection.scanFile(
            this,
            arrayOf(target.absolutePath),
            arrayOf(mimeType),
            null
        )
    }

    /// Install an APK silently via PackageInstaller.Session.
    /// Requires the user to have granted "Install unknown apps" to this app.
    private fun installApk(apkPath: String) {
        val file = File(apkPath)
        if (!file.exists()) {
            throw IllegalArgumentException("APK file not found: $apkPath")
        }

        val packageInstaller = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL
        )
        val sessionId = packageInstaller.createSession(params)
        val session = packageInstaller.openSession(sessionId)

        try {
            // Add the APK file to the session
            val inputStream = FileInputStream(file)
            val outStream = session.openWrite("el_saver_update.apk", 0, file.length())
            try {
                val buffer = ByteArray(8192)
                var size: Int
                while (inputStream.read(buffer).also { size = it } > 0) {
                    outStream.write(buffer, 0, size)
                }
                session.fsync(outStream)
            } finally {
                outStream.close()
                inputStream.close()
            }

            // Commit the session with a broadcast intent to receive the result
            val intent = Intent(this, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                this,
                sessionId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            session.commit(pendingIntent.intentSender)
        } catch (e: Exception) {
            session.abandon()
            throw e
        }
    }

    private fun isPipSupported(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE)
        } else {
            false
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun enterPipMode(aspectRatio: Double, title: String, subtitle: String): Boolean {
        return try {
            if (!isPipSupported()) return false

            val rational = Rational(
                (aspectRatio * 1000).toInt(),
                1000
            )

            val params = PictureInPictureParams.Builder()
                .setAspectRatio(rational)
                .build()

            enterPictureInPictureMode(params)
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun updatePipParams(aspectRatio: Double, title: String, subtitle: String) {
        try {
            if (!isPipSupported() || !isInPictureInPictureMode) return

            val rational = Rational(
                (aspectRatio * 1000).toInt(),
                1000
            )

            val params = PictureInPictureParams.Builder()
                .setAspectRatio(rational)
                .build()

            setPictureInPictureParams(params)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun exitPipMode() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isInPictureInPictureMode) {
                // Move task to front to exit PIP mode
                moveTaskToBack(false)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)

        // Notify Flutter about PIP mode change
        methodChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()

        // Notify Flutter that user pressed home button
        methodChannel?.invokeMethod("onUserLeaveHint", null)
    }
}
