package com.slideshow.photo_slideshow_maker

import android.app.Activity
import android.content.ClipData
import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var player: MediaPlayer? = null
    private var audioRequest = 0
    private val projects by lazy { getSharedPreferences("slideshow", MODE_PRIVATE) }
    private val exports by lazy { File(cacheDir, "exports").apply { mkdirs() } }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "slideshow/media")
            .setMethodCallHandler(::handle)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "pickPhotos" -> select(result, "image/*", PHOTOS)
                "pickAudio" -> select(result, "audio/*", AUDIO)
                "capturePhoto" -> launch(result, Intent(MediaStore.ACTION_IMAGE_CAPTURE), CAMERA)
                "loadProjects" -> result.success(projects.getString("items", null))
                "saveProjects" -> {
                    projects.edit().putString("items", call.arguments as String).apply()
                    result.success(null)
                }
                "previewAudio" -> {
                    val request = ++audioRequest
                    val args = call.arguments as? Map<*, *>
                    val volume = (args?.get("volume") as? Number)?.toFloat() ?: .6f
                    background(result) {
                        val path = soundtrack(args?.get("source") ?: call.arguments)
                        runOnUiThread { if (!isDestroyed && request == audioRequest) runCatching { play(path, volume) } }
                        null
                    }
                }
                "stopAudio" -> { stopAudio(); result.success(null) }
                "volume" -> {
                    val volume = (call.arguments as Number).toFloat()
                    player?.setVolume(volume, volume)
                    result.success(null)
                }
                "beginExport" -> background(result) {
                    exports.listFiles()?.filter { System.currentTimeMillis() - it.lastModified() > 86_400_000 }
                        ?.forEach { it.deleteRecursively() }
                    UUID.randomUUID().toString().also { exportFolder(it).mkdirs() }
                }
                "writeFrame" -> background(result) {
                    val folder = exportFolder(call.argument<String>("id")!!)
                    File(folder, "${call.argument<Int>("index")}.rgba")
                        .writeBytes(call.argument<ByteArray>("bytes")!!)
                    null
                }
                "encode" -> background(result) {
                    val folder = exportFolder(call.argument<String>("id")!!)
                    val video = File(folder, "Slideshow.mp4")
                    val music = call.argument<String>("music")
                    val volume = call.argument<Double>("volume") ?: 0.6
                    val audio = when {
                        music == null || volume == 0.0 -> null
                        File(music).isFile -> File(music)
                        else -> AudioSamples.file(cacheDir, music.hashCode() and 7, volume)
                    }
                    VideoEncoder.encode(
                        folder, video, call.argument<Int>("width")!!, call.argument<Int>("height")!!,
                        call.argument<Int>("count")!!, call.argument<Int>("transition")!!,
                        call.argument<Double>("intensity")!!, audio
                    )
                    video.path
                }
                "cleanFrames" -> background(result) {
                    val folder = exportFolder(call.arguments as String)
                    folder.listFiles { file -> file.extension == "rgba" }?.forEach { it.delete() }
                    if (folder.list()?.isEmpty() == true) folder.delete()
                    null
                }
                "saveVideo" -> background(result) { publish(File(call.arguments as String)); null }
                "shareVideo" -> {
                    val file = File(call.arguments as String)
                    val uri = Uri.Builder().scheme("content").authority("${packageName}.exports")
                        .appendPath(file.parentFile!!.name).appendPath(file.name).build()
                    val share = Intent(Intent.ACTION_SEND).apply {
                        type = "video/mp4"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        clipData = ClipData.newUri(contentResolver, file.name, uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(Intent.createChooser(share, "Share slideshow"))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("media", error.message, null)
        }
    }

    private fun exportFolder(id: String): File {
        require(runCatching { UUID.fromString(id).toString() == id }.getOrDefault(false))
        return File(exports, id)
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        worker.execute {
            try {
                val value = work()
                runOnUiThread { result.success(value) }
            } catch (error: Exception) {
                runOnUiThread { result.error("media", error.message, null) }
            }
        }
    }

    private fun select(result: MethodChannel.Result, mime: String, request: Int) = launch(
        result,
        Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            type = mime
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, request == PHOTOS)
        },
        request
    )

    private fun launch(result: MethodChannel.Result, intent: Intent, request: Int) {
        if (pending != null) { result.error("busy", "A media picker is already open", null); return }
        startActivityForResult(intent, request)
        pending = result
    }

    @Deprecated("Android activity result callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode !in PHOTOS..CAMERA) return
        val result = pending ?: return
        pending = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(if (requestCode == AUDIO) null else emptyList<String>())
            return
        }
        background(result) {
            if (requestCode == CAMERA) {
                @Suppress("DEPRECATION")
                val thumbnail = data.extras?.get("data") as? Bitmap
                if (thumbnail == null) emptyList<String>()
                else {
                    val file = mediaFile("jpg")
                    file.outputStream().use { thumbnail.compress(Bitmap.CompressFormat.JPEG, 92, it) }
                    listOf(file.path)
                }
            } else {
                val uris = data.clipData?.let { items ->
                    (0 until items.itemCount).map { items.getItemAt(it).uri }
                } ?: listOfNotNull(data.data)
                val files = uris.map { copyMedia(it, requestCode == AUDIO).path }
                if (requestCode == AUDIO) files.firstOrNull() else files
            }
        }
    }

    private fun mediaFile(extension: String): File =
        File(File(filesDir, "media").apply { mkdirs() }, "${UUID.randomUUID()}.$extension")

    private fun copyMedia(uri: Uri, audio: Boolean): File {
        val name = contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { if (it.moveToFirst()) it.getString(0) else null }
        val suffix = name?.substringAfterLast('.', "")?.takeIf { it.matches(Regex("[a-zA-Z0-9]{1,8}")) }
        val file = mediaFile(suffix ?: if (audio) "audio" else "jpg")
        try {
            val input = contentResolver.openInputStream(uri) ?: error("Cannot open selected media")
            input.use { source -> file.outputStream().use { source.copyTo(it) } }
            return file
        } catch (error: Exception) {
            file.delete()
            throw error
        }
    }

    private fun soundtrack(value: Any?): File = when (value) {
        is String -> File(value).takeIf { it.isFile } ?: AudioSamples.file(cacheDir, value.hashCode() and 7, .6)
        is Int -> AudioSamples.file(cacheDir, value, .6)
        else -> error("Audio unavailable")
    }

    private fun play(path: File, volume: Float) {
        player?.release()
        player = MediaPlayer().apply {
            setDataSource(path.path)
            setVolume(volume, volume)
            isLooping = true
            setOnPreparedListener { it.start() }
            prepareAsync()
        }
    }

    private fun stopAudio() {
        audioRequest++
        player?.release()
        player = null
    }

    private fun publish(file: File) {
        if (Build.VERSION.SDK_INT < 29) {
            val directory = getExternalFilesDir(android.os.Environment.DIRECTORY_MOVIES) ?: filesDir
            file.copyTo(File(directory, "Slideshow-${System.currentTimeMillis()}.mp4"))
            return
        }
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, "Slideshow-${System.currentTimeMillis()}.mp4")
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/Slideshow")
            put(MediaStore.Video.Media.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
            ?: error("Cannot create a video in Movies")
        try {
            val output = contentResolver.openOutputStream(uri) ?: error("Cannot open video output")
            output.use { target -> file.inputStream().use { it.copyTo(target) } }
            values.clear()
            values.put(MediaStore.Video.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
        } catch (error: Exception) {
            contentResolver.delete(uri, null, null)
            throw error
        }
    }

    override fun onStop() {
        stopAudio()
        super.onStop()
    }

    override fun onDestroy() {
        stopAudio()
        worker.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val PHOTOS = 701
        private const val AUDIO = 702
        private const val CAMERA = 703
    }
}
