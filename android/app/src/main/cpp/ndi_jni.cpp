#include <jni.h>
#include <android/log.h>
#include <string>
#include <cstring>

// NDI SDK header — placed in include/ alongside this file after SDK download.
// See CMakeLists.txt for include path configuration.
#include "Processing.NDI.Lib.h"

#define LOG_TAG "NDIWebcam"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static NDIlib_send_instance_t g_ndi_send = nullptr;

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_ndiwebcam_NDIStreamer_nativeInit(JNIEnv *env, jobject, jstring sourceName) {
    if (!NDIlib_initialize()) {
        LOGE("NDIlib_initialize failed");
        return JNI_FALSE;
    }

    const char *name = env->GetStringUTFChars(sourceName, nullptr);
    NDIlib_send_create_t settings{};
    settings.p_ndi_name  = name;
    settings.clock_video = false;
    settings.clock_audio = false;

    g_ndi_send = NDIlib_send_create(&settings);
    env->ReleaseStringUTFChars(sourceName, name);

    if (!g_ndi_send) {
        LOGE("NDIlib_send_create failed");
        NDIlib_destroy();
        return JNI_FALSE;
    }
    LOGI("NDI sender created");
    return JNI_TRUE;
}

// Sends a video frame.
// data:   UYVY byte array (width * height * 2 bytes)
// width, height: frame dimensions
// fpsN, fpsD: frame rate numerator/denominator (e.g. 30000/1000 = 30 fps)
JNIEXPORT jboolean JNICALL
Java_com_ndiwebcam_NDIStreamer_nativeSendVideoFrame(
    JNIEnv *env, jobject,
    jbyteArray data, jint width, jint height, jint fpsN, jint fpsD)
{
    if (!g_ndi_send) return JNI_FALSE;

    jbyte *pixels = env->GetByteArrayElements(data, nullptr);

    NDIlib_video_frame_v2_t frame{};
    frame.xres                  = width;
    frame.yres                  = height;
    frame.FourCC                = NDIlib_FourCC_type_UYVY;
    frame.frame_rate_N          = fpsN;
    frame.frame_rate_D          = fpsD;
    frame.picture_aspect_ratio  = static_cast<float>(width) / static_cast<float>(height);
    frame.frame_format_type     = NDIlib_frame_format_type_progressive;
    frame.timecode              = NDIlib_send_timecode_synthesize;
    frame.p_data                = reinterpret_cast<uint8_t *>(pixels);
    frame.line_stride_in_bytes  = width * 2; // UYVY: 2 bytes per pixel

    NDIlib_send_send_video_v2(g_ndi_send, &frame);

    env->ReleaseByteArrayElements(data, pixels, JNI_ABORT);
    return JNI_TRUE;
}

// Sends an audio frame.
// data:        float32 planar PCM (no_channels * no_samples * 4 bytes)
// sampleRate:  e.g. 48000
// channels:    1 or 2
// noSamples:   samples per channel in this buffer
JNIEXPORT jboolean JNICALL
Java_com_ndiwebcam_NDIStreamer_nativeSendAudioFrame(
    JNIEnv *env, jobject,
    jfloatArray data, jint sampleRate, jint channels, jint noSamples)
{
    if (!g_ndi_send) return JNI_FALSE;

    jfloat *samples = env->GetFloatArrayElements(data, nullptr);

    NDIlib_audio_frame_v3_t frame{};
    frame.sample_rate            = sampleRate;
    frame.no_channels            = channels;
    frame.no_samples             = noSamples;
    frame.timecode               = NDIlib_send_timecode_synthesize;
    frame.FourCC                 = NDIlib_FourCC_audio_type_FLTP;
    frame.p_data                 = samples;
    frame.channel_stride_in_bytes = noSamples * static_cast<int>(sizeof(float));

    NDIlib_send_send_audio_v3(g_ndi_send, &frame);

    env->ReleaseFloatArrayElements(data, samples, JNI_ABORT);
    return JNI_TRUE;
}

JNIEXPORT jint JNICALL
Java_com_ndiwebcam_NDIStreamer_nativeGetReceiverCount(JNIEnv *, jobject) {
    if (!g_ndi_send) return 0;
    return static_cast<jint>(NDIlib_send_get_no_connections(g_ndi_send, 0));
}

JNIEXPORT void JNICALL
Java_com_ndiwebcam_NDIStreamer_nativeDestroy(JNIEnv *, jobject) {
    if (g_ndi_send) {
        NDIlib_send_destroy(g_ndi_send);
        g_ndi_send = nullptr;
    }
    NDIlib_destroy();
    LOGI("NDI sender destroyed");
}

} // extern "C"
