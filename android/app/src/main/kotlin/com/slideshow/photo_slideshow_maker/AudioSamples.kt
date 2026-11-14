package com.slideshow.photo_slideshow_maker

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.sin

object AudioSamples {
    private const val RATE = 44100

    fun file(directory: File, variant: Int, volume: Double): File {
        val level = (volume * 20).toInt().coerceIn(0, 20)
        val target = File(directory, "slideshow-audio-$variant-$level.m4a")
        if (target.isFile) return target
        val temporary = File.createTempFile("audio-", ".m4a", directory)
        val notes = doubleArrayOf(261.63, 329.63, 392.00, 440.00, 523.25, 440.00, 392.00, 329.63)
        val codec = MediaCodec.createEncoderByType("audio/mp4a-latm")
        val muxer = MediaMuxer(temporary.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var track = -1
        var started = false
        try {
            codec.configure(MediaFormat.createAudioFormat("audio/mp4a-latm", RATE, 1).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, 64_000)
            }, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
            var index = 0
            var inputDone = false
            var outputDone = false
            val info = MediaCodec.BufferInfo()
            val beat = RATE / 2
            while (!outputDone) {
                if (!inputDone) {
                    val input = codec.dequeueInputBuffer(10_000)
                    if (input >= 0) {
                        val buffer = codec.getInputBuffer(input)!!.order(ByteOrder.LITTLE_ENDIAN)
                        buffer.clear()
                        val count = minOf(buffer.remaining() / 2, beat * notes.size - index)
                        for (i in 0 until count) {
                            val note = notes[((index + i) / beat + variant) % notes.size]
                            val time = ((index + i) % beat).toDouble() / RATE
                            val envelope = minOf(time * 85, 1.0) * exp(-time * 7)
                            val wave = sin(2 * PI * note * time) + .2 * sin(4 * PI * note * time)
                            buffer.putShort((wave * envelope * level * 350).toInt().toShort())
                        }
                        inputDone = count == 0
                        codec.queueInputBuffer(input, 0, count * 2, index * 1_000_000L / RATE,
                            if (inputDone) MediaCodec.BUFFER_FLAG_END_OF_STREAM else 0)
                        index += count
                    }
                }
                when (val output = codec.dequeueOutputBuffer(info, 10_000)) {
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        track = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                        started = true
                    }
                    else -> if (output >= 0) {
                        val buffer = codec.getOutputBuffer(output)!!
                        if (info.size > 0 && info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                            buffer.position(info.offset)
                            buffer.limit(info.offset + info.size)
                            muxer.writeSampleData(track, buffer, info)
                        }
                        outputDone = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                        codec.releaseOutputBuffer(output, false)
                    }
                }
            }
            muxer.stop()
            started = false
            check(temporary.renameTo(target)) { "Cannot save preview audio" }
            return target
        } finally {
            runCatching { codec.stop() }
            codec.release()
            if (started) runCatching { muxer.stop() }
            muxer.release()
            temporary.delete()
        }
    }
}
