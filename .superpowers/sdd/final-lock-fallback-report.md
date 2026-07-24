# WebDAV LOCK 423 Fallback Report

## Change

`WebDavSyncAdapter.lock()` now treats HTTP 423 Locked as an unavailable optional
WebDAV lock, returning `null` so synchronization continues with the existing
ETag-based conditional PUT.

## Test-First Evidence

Added adapter regression coverage for a LOCK response of 423 followed by a
successful conditional PUT. Before the production change, the focused test
failed with:

```
HttpException: WebDAV LOCK failed: 423
```

After adding the fallback, the regression verifies that `lock()` returns null,
PUT preserves `If-Match: "v1"`, and no lock `If` header is sent.

## Verification

| Command | Result |
| --- | --- |
| `flutter test test/data/sync/webdav_sync_adapter_test.dart` | Passed: 12 tests |
| `flutter analyze` | Passed: no issues found |

## Scope

Only the WebDAV adapter, its focused regression test, and this report are part
of this change. Existing unrelated iOS worktree changes were not modified or
included.
