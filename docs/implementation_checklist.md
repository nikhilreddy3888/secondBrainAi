# Implementation Checklist

## Security and Storage

- [ ] Add `sqflite_sqlcipher` and implement encrypted DB bootstrap.
- [ ] Create `KeyManager` abstraction for KEK/DEK handling.
- [ ] Require biometric unlock before DB open.
- [ ] Add app-lock timeout and in-memory key wipe on pause/background.
- [ ] Migrate secure-storage JSON vault into SQLCipher tables.

## Data and Retrieval

- [ ] Add DB schema + migrations for notes/passwords/docs/events/audit_log.
- [ ] Add FTS5 virtual tables and triggers for searchable entities.
- [ ] Add vector index strategy (`sqlite-vec` preferred, fallback blobs).
- [ ] Implement chunking worker in isolate.
- [ ] Implement hybrid retrieval (keyword + semantic score fusion).

## AI and Agentic Runtime

- [ ] Add model tier selector by RAM/device profile.
- [ ] Add model lifecycle manager (load/unload/reload).
- [ ] Add tool declaration registry + JSON schema validator.
- [ ] Add tool loop executor with max call depth and timeout.
- [ ] Enforce secret-safe prompt builder (no raw password values).

## Ingestion

- [ ] Add OCR module (`google_mlkit_text_recognition`).
- [ ] Add entity extraction module (`google_mlkit_entity_extraction`).
- [ ] Add document import pipeline (camera/gallery/file picker).
- [ ] Add chunking + embedding enqueue after ingestion.

## Hardening

- [ ] Add screenshot protection for sensitive screens.
- [ ] Add clipboard auto-clear policy after secret copy.
- [ ] Add path validation allow-list for any file tools.
- [ ] Enable obfuscation and symbol split in release pipeline.
- [ ] Add Android keep rules for SQLCipher classes.

## Testing

- [ ] Add repository migration tests (JSON -> SQLCipher).
- [ ] Add retrieval correctness tests (FTS/vector/hybrid ranking).
- [ ] Add tool-call validation tests for malformed arguments.
- [ ] Add password reveal flow tests with biometric gate.
- [ ] Run thermal + latency benchmark suite on real devices.
