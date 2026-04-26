# Local-First Encrypted Second Brain Architecture

This document defines a production architecture for this Flutter app to evolve from secure local JSON storage to a hardened, fully local, encrypted second-brain ecosystem with on-device AI, RAG, and agentic tool execution.

## 1) Architecture Goals

- 100% local execution for storage, retrieval, and AI inference.
- Zero plaintext data at rest outside secure hardware-backed stores.
- No raw secrets (password bodies, private keys) in LLM prompts.
- Deterministic local tool execution with strict argument validation.
- Graceful hardware tiering for low/mid/high-end devices.

## 2) Current State (This Repository)

- App shell, routing, and Riverpod state are in place.
- On-device LLM integration exists with `runanywhere` + `runanywhere_llamacpp`.
- Current vault persistence uses `flutter_secure_storage` JSON blobs.
- Current retrieval is an in-memory BM25-like implementation.
- Assistant already supports local command parsing and AI fallback.

## 3) Target Runtime Topology

### 3.1 Security and Key Hierarchy

- `KEK` (Key Encryption Key): Hardware-backed key in Android Keystore/iOS Keychain.
- `DEK` (Data Encryption Key): Random 256-bit key encrypted by KEK.
- SQLCipher passphrase is derived from DEK + salt (PBKDF2).
- Database and vector index are encrypted in one local container.

### 3.2 Data Plane

- Primary store: SQLCipher (`sqflite_sqlcipher`) with normalized tables:
  - `notes`, `documents`, `events`, `passwords`, `attachments`
  - `audit_log` (event sourcing / version history)
- Full text: `FTS5` shadow tables for exact/keyword recall.
- Semantic search:
  - Preferred: `sqlite-vec` virtual tables inside SQLCipher DB.
  - Fallback: encrypted vector blobs + cosine ranking in isolate.

### 3.3 AI Plane

- Inference backend: RunAnywhere + LlamaCPP.
- Model tiers:
  - Low tier: ~0.5B-1B Q4 models.
  - Mid tier: ~1.5B-3B Q4 models.
  - High tier: ~3.8B+ with dynamic unload policies.
- Context limits for mobile thermal safety: 4k-8k tokens.
- All inference and embeddings run in background isolates/native threads.

### 3.4 Agentic Tool Plane

- Register explicit tools with JSON schema contracts.
- Validate all tool args before execution.
- Execute tools against encrypted DB using parameterized queries only.
- Tool results are appended to chat history and looped until completion.

## 4) Security Controls

- Biometric gate before unlocking DEK.
- App lock timeout with in-memory key wipe.
- No password plaintext in AI prompts or citation text.
- Clipboard auto-clear for copied secrets.
- Screenshot protection on sensitive screens (platform-specific).
- Path allow-list for any file-reading tools.

## 5) Data Model (Suggested)

```sql
-- Core entities
CREATE TABLE notes (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  file_name TEXT NOT NULL,
  path TEXT NOT NULL,
  content TEXT NOT NULL,
  added_at TEXT NOT NULL
);

CREATE TABLE events (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  starts_at TEXT NOT NULL,
  description TEXT NOT NULL
);

CREATE TABLE passwords (
  id TEXT PRIMARY KEY,
  account_name TEXT NOT NULL,
  username TEXT NOT NULL,
  encrypted_secret BLOB NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE audit_log (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  action TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL
);
```

## 6) RAG Pipeline

1. Ingestion: note/doc/OCR content is chunked with overlap.
2. Embedding generation: on-device model in isolate.
3. Storage: chunk text + metadata + vector.
4. Retrieval: hybrid ranking = FTS score + vector similarity.
5. Prompt build: inject only safe, filtered context.
6. Grounded answer: answer only from provided context.

## 7) Assistant Policy

- Password retrieval flow requires secondary biometric confirmation.
- LLM can see password metadata, never plaintext secrets.
- Any mutating action must be represented as a tool call and logged.

## 8) Phased Implementation Plan

### Phase A: Security Foundation

- Introduce SQLCipher-backed repository layer.
- Add key manager abstraction and biometric unlock flow.
- Migrate existing vault JSON into SQLCipher on first launch.

### Phase B: Retrieval Infrastructure

- Add FTS5 for notes/documents/events metadata.
- Add vector storage and similarity query abstraction.
- Move BM25 fallback to a compatibility path only.

### Phase C: Agentic Runtime

- Replace regex-only assistant writes with tool contracts.
- Add multi-step tool loop execution and history augmentation.
- Add strict tool input validation and audit logging.

### Phase D: Hardening and Performance

- Add model tier selection by device RAM.
- Add model unload/reload lifecycle handling.
- Benchmark thermal behavior and token throughput on target devices.

## 9) Code Ownership Map (Recommended)

- `lib/core/security/`: key management, biometrics, secret policies.
- `lib/core/data/`: SQLCipher DB, migrations, repositories.
- `lib/features/assistant/`: tool registry, agent loop, prompt policy.
- `lib/features/ingestion/`: OCR, entity extraction, chunking.
- `lib/features/retrieval/`: embeddings, vector store, hybrid ranker.

## 10) Immediate Next Refactors

- Move from secure-storage JSON vault to encrypted SQLCipher tables.
- Add explicit `SecretAccessPolicy` service for password reveal/copy.
- Add `ToolExecutor` abstraction to unify command parsing and AI calls.
- Add `AuditLogRepository` for all data mutation operations.
