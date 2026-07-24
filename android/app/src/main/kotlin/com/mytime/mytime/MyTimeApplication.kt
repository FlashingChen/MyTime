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
        stopDelegate = { delegate?.onStopped() },
    )

    override fun startWork(): ListenableFuture<Result> = runner.start()

    override fun onStopped() {
        runner.stop()
        super.onStopped()
    }
}

/** Owns worker admission so stop and foreground races cannot start Flutter. */
internal class SyncExecutionLockWorkRunner(
    private val acquire: () -> String?,
    private val release: (String) -> Boolean,
    private val isForegroundAttached: () -> Boolean,
    private val startDelegate: () -> ListenableFuture<ListenableWorker.Result>,
    private val stopDelegate: () -> Unit,
) {
    private val stateLock = java.lang.Object()
    private val stopped = AtomicBoolean(false)
    private var token: String? = null
    private var startingDelegate = false
    private var delegateStarted = false
    private var stoppingDelegate = false
    private var delegateHandoffThread: Thread? = null
    private var delegateStopped = false
    private var released = false

    fun start(): ListenableFuture<ListenableWorker.Result> {
        if (isForegroundAttached()) return completed(ListenableWorker.Result.retry())
        val acquiredToken = acquire() ?: return completed(ListenableWorker.Result.retry())

        return try {
            val shouldStart = synchronized(stateLock) {
                token = acquiredToken
                if (stopped.get() || isForegroundAttached()) {
                    false
                } else {
                    startingDelegate = true
                    true
                }
            }
            if (!shouldStart) {
                releaseOnce()
                return completed(ListenableWorker.Result.retry())
            }
            val future = runDelegateHandoff(startDelegate)
            val shouldStop = synchronized(stateLock) {
                startingDelegate = false
                delegateStarted = true
                stateLock.notifyAll()
                if (stopped.get() && !delegateStopped && !stoppingDelegate) {
                    stoppingDelegate = true
                    true
                } else {
                    false
                }
            }
            if (shouldStop) stopAndRelease()
            future.addListener(::releaseOnce, MoreExecutors.directExecutor())
            future
        } catch (error: Throwable) {
            val shouldStop = synchronized(stateLock) {
                startingDelegate = false
                stateLock.notifyAll()
                if (stopped.get() && !delegateStopped && !stoppingDelegate) {
                    stoppingDelegate = true
                    true
                } else {
                    false
                }
            }
            if (shouldStop) stopAndRelease() else releaseOnce()
            throw error
        }
    }

    fun stop() {
        val shouldStop = synchronized(stateLock) {
            stopped.set(true)
            if (
                delegateHandoffThread === Thread.currentThread() &&
                    (startingDelegate || stoppingDelegate)
            ) {
                return
            }
            while (startingDelegate || stoppingDelegate) stateLock.wait()
            if (delegateStarted && !delegateStopped) {
                stoppingDelegate = true
                true
            } else {
                false
            }
        }
        if (shouldStop) stopAndRelease() else releaseOnce()
    }

    private fun releaseOnce() {
        val acquiredToken = synchronized(stateLock) {
            if (
                released ||
                    (stopped.get() && delegateStarted && !delegateStopped)
            ) {
                null
            } else {
                token?.also { released = true }
            }
        }
        if (acquiredToken != null) {
            release(acquiredToken)
        }
    }

    private fun stopAndRelease() {
        try {
            runDelegateHandoff(stopDelegate)
        } finally {
            synchronized(stateLock) {
                stoppingDelegate = false
                delegateStopped = true
                stateLock.notifyAll()
            }
            releaseOnce()
        }
    }

    private fun <T> runDelegateHandoff(delegate: () -> T): T {
        synchronized(stateLock) {
            delegateHandoffThread = Thread.currentThread()
        }
        return try {
            delegate()
        } finally {
            synchronized(stateLock) {
                if (delegateHandoffThread === Thread.currentThread()) {
                    delegateHandoffThread = null
                }
            }
        }
    }

    private fun completed(result: ListenableWorker.Result): ListenableFuture<ListenableWorker.Result> =
        CallbackToFutureAdapter.getFuture { completer ->
            completer.set(result)
            null
        }
}
