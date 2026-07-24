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
        if (handles(workerClassName)) {
            SyncExecutionLockWorker(appContext, workerParameters)
        } else {
            null
        }

    companion object {
        internal fun handles(workerClassName: String): Boolean =
            workerClassName == BackgroundWorker::class.java.name
    }
}

/** Acquires process ownership before constructing the plugin's headless worker. */
class SyncExecutionLockWorker(
    appContext: Context,
    private val workerParameters: WorkerParameters,
) : ListenableWorker(appContext, workerParameters) {
    private var delegate: BackgroundWorker? = null
    private val runner = SyncExecutionLockWorkRunner(
        acquire = { SyncExecutionLock.acquire(30_000) },
        release = SyncExecutionLock::release,
        isForegroundAttached = SyncExecutionLock::isForegroundAttached,
        startDelegate = {
            BackgroundWorker(applicationContext, workerParameters).also { delegate = it }.startWork()
        },
    )

    override fun startWork(): ListenableFuture<Result> = runner.start()

    override fun onStopped() {
        runner.stop()
        try {
            delegate?.onStopped()
        } finally {
            super.onStopped()
        }
    }
}

/** Owns worker admission so stop and foreground races cannot start Flutter. */
internal class SyncExecutionLockWorkRunner(
    private val acquire: () -> String?,
    private val release: (String) -> Boolean,
    private val isForegroundAttached: () -> Boolean,
    private val startDelegate: () -> ListenableFuture<ListenableWorker.Result>,
) {
    private val stateLock = Any()
    private val stopped = AtomicBoolean(false)
    private val released = AtomicBoolean(false)
    private var token: String? = null

    fun start(): ListenableFuture<ListenableWorker.Result> {
        if (isForegroundAttached()) return completed(ListenableWorker.Result.retry())
        val acquiredToken = acquire() ?: return completed(ListenableWorker.Result.retry())

        return try {
            val future = synchronized(stateLock) {
                token = acquiredToken
                if (stopped.get() || isForegroundAttached()) null else startDelegate()
            }
            if (future == null) {
                releaseOnce()
                return completed(ListenableWorker.Result.retry())
            }
            future.addListener(::releaseOnce, MoreExecutors.directExecutor())
            future
        } catch (error: Throwable) {
            releaseOnce()
            throw error
        }
    }

    fun stop() {
        stopped.set(true)
        releaseOnce()
    }

    private fun releaseOnce() {
        val acquiredToken = synchronized(stateLock) { token }
        if (acquiredToken != null && released.compareAndSet(false, true)) {
            release(acquiredToken)
        }
    }

    private fun completed(result: ListenableWorker.Result): ListenableFuture<ListenableWorker.Result> =
        CallbackToFutureAdapter.getFuture { completer ->
            completer.set(result)
            null
        }
}
