package com.ndiwebcam

import android.util.Log

/**
 * Kotlin wrapper around the native NDI send API exposed via ndi_jni.cpp.
 * All JNI calls are made from the caller's thread — the JNI layer is thread-safe.
 */
class NDIStreamer {

    var isStreaming = false
        private set

    // MARK: Lifecycle

    fun start(sourceName: String): Boolean {
        val ok = nativeInit(sourceName)
        isStreaming = ok
        if (!ok) Log.e(TAG, "NDI init failed")
        return ok
    }

    fun stop() {
        if (isStreaming) {
            nativeDestroy()
            isStreaming = false
        }
    }

    // MARK: Video
    // data: UYVY byte array (width * height * 2)
    fun sendVideoFrame(data: ByteArray, width: Int, height: Int, fpsNumerator: Int = 30000, fpsDenominator: Int = 1000) {
        if (!isStreaming) return
        nativeSendVideoFrame(data, width, height, fpsNumerator, fpsDenominator)
    }

    // MARK: Audio
    // data: float32 planar PCM (channel_stride = noSamples floats per channel)
    fun sendAudioFrame(data: FloatArray, sampleRate: Int, channels: Int, noSamples: Int) {
        if (!isStreaming) return
        nativeSendAudioFrame(data, sampleRate, channels, noSamples)
    }

    // MARK: Status
    val connectedReceiverCount: Int
        get() = if (isStreaming) nativeGetReceiverCount() else 0

    // MARK: JNI

    private external fun nativeInit(sourceName: String): Boolean
    private external fun nativeSendVideoFrame(data: ByteArray, width: Int, height: Int, fpsN: Int, fpsD: Int): Boolean
    private external fun nativeSendAudioFrame(data: FloatArray, sampleRate: Int, channels: Int, noSamples: Int): Boolean
    private external fun nativeGetReceiverCount(): Int
    private external fun nativeDestroy()

    companion object {
        private const val TAG = "NDIStreamer"

        init {
            // Loads libndi.so (the Vizrt NDI library) then our JNI bridge.
            System.loadLibrary("ndi")
            System.loadLibrary("ndiwebcam")
        }
    }
}
