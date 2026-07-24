# WebDAV Lock-Token Normalization Report

## Red

Added `normalizes a bracketed lock token for PUT and unlock` to
`test/data/sync/webdav_sync_adapter_test.dart`. The test supplies the standard
`lock-token: <opaquelocktoken:token>` LOCK response and requires canonical
headers:

- `If: (<opaquelocktoken:token>)` for PUT
- `Lock-Token: opaquelocktoken:token` for UNLOCK

Before the implementation, the focused test failed with:

```text
Expected: '(<opaquelocktoken:token>)'
Actual: '(<<opaquelocktoken:token>>)'
```

## Green

`WebDavSyncAdapter.lock()` now removes one enclosing angle-bracket pair from a
successful LOCK response before storing and returning the token. Unbracketed
responses retain their existing value, so the existing unbracketed-token test
continues to assert the same PUT and UNLOCK headers.

Verification completed:

```text
flutter test test/data/sync/webdav_sync_adapter_test.dart
00:00 +13: All tests passed!

flutter analyze
No issues found!
```
