# WebDAV LOCK Fallback Report

## Change

`WebDavSyncAdapter.lock()` treats LOCK as optional only when the server does not
support the method: HTTP 405 Method Not Allowed or HTTP 501 Not Implemented.
HTTP 423 Locked represents lock contention and continues to throw the normal
`HttpException`; synchronization therefore cannot downgrade to an ETag-only PUT.

## Test-First Evidence

Replaced the erroneous 423 fallback test with adapter regression coverage that
returns 423 for LOCK, expects `HttpException`, and asserts that no PUT request
occurs. Before the production change, the focused test failed with:

```
Expected: throws HttpException with message `WebDAV LOCK failed: 423`
Actual: emitted <null>
```

After removing only the 423 fallback, the test passes: `lock()` throws
`HttpException: WebDAV LOCK failed: 423` and PUT count remains zero.

## Verification

| Command | Result |
| --- | --- |
| `flutter test test/data/sync/webdav_sync_adapter_test.dart` (red) | Failed as expected: LOCK 423 emitted `null` |
| `flutter test test/data/sync/webdav_sync_adapter_test.dart` (green) | Passed: 12 tests |
| `flutter analyze` | Passed: no issues found |

## Scope

Only the WebDAV adapter, its focused regression test, and this report are part
of this change. Existing unrelated iOS worktree changes were not modified or
included.
