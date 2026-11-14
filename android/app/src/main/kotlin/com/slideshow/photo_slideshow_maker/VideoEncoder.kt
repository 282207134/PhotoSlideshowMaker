package com.slideshow.photo_slideshow_maker

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteBuffer
import kotlin.math.max
import kotlin.math.min

object VideoEncoder {
    private const val FPS = 24
    private const val MIME = "video/avc"

    fun encode(folder: File, output: File, width: Int, height: Int, count: Int,
        transition: Int, intensity: Double, soundtrack: File?) {
        require(count > 0)
        val format = MediaFormat.createVideoFormat(MIME, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
            setInteger(MediaFormat.KEY_BIT_RATE, 1_500_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, FPS)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        val codec = MediaCodec.createEncoderByType(MIME)
        val muxer = MediaMuxer(output.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val audio = MediaExtractor()
        var videoTrack = -1
        var audioTrack = -1
        var started = false
        var completed = false
        try {
            if (soundtrack != null) {
                val audioFormat = runCatching {
                    audio.setDataSource(soundtrack.path)
                    (0 until audio.trackCount).firstNotNullOfOrNull { i ->
                        val track = audio.getTrackFormat(i)
                        val mime = track.getString(MediaFormat.KEY_MIME)
                        if (mime == "audio/mp4a-latm") { audio.selectTrack(i); track } else null
                    }
                }.getOrNull()
                if (audioFormat != null) audioTrack = muxer.addTrack(audioFormat)
            }
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
            val info = MediaCodec.BufferInfo()
            val framesPerSlide = FPS * 2
            val transitionFrames = (FPS * (0.2 + intensity * .55)).toInt()
            val totalFrames = count * framesPerSlide
            var queued = 0
            var inputDone = false
            var outputDone = false
            var slide = -1
            var previous: ByteArray? = null
            var current = ByteArray(0)
            val blend = ByteArray(width * height * 3 / 2)
            var lastProgress = System.nanoTime()
            while (!outputDone) {
                if (!inputDone) {
                    val input = codec.dequeueInputBuffer(10_000)
                    if (input >= 0) {
                        val time = queued * 1_000_000L / FPS
                        if (queued == totalFrames) {
                            codec.queueInputBuffer(input, 0, 0, time, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            val index = queued / framesPerSlide
                            if (index != slide) {
                                previous = current.takeIf { it.isNotEmpty() }
                                current = yuv(File(folder, "$index.rgba").readBytes(), width, height)
                                slide = index
                            }
                            val offset = queued % framesPerSlide
                            val prior = previous
                            val image = if (transition >= 0 && prior != null && offset < transitionFrames) {
                                mix(prior, current, blend, width, height, (offset + 1.0) / transitionFrames, transition % 2 == 1)
                                blend
                            } else current
                            val inputImage = codec.getInputImage(input) ?: error("Encoder cannot accept YUV frames")
                            inputImage.use {
                                val ySize = width * height
                                copyPlane(image, 0, it.planes[0], width, height)
                                copyPlane(image, ySize, it.planes[1], width / 2, height / 2)
                                copyPlane(image, ySize + ySize / 4, it.planes[2], width / 2, height / 2)
                            }
                            codec.queueInputBuffer(input, 0, image.size, time, 0)
                            queued++
                        }
                        lastProgress = System.nanoTime()
                    }
                }
                when (val index = codec.dequeueOutputBuffer(info, 10_000)) {
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        videoTrack = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                        started = true
                    }
                    MediaCodec.INFO_TRY_AGAIN_LATER -> {
                        check(System.nanoTime() - lastProgress < 20_000_000_000L) { "Video encoder timed out" }
                    }
                    else -> if (index >= 0) {
                        val buffer = codec.getOutputBuffer(index)!!
                        if (info.size > 0 && info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                            buffer.position(info.offset)
                            buffer.limit(info.offset + info.size)
                            muxer.writeSampleData(videoTrack, buffer, info)
                        }
                        outputDone = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                        codec.releaseOutputBuffer(index, false)
                        lastProgress = System.nanoTime()
                    }
                }
            }
            if (audioTrack >= 0) writeAudio(audio, muxer, audioTrack, count * 2_000_000L)
            muxer.stop()
            started = false
            completed = true
        } finally {
            runCatching { codec.stop() }
            codec.release()
            audio.release()
            if (started) runCatching { muxer.stop() }
            muxer.release()
            if (!completed) output.delete()
        }
    }

    private fun writeAudio(audio: MediaExtractor, muxer: MediaMuxer, track: Int, duration: Long) {
        val bytes = ByteBuffer.allocateDirect(256 * 1024)
        val info = MediaCodec.BufferInfo()
        var offset = 0L
        var last = -1L
        while (offset < duration) {
            bytes.clear()
            val size = audio.readSampleData(bytes, 0)
            if (size < 0) {
                if (last < offset) break
                offset = last + 23_220
                audio.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                continue
            }
            val time = max(last + 1, offset + audio.sampleTime)
            if (time >= duration) break
            info.set(0, size, time, 0)
            muxer.writeSampleData(track, bytes, info)
            last = time
            audio.advance()
        }
    }

    private fun copyPlane(src: ByteArray, offset: Int, plane: android.media.Image.Plane, width: Int, height: Int) {
        val buffer = plane.buffer
        for (y in 0 until height) {
            val row = y * plane.rowStride
            val input = offset + y * width
            if (plane.pixelStride == 1) {
                buffer.position(row)
                buffer.put(src, input, width)
            } else {
                for (x in 0 until width) buffer.put(row + x * plane.pixelStride, src[input + x])
            }
        }
    }

    private fun yuv(rgba: ByteArray, width: Int, height: Int): ByteArray {
        val size = width * height
        require(rgba.size == size * 4)
        val data = ByteArray(size * 3 / 2)
        var chroma = 0
        for (y in 0 until height) for (x in 0 until width) {
            val pixel = y * width + x
            val r = rgba[pixel * 4].toInt() and 255
            val g = rgba[pixel * 4 + 1].toInt() and 255
            val b = rgba[pixel * 4 + 2].toInt() and 255
            data[pixel] = (((66 * r + 129 * g + 25 * b + 128) shr 8) + 16).toByte()
            if (x % 2 == 0 && y % 2 == 0) {
                data[size + chroma] = (((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128).toByte()
                data[size + size / 4 + chroma] = (((112 * r - 94 * g - 18 * b + 128) shr 8) + 128).toByte()
                chroma++
            }
        }
        return data
    }

    private fun mix(a: ByteArray, b: ByteArray, out: ByteArray, width: Int, height: Int, fraction: Double, slide: Boolean) {
        if (!slide) {
            val amount = (fraction * 256).toInt()
            for (i in out.indices) out[i] = (((a[i].toInt() and 255) * (256 - amount) + (b[i].toInt() and 255) * amount) shr 8).toByte()
            return
        }
        val ySize = width * height
        for ((start, w, h) in listOf(Triple(0, width, height),
            Triple(ySize, width / 2, height / 2), Triple(ySize + ySize / 4, width / 2, height / 2))) {
            val cut = min(w, (w * (1 - fraction)).toInt())
            for (row in 0 until h) {
                val base = start + row * w
                a.copyInto(out, base, base + w - cut, base + w)
                b.copyInto(out, base + cut, base, base + w - cut)
            }
        }
    }
}
