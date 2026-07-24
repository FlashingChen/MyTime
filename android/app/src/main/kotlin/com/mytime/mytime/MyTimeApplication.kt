package com.mytime.mytime

import android.app.Application
import android.content.Context
import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.work.Configuration
import androidx.work.ListenableWorker
import androidx.work.WorkerFactory
import androidx.work.WorkerParameters
import com.google.common.util.concurrent.ListenableFuture
import com.google.common.util.concurrent.MoreExecutors
import dev.fluttercommunity.workmanager.BackgroundWorker
import java.util.concurrent.atomic.AtomicBoolean

/** Installs the WorkerFactory that owns sync admission before Flutter starts. */
class MyTimeApplication : Application(), Configuration.Provider {
    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(MyTimeWorkerFactory())
            .build()
}

/** Wraps only workmanager's worker and leaves all unrelated workers to WorkManager. */
class MyTimeWorkerFactory : WorkerFactory() {
    override fun createWorker(
        appContext: Context,
        workerClassName: String,
        workerParameters: WorkerParameters,
    ): ListenableWorker? =
        if (workerClassName == BackgroundWorker::class.java.name) {
            SyncExecutionLockWorker(appContext, workerParameters)
        } else {
            null
        }
}

/** Acquires process ownership before constructing the plugin's headless worker. */
class SyncExecutionLockWorker(
    appContext: Context,
    private val workerParameters: WorkerParameters,
) : ListenableWorker(appContext, workerParameters) {
    private val released = AtomicBoolean(false)
    private var acquired = false
    private var delegate: BackgroundWorker? = null

    override fun startWork(): ListenableFuture<Result> {
        if (SyncExecutionLock.isForegroundAttached()) return completed(Result.retry())
        if (!SyncExecutionLock.tryAcquire(30_000)) return completed(Result.retry())

        acquired = true
        return try {
            val future = BackgroundWorker(applicationContext, workerParameters).also {
                delegate = it
            }.startWork()
            future.addListener(::releaseOnce, MoreExecutors.directExecutor())
            future
        } catch (error: Throwable) {
            releaseOnce()
            throw error
        }
    }

    override fun onStopped() {
        try {
            delegate?.onStopped()
        } finally {
            releaseOnce()
            super.onStopped()
        }
    }

    private fun releaseOnce() {
        if (acquired && released.compareAndSet(false, true)) {
            SyncExecutionLock.release()
        }
    }

    private fun completed(result: Result): ListenableFuture<Result> =
        CallbackToFutureAdapter.getFuture { completer ->
            completer.set(result)
            null
        }
}
