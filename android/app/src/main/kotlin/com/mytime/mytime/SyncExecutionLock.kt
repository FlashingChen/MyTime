package com.mytime.mytime

import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.UUID

/** Coordinates foreground and WorkManager access to process-local sync storage. */
object SyncExecutionLock {
    private val semaphore = Semaphore(1, true)
    private val foregroundActivities = AtomicInteger(0)
    private var holderToken: String? = null

    fun attachForeground() {
        foregroundActivities.incrementAndGet()
    }

    fun detachForeground() {
        foregroundActivities.updateAndGet { count -> (count - 1).coerceAtLeast(0) }
    }

    fun isForegroundAttached(): Boolean = foregroundActivities.get() > 0

    fun acquire(timeoutMillis: Long?): String? {
        try {
            val obtained = when {
                timeoutMillis == null -> {
                    semaphore.acquire()
                    true
                }
                timeoutMillis <= 0 -> semaphore.tryAcquire()
                else -> semaphore.tryAcquire(timeoutMillis, TimeUnit.MILLISECONDS)
            }
            if (!obtained) return null
            return UUID.randomUUID().toString().also { token ->
                synchronized(this) { holderToken = token }
            }
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            return null
        }
    }

    fun release(token: String): Boolean {
        synchronized(this) {
            if (holderToken != token) return false
            holderToken = null
        }
        semaphore.release()
        return true
    }
}
