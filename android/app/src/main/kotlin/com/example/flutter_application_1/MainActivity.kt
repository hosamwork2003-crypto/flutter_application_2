package com.example.flutter_application_1

import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    companion object {
        init {
            System.loadLibrary("native_piano")
        }

        private const val CHANNEL = "native_piano"
        private const val TAG = "NativePiano"
    }

    external fun nativeInit(sf2AssetPath: String): Boolean
    external fun nativeNoteOn(midi: Int, velocity: Int)
    external fun nativeNoteOnMany(midis: IntArray, velocity: Int)
    external fun nativeNoteOff(midi: Int)
    external fun nativeAllNotesOff()
    external fun nativeRelease()

    private var isInitialized = false
    private var cachedPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "init" -> {
                        try {
                            val sf2AssetPath = call.argument<String>("sf2AssetPath")
                            if (sf2AssetPath.isNullOrBlank()) {
                                result.error("INIT_ERROR", "sf2AssetPath is null or blank", null)
                                return@setMethodCallHandler
                            }

                            val file = copyAssetToFilesDir(sf2AssetPath)

                            if (isInitialized && cachedPath == file.absolutePath) {
                                Log.i(TAG, "Already initialized, skipping nativeInit")
                                result.success(true)
                                return@setMethodCallHandler
                            }

                            val ok = nativeInit(file.absolutePath)

                            if (ok) {
                                isInitialized = true
                                cachedPath = file.absolutePath
                            }

                            result.success(ok)
                        } catch (e: Exception) {
                            Log.e(TAG, "INIT_ERROR", e)
                            result.error("INIT_ERROR", e.message, null)
                        }
                    }

                    "noteOn" -> {
                        val midi = call.argument<Int>("midi")
                        val velocity = call.argument<Int>("velocity")

                        if (midi == null || velocity == null) {
                            result.error("NOTE_ON_ERROR", "Missing midi or velocity", null)
                        } else {
                            nativeNoteOn(midi, velocity)
                            result.success(null)
                        }
                    }

                    "noteOnMany" -> {
                        val midis = call.argument<List<Int>>("midis")
                        val velocity = call.argument<Int>("velocity")

                        if (midis == null || velocity == null) {
                            result.error("NOTE_ON_MANY_ERROR", "Missing midis or velocity", null)
                        } else {
                            nativeNoteOnMany(midis.toIntArray(), velocity)
                            result.success(null)
                        }
                    }

                    "noteOff" -> {
                        val midi = call.argument<Int>("midi")

                        if (midi == null) {
                            result.error("NOTE_OFF_ERROR", "Missing midi", null)
                        } else {
                            nativeNoteOff(midi)
                            result.success(null)
                        }
                    }

                    "allNotesOff" -> {
                        nativeAllNotesOff()
                        result.success(null)
                    }

                    "release" -> {
                        nativeRelease()
                        isInitialized = false
                        cachedPath = null
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun copyAssetToFilesDir(assetPath: String): File {
        val flutterAssetKey = FlutterInjector.instance()
            .flutterLoader()
            .getLookupKeyForAsset(assetPath)

        val outFile = File(filesDir, "SalC5Light2.sf2")

        if (outFile.exists() && outFile.length() > 0L) {
            Log.i(TAG, "SF2 already exists: ${outFile.absolutePath}")
            return outFile
        }

        outFile.parentFile?.mkdirs()

        assets.open(flutterAssetKey).use { input ->
            FileOutputStream(outFile).use { output ->
                input.copyTo(output)
                output.flush()
            }
        }

        Log.i(TAG, "Copied SF2 to: ${outFile.absolutePath}")
        return outFile
    }
}
