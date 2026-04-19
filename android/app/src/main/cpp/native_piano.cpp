#include <jni.h>
#include <string>
#include <memory>
#include <cstring>
#include <atomic>

#include "Oboe.h"

#define TSF_IMPLEMENTATION
#include "tsf.h"

#include <android/log.h>

#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "NativePiano", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "NativePiano", __VA_ARGS__)

static tsf* g_tsf = nullptr;

struct NoteEvent {
    enum Type : int {
        NoteOn = 1,
        NoteOff = 2,
        AllNotesOff = 3,
    };

    int type = 0;
    int midi = 0;
    int velocity = 127;
};

static constexpr int kEventQueueSize = 512;
static NoteEvent g_eventQueue[kEventQueueSize];
static std::atomic<int> g_writeIndex{0};
static std::atomic<int> g_readIndex{0};

static bool enqueueEvent(const NoteEvent& event) {
    const int write = g_writeIndex.load(std::memory_order_relaxed);
    const int next = (write + 1) % kEventQueueSize;
    const int read = g_readIndex.load(std::memory_order_acquire);

    if (next == read) {
        LOGE("Event queue full; dropping event type=%d midi=%d", event.type, event.midi);
        return false;
    }

    g_eventQueue[write] = event;
    g_writeIndex.store(next, std::memory_order_release);
    return true;
}

static bool dequeueEvent(NoteEvent& outEvent) {
    const int read = g_readIndex.load(std::memory_order_relaxed);
    const int write = g_writeIndex.load(std::memory_order_acquire);

    if (read == write) return false;

    outEvent = g_eventQueue[read];
    g_readIndex.store((read + 1) % kEventQueueSize, std::memory_order_release);
    return true;
}

class PianoEngine : public oboe::AudioStreamCallback {
public:
    bool init() {
        stop();

        oboe::AudioStreamBuilder builder;
        builder.setDirection(oboe::Direction::Output);
        builder.setPerformanceMode(oboe::PerformanceMode::LowLatency);
        builder.setSharingMode(oboe::SharingMode::Shared);
        builder.setUsage(oboe::Usage::Game);
        builder.setFormat(oboe::AudioFormat::Float);
        builder.setChannelCount(2);
        builder.setSampleRate(48000);
        builder.setCallback(this);

        auto result = builder.openStream(mStream);
        if (result != oboe::Result::OK || !mStream) {
            LOGE("openStream failed: %s", oboe::convertToText(result));
            return false;
        }

        result = mStream->requestStart();
        if (result != oboe::Result::OK) {
            LOGE("requestStart failed: %s", oboe::convertToText(result));
            mStream->close();
            mStream.reset();
            return false;
        }

        LOGI("stream started, sampleRate=%d, burst=%d",
             mStream->getSampleRate(),
             mStream->getFramesPerBurst());

        return true;
    }

    void stop() {
        if (mStream) {
            mStream->requestStop();
            mStream->close();
            mStream.reset();
        }
    }

    int32_t getSampleRate() const {
        return mStream ? mStream->getSampleRate() : 44100;
    }

    oboe::DataCallbackResult onAudioReady(
        oboe::AudioStream* /*audioStream*/,
        void* audioData,
        int32_t numFrames
    ) override {
        float* output = static_cast<float*>(audioData);
        std::memset(output, 0, sizeof(float) * numFrames * 2);

        if (g_tsf == nullptr) {
            return oboe::DataCallbackResult::Continue;
        }

        NoteEvent event;
        while (dequeueEvent(event)) {
            switch (event.type) {
                case NoteEvent::NoteOn: {
                    float vel = event.velocity / 127.0f;
                    if (vel < 0.05f) vel = 0.05f;
                    if (vel > 0.75f) vel = 0.75f;
                    tsf_note_on(g_tsf, 0, event.midi, vel);
                    break;
                }
                case NoteEvent::NoteOff:
                    tsf_note_off(g_tsf, 0, event.midi);
                    break;
                case NoteEvent::AllNotesOff:
                    tsf_note_off_all(g_tsf);
                    break;
                default:
                    break;
            }
        }

        tsf_render_float(g_tsf, output, numFrames, 0);
        return oboe::DataCallbackResult::Continue;
    }

private:
    std::shared_ptr<oboe::AudioStream> mStream;
};

static PianoEngine g_engine;

extern "C"
JNIEXPORT jboolean JNICALL
Java_com_example_flutter_1application_11_MainActivity_nativeInit(
        JNIEnv* env,
        jobject /*thiz*/,
        jstring sf2AssetPath) {

    if (g_tsf != nullptr) {
        tsf_close(g_tsf);
        g_tsf = nullptr;
    }

    g_writeIndex.store(0, std::memory_order_relaxed);
    g_readIndex.store(0, std::memory_order_relaxed);

    const char* pathChars = env->GetStringUTFChars(sf2AssetPath, nullptr);
    std::string path(pathChars ? pathChars : "");
    env->ReleaseStringUTFChars(sf2AssetPath, pathChars);

    g_tsf = tsf_load_filename(path.c_str());
    if (g_tsf == nullptr) {
        LOGE("tsf_load_filename failed");
        return JNI_FALSE;
    }

    if (!g_engine.init()) {
        tsf_close(g_tsf);
        g_tsf = nullptr;
        return JNI_FALSE;
    }

    const int sampleRate = g_engine.getSampleRate();

    tsf_set_output(g_tsf, TSF_STEREO_INTERLEAVED, sampleRate, -12.0f);
    tsf_set_max_voices(g_tsf, 96);

    LOGI("TSF ready. sampleRate=%d", sampleRate);
    return JNI_TRUE;
}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_flutter_1application_11_MainActivity_nativeNoteOn(
        JNIEnv* /*env*/,
        jobject /*thiz*/,
        jint midi,
        jint velocity) {
    enqueueEvent(NoteEvent{NoteEvent::NoteOn, midi, velocity});
}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_flutter_1application_11_MainActivity_nativeNoteOff(
        JNIEnv* /*env*/,
        jobject /*thiz*/,
        jint midi) {
    enqueueEvent(NoteEvent{NoteEvent::NoteOff, midi, 0});
}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_flutter_1application_11_MainActivity_nativeAllNotesOff(
        JNIEnv* /*env*/,
        jobject /*thiz*/) {
    enqueueEvent(NoteEvent{NoteEvent::AllNotesOff, 0, 0});
}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_flutter_1application_11_MainActivity_nativeRelease(
        JNIEnv* /*env*/,
        jobject /*thiz*/) {
    g_writeIndex.store(0, std::memory_order_relaxed);
    g_readIndex.store(0, std::memory_order_relaxed);

    if (g_tsf != nullptr) {
        tsf_note_off_all(g_tsf);
    }

    g_engine.stop();

    if (g_tsf != nullptr) {
        tsf_close(g_tsf);
        g_tsf = nullptr;
    }

    LOGI("nativeRelease completed");
}