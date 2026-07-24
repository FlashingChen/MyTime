package com.mytime.mytime

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        SyncExecutionLock.attachForeground()
        super.onCreate(savedInstanceState)
    }

    override fun onDestroy() {
        SyncExecutionLock.detachForeground()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    val timeoutMillis = call.argument<Number>("timeoutMillis")?.toLong()
                    if (timeoutMillis != null && timeoutMillis < 0) {
                        result.error("invalid_timeout", "timeoutMillis must be a non-negative integer", null)
                    } else {
                        executor.execute {
                            try {
                                result.success(SyncExecutionLock.acquire(timeoutMillis))
                            } catch (error: Throwable) {
                                result.error("acquire_failed", error.message, null)
                            }
                        }
                    }
                }
                "release" -> {
                    try {
                        val token = call.argument<String>("token")
                        if (token == null) {
                            result.error("invalid_token", "token is required", null)
                        } else {
                            result.success(SyncExecutionLock.release(token))
                        }
                    } catch (error: Throwable) {
                        result.error("release_failed", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private companion object {
        const val channelName = "mytime/sync_execution_lock"
        val executor = Executors.newSingleThreadExecutor()
    }
}
