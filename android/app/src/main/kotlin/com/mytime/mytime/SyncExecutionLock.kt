package com.mytime.mytime

import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicBoolean

/** Coordinates foreground and WorkManager access to process-local sync storage. */
object SyncExecutionLock {
    private val semaphore = Semaphore(1, true)
    private val foregroundActivities = AtomicInteger(0)
    private val acquired = AtomicBoolean(false)

    fun attachForeground() {
        foregroundActivities.incrementAndGet()
    }

    fun detachForeground() {
        foregroundActivities.updateAndGet { count -> (count - 1).coerceAtLeast(0) }
    }

    fun isForegroundAttached(): Boolean = foregroundActivities.get() > 0

    fun tryAcquire(timeoutMillis: Long): Boolean {
        try {
            val obtained = if (timeoutMillis <= 0) {
                semaphore.tryAcquire()
            } else {
                semaphore.tryAcquire(timeoutMillis, TimeUnit.MILLISECONDS)
            }
            if (obtained) acquired.set(true)
            return obtained
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            return false
        }
    }

    fun release() {
        if (acquired.compareAndSet(true, false)) semaphore.release()
    }
}
