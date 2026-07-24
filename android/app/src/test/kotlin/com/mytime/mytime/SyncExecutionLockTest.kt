package com.mytime.mytime

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SyncExecutionLockTest {
    @Test
    fun foregroundAttachmentTracksMultipleActivities() {
        SyncExecutionLock.attachForeground()
        SyncExecutionLock.attachForeground()

        assertTrue(SyncExecutionLock.isForegroundAttached())
        SyncExecutionLock.detachForeground()
        assertTrue(SyncExecutionLock.isForegroundAttached())
        SyncExecutionLock.detachForeground()
        assertFalse(SyncExecutionLock.isForegroundAttached())
    }

    @Test
    fun secondCallerWaitsUntilCurrentHolderReleases() {
        assertTrue(SyncExecutionLock.tryAcquire(0))
        val attempted = CountDownLatch(1)
        val acquired = CountDownLatch(1)
        val worker = Thread {
            attempted.countDown()
            if (SyncExecutionLock.tryAcquire(500)) {
                acquired.countDown()
                SyncExecutionLock.release()
            }
        }
        worker.start()

        assertTrue(attempted.await(1, TimeUnit.SECONDS))
        assertFalse(acquired.await(50, TimeUnit.MILLISECONDS))
        SyncExecutionLock.release()

        assertTrue(acquired.await(1, TimeUnit.SECONDS))
        worker.join(1000)
    }

    @Test
    fun interruptedAcquisitionDoesNotClaimTheLock() {
        assertTrue(SyncExecutionLock.tryAcquire(0))
        val completed = CountDownLatch(1)
        var acquired = true
        val worker = Thread {
            acquired = SyncExecutionLock.tryAcquire(1000)
            completed.countDown()
        }
        worker.start()
        Thread.sleep(20)
        worker.interrupt()

        assertTrue(completed.await(1, TimeUnit.SECONDS))
        assertFalse(acquired)
        SyncExecutionLock.release()
    }
}
