package com.ndiwebcam

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.isActive

class NDIAudioManager(private val context: Context) {

    data class AudioDevice(val id: Int, val name: String, val type: Int)

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var audioRecord: AudioRecord? = null
    private var captureJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.IO)

    val availableInputDevices: List<AudioDevice>
        get() = audioManager
            .getDevices(AudioManager.GET_DEVICES_INPUTS)
            .map { AudioDevice(it.id, deviceTypeName(it.type), it.type) }
            .distinctBy { it.type }

    var selectedDeviceId: Int = AudioDeviceInfo.TYPE_BUILTIN_MIC

    fun startCapture(ndiStreamer: NDIStreamer) {
        val sampleRate  = 48_000
        val channels    = AudioFormat.CHANNEL_IN_STEREO
        val encoding    = AudioFormat.ENCODING_PCM_FLOAT
        val bufferSize  = AudioRecord.getMinBufferSize(sampleRate, channels, encoding)
            .coerceAtLeast(4096)

        val record = AudioRecord.Builder()
            .setAudioSource(MediaRecorder.AudioSource.MIC)
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setChannelMask(channels)
                    .setEncoding(encoding)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize)
            .build()

        // Route to the preferred device if selected.
        audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
            .firstOrNull { it.id == selectedDeviceId }
            ?.let { record.preferredDevice = it }

        record.startRecording()
        audioRecord = record

        captureJob = scope.launch {
            val noChannels  = 2
            val samplesPerChannel = bufferSize / (noChannels * 4) // 4 bytes per float
            val buf = FloatArray(samplesPerChannel * noChannels)

            while (isActive) {
                val read = record.read(buf, 0, buf.size, AudioRecord.READ_BLOCKING)
                if (read > 0) {
                    // Deinterleave LRLRLR → LL..RR.. for NDI FLTP format.
                    val planar = deinterleave(buf, read, noChannels)
                    ndiStreamer.sendAudioFrame(planar, sampleRate, noChannels, read / noChannels)
                }
            }
        }
    }

    fun stopCapture() {
        captureJob?.cancel()
        captureJob = null
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
    }

    private fun deinterleave(interleaved: FloatArray, totalSamples: Int, channels: Int): FloatArray {
        val samplesPerChannel = totalSamples / channels
        val out = FloatArray(totalSamples)
        for (ch in 0 until channels) {
            for (i in 0 until samplesPerChannel) {
                out[ch * samplesPerChannel + i] = interleaved[i * channels + ch]
            }
        }
        return out
    }

    private fun deviceTypeName(type: Int): String = when (type) {
        AudioDeviceInfo.TYPE_BUILTIN_MIC       -> "Built-in Microphone"
        AudioDeviceInfo.TYPE_WIRED_HEADSET     -> "Wired Headset"
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO     -> "Bluetooth (SCO)"
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP    -> "Bluetooth (A2DP)"
        AudioDeviceInfo.TYPE_USB_DEVICE        -> "USB Microphone"
        AudioDeviceInfo.TYPE_USB_HEADSET       -> "USB Headset"
        else -> "Audio Device ($type)"
    }

    companion object {
        private const val TAG = "NDIAudioManager"
    }
}
