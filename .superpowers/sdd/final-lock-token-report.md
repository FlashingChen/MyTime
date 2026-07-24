# Final WebDAV Lock Token Review

## Scope

Correct the `UNLOCK` `Lock-Token` header serialization while preserving the
canonical stored token and the existing `PUT` `If` condition syntax.

## Red Evidence

Updated `test/data/sync/webdav_sync_adapter_test.dart` before production code:

- `formats a legacy lock token for PUT and UNLOCK`
- `formats a bracketed lock token for PUT and UNLOCK`

Command:

```text
flutter test test/data/sync/webdav_sync_adapter_test.dart
```

Result: failed as expected. Both tests expected
`<opaquelocktoken:token>` for `UNLOCK` `Lock-Token`, but the adapter emitted
the bare `opaquelocktoken:token`. The same runs retained the required `PUT`
assertion `(<opaquelocktoken:token>)`.

## Green Evidence

Production change: `WebDavSyncAdapter.unlock` now serializes the canonical
token as `<${lock.token}>` in the `Lock-Token` header.

Command:

```text
flutter test test/data/sync/webdav_sync_adapter_test.dart
```

Result: all 13 adapter tests passed, including both legacy and bracketed LOCK
response variants. Their `PUT` `If` assertions remain
`(<opaquelocktoken:token>)`.

Static analysis also completed successfully:

```text
flutter analyze
No issues found!
```
