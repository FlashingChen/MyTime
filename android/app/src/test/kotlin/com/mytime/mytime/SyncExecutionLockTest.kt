package com.mytime.mytime

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.work.ListenableWorker.Result
import com.google.common.util.concurrent.ListenableFuture
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
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
        val firstToken = requireNotNull(SyncExecutionLock.acquire(0))
        val attempted = CountDownLatch(1)
        val acquired = CountDownLatch(1)
        val worker = Thread {
            attempted.countDown()
            val token = SyncExecutionLock.acquire(500)
            if (token != null) {
                acquired.countDown()
                SyncExecutionLock.release(token)
            }
        }
        worker.start()

        assertTrue(attempted.await(1, TimeUnit.SECONDS))
        assertFalse(acquired.await(50, TimeUnit.MILLISECONDS))
        assertTrue(SyncExecutionLock.release(firstToken))

        assertTrue(acquired.await(1, TimeUnit.SECONDS))
        worker.join(1000)
    }

    @Test
    fun interruptedAcquisitionDoesNotClaimTheLock() {
        val token = requireNotNull(SyncExecutionLock.acquire(0))
        val completed = CountDownLatch(1)
        var acquired: String? = "unexpected"
        val worker = Thread {
            acquired = SyncExecutionLock.acquire(1000)
            completed.countDown()
        }
        worker.start()
        Thread.sleep(20)
        worker.interrupt()

        assertTrue(completed.await(1, TimeUnit.SECONDS))
        assertNull(acquired)
        assertTrue(SyncExecutionLock.release(token))
    }

    @Test
    fun staleTokenCannotReleaseTheCurrentHolder() {
        val firstToken = requireNotNull(SyncExecutionLock.acquire(0))

        assertFalse(SyncExecutionLock.release("not-the-holder"))
        assertTrue(SyncExecutionLock.release(firstToken))

        val secondToken = requireNotNull(SyncExecutionLock.acquire(0))
        assertFalse(SyncExecutionLock.release(firstToken))
        assertNull(SyncExecutionLock.acquire(0))
        assertTrue(SyncExecutionLock.release(secondToken))
    }

    @Test
    fun workerWrapperRecognizesOnlyBackgroundWorkerClass() {
        assertTrue(MyTimeWorkerFactory.handles("dev.fluttercommunity.workmanager.BackgroundWorker"))
        assertFalse(MyTimeWorkerFactory.handles("unrelated.Worker"))
    }

    @Test
    fun workerWrapperRetriesWithoutDelegateWhenForegroundIsActive() {
        val harness = WorkerHarness(foregroundAttached = true)

        assertEquals(Result.retry(), harness.runner.start().get())
        assertEquals(0, harness.delegateStarts)
    }

    @Test
    fun workerWrapperRetriesWithoutDelegateWhenAcquisitionTimesOut() {
        val harness = WorkerHarness(acquireResult = null)

        assertEquals(Result.retry(), harness.runner.start().get())
        assertEquals(0, harness.delegateStarts)
    }

    @Test
    fun workerWrapperReleasesTokenWhenDelegateCompletes() {
        val harness = WorkerHarness()

        assertEquals(Result.success(), harness.runner.start().get())
        assertEquals(listOf("worker-token"), harness.releasedTokens)
    }

    @Test
    fun workerWrapperReleasesWithoutDelegateWhenStoppedDuringAcquisition() {
        val acquired = CountDownLatch(1)
        val allowAcquire = CountDownLatch(1)
        val harness = WorkerHarness(acquire = {
            acquired.countDown()
            allowAcquire.await(1, TimeUnit.SECONDS)
            "worker-token"
        })
        var result: Result? = null
        val thread = Thread { result = harness.runner.start().get() }
        thread.start()

        assertTrue(acquired.await(1, TimeUnit.SECONDS))
        harness.runner.stop()
        allowAcquire.countDown()
        thread.join(1000)

        assertEquals(Result.retry(), requireNotNull(result))
        assertEquals(0, harness.delegateStarts)
        assertEquals(listOf("worker-token"), harness.releasedTokens)
    }

    @Test
    fun workerWrapperStopsDelegateBeforeReleasingWhenStoppedDuringDelegateConstruction() {
        val delegateAdmission = CountDownLatch(1)
        val allowConstruction = CountDownLatch(1)
        val releasedTokens = mutableListOf<String>()
        var delegateConstructions = 0
        val events = mutableListOf<String>()
        val runner = SyncExecutionLockWorkRunner(
            acquire = { "worker-token" },
            release = { token -> releasedTokens.add(token); events.add("released"); true },
            isForegroundAttached = { false },
            startDelegate = {
                delegateAdmission.countDown()
                assertTrue(allowConstruction.await(1, TimeUnit.SECONDS))
                delegateConstructions++
                events.add("started")
                completed(Result.success())
            },
            stopDelegate = { events.add("stopped") },
        )
        val startThread = Thread { runner.start().get() }
        startThread.start()

        assertTrue(delegateAdmission.await(1, TimeUnit.SECONDS))
        val stopThread = Thread(runner::stop)
        stopThread.start()
        assertTrue(waitForStopRequest(runner))
        allowConstruction.countDown()
        startThread.join(1000)
        stopThread.join(1000)

        assertEquals(1, delegateConstructions)
        assertEquals(listOf("started", "stopped", "released"), events)
        assertEquals(listOf("worker-token"), releasedTokens)
    }

    private class WorkerHarness(
        private var foregroundAttached: Boolean = false,
        private val acquireResult: String? = "worker-token",
        private val acquire: (() -> String?)? = null,
    ) {
        var delegateStarts = 0
        val releasedTokens = mutableListOf<String>()
        val runner = SyncExecutionLockWorkRunner(
            acquire = { acquire?.invoke() ?: acquireResult },
            release = { token -> releasedTokens.add(token); true },
            isForegroundAttached = { foregroundAttached },
            startDelegate = {
                delegateStarts++
                completed(Result.success())
            },
            stopDelegate = {},
        )
    }

    private companion object {
        fun waitForStopRequest(runner: SyncExecutionLockWorkRunner): Boolean {
            val stoppedField = SyncExecutionLockWorkRunner::class.java.getDeclaredField("stopped")
            stoppedField.isAccessible = true
            val stopped = stoppedField.get(runner) as AtomicBoolean
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(1)
            while (!stopped.get() && System.nanoTime() < deadline) {
                Thread.yield()
            }
            return stopped.get()
        }

        fun completed(result: Result): ListenableFuture<Result> =
            CallbackToFutureAdapter.getFuture { completer ->
                completer.set(result)
                null
            }
    }
}
