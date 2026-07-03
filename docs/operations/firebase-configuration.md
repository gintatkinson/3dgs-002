# Firebase Configuration Guide

> How to run the app with Firebase Firestore as the data source,
> using either a local emulator or a cloud project.

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Running with Firebase Emulator (Local)](#2-running-with-firebase-emulator-local)
3. [Running with Firebase Cloud (Production)](#3-running-with-firebase-cloud-production)
4. [Selecting Data Source at Runtime](#4-selecting-data-source-at-runtime)
5. [Firestore Data Model](#5-firestore-data-model)
6. [Seeding Test Data](#6-seeding-test-data)
7. [Troubleshooting](#7-troubleshooting)

## 1. Prerequisites

- **Node.js 18+** — required for `firebase-tools`.
- **Java 11+** — required by the Firestore emulator.
- **Firebase project** — required for cloud mode (can be a free Spark tier).
- **Flutter SDK 3.12+** — with `cloud_firestore` and `firebase_core` added to `pubspec.yaml`:

  ```bash
  cd app_flutter
  flutter pub add cloud_firestore firebase_core
  ```
- **Firebase platform config files** per target platform:
  - Android: `google-services.json` in `android/app/`
  - iOS: `GoogleService-Info.plist` in `ios/Runner/`
  - macOS: `GoogleService-Info.plist` in `macos/Runner/`
  - Web: Firebase config in `web/index.html`

  Download these from **Project Settings > Your apps** in the [Firebase Console](https://console.firebase.google.com).

## 2. Running with Firebase Emulator (Local)

The emulator runs Firestore locally on port `8080` with no internet or cloud credentials required.

### Setup

```bash
cd app_flutter && ./scripts/setup-firebase-emulator.sh
```

This script:

1. Installs `firebase-tools` globally via npm (if not already present).
2. Creates `firebase.json` in the project root with Firestore emulator on port `8080` and the Emulator UI enabled.
3. Creates `firestore.rules` (permissive rules for local development).
4. Starts the emulator in the background.
5. Waits for the emulator to be ready (polls `http://localhost:8080`).
6. Seeds test data via `scripts/seed-firebase-data.py`.

### Run the app

```bash
cd app_flutter && flutter run --dart-define=DATA_SOURCE=firebase
```

The app calls `Firebase.initializeApp()` with a default (dummy) project, then connects the Firestore client to `localhost:8080` via `useFirestoreEmulator()`. All reads and writes hit the local emulator.

### Stopping the emulator

```bash
kill <PID>
```

The setup script prints the emulator PID on startup. Alternatively:

```bash
npx firebase-tools emulators:stop
```

### firebase.json

The root `firebase.json` is created automatically by the setup script:

```json
{
  "firestore": {
    "rules": "firestore.rules"
  },
  "emulators": {
    "firestore": {
      "port": 8080
    },
    "ui": {
      "enabled": true
    }
  }
}
```

### firestore.rules

Local development uses fully open rules (created by the setup script):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

## 3. Running with Firebase Cloud (Production)

To use a real Firebase project in production or staging:

### 3.1 Create a Firebase project

1. Go to the [Firebase Console](https://console.firebase.google.com) and create a new project (or select an existing one).
2. Register your app for each platform (Android, iOS, macOS, Web).
3. Download and place the platform config files (see [Prerequisites](#1-prerequisites)).

### 3.2 Deploy Firestore Security Rules

Replace the permissive local rules with production-appropriate rules. A minimal locked-down rule set:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /schema/{docId} {
      allow read: if true;
      allow write: if false; // schema is managed via migration scripts
    }
    match /data/{docId} {
      allow read, write: if request.auth != null;
    }
    match /elements/{docId} {
      allow read, write: if request.auth != null;
    }
    match /alarms/{docId} {
      allow read, write: if request.auth != null;
    }
    match /events/{docId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

Deploy rules:

```bash
firebase deploy --only firestore:rules
```

### 3.3 Seed the Firestore schema

Seed the schema document and base data using the REST API or the Firebase Admin SDK. You can use the same `seed-firebase-data.py` script by pointing it at the Firestore REST endpoint for your cloud project:

```bash
# Default (emulator) — no change needed
python3 app_flutter/scripts/seed-firebase-data.py

# Cloud — override the BASE and PROJECT variables in the script.
```

### 3.4 Run the app

```bash
cd app_flutter && flutter run --dart-define=DATA_SOURCE=firebase
```

In cloud mode, the app calls `Firebase.initializeApp()` with the platform config files and connects directly to the cloud Firestore instance (no `useFirestoreEmulator` call).

## 4. Selecting Data Source at Runtime

The data source is chosen at startup via the `DATA_SOURCE` Dart environment variable.

### 4.1 Environment variable (primary)

In `app_flutter/lib/main.dart:16`:

```dart
const _dataSource = String.fromEnvironment('DATA_SOURCE', defaultValue: 'sqlite');
```

| Value | Behavior |
|---|---|
| `sqlite` (default) | Uses the bundled SQLite database (`assets/properties_db.db`). |
| `firebase` | Initializes Firebase and connects to Firestore (emulator or cloud). |

Pass it at build/run time:

```bash
flutter run --dart-define=DATA_SOURCE=firebase
flutter build macos --dart-define=DATA_SOURCE=firebase
```

### 4.2 Config file fallback

If no `DATA_SOURCE` env var is set, `RepositoryResolver.resolve()` reads `assets/persistence-config.json`:

```json
{
  "repository_type": "sqlite"
}
```

Change to `"firebase"` to default to Firebase when the env var is absent.

### 4.3 Runtime resolution flow

```
main.dart
  └─ DATA_SOURCE env var → "firebase" or "sqlite"
       └─ passed to RepositoryResolver.resolve(dataSourceType: ...)
            ├─ "sqlite"   → SqliteDataSource + SqliteRepositoryAdapter
            └─ "firebase" → FirebaseDataSource + FirebaseRepositoryAdapter
                              └─ useEmulator = true (always for now)
```

When the type is `"firebase"`, `_createFirebaseAdapter()` always calls `firestore.useFirestoreEmulator('localhost', 8080)`. To switch to cloud, either remove that call or introduce a separate config flag.

### 4.4 Emulator vs Cloud differentiation

Today the code always enables the Firestore emulator when `DATA_SOURCE=firebase`. To differentiate between local and cloud, add a second env var:

```bash
flutter run --dart-define=DATA_SOURCE=firebase --dart-define=USE_FIRESTORE_EMULATOR=false
```

Alternatively, read a runtime config value. The `RepositoryResolver` already accepts `useEmulator` as a parameter (defaults to `true`).

## 5. Firestore Data Model

The Firestore database uses the following collections and document structure:

### 5.1 Schema collection

**Collection: `schema`**

| Document ID | Purpose | Fields |
|---|---|---|
| `types` | Defines all object types in the domain ontology. | `fields` — a map keyed by type name (e.g. `"Item"`, `"SubElement"`). Each value is a JSON string containing `displayName`, `iconName`, `fields` (array of field definitions), `childTypes`, `relatedTypes`, and `parentTypes`. |
| `hierarchy` | Defines parent-child relationships between types. | `pairs` — an array of `[parentTypeName, childTypeName]` tuples. |

**Example `schema/types` document (from seed script):**

```json
{
  "fields": {
    "Item": "{\"displayName\":\"Item\",\"iconName\":\"insert_drive_file\",\"fields\":[{\"key\":\"name\",\"label\":\"Name\",\"type\":\"string\"},{\"key\":\"description\",\"label\":\"Description\",\"type\":\"string\"}],\"childTypes\":[{\"relationName\":\"contains\",\"childTypeName\":\"SubElement\",\"childLabel\":\"Items\"}],\"relatedTypes\":[{\"relationName\":\"affects\",\"childTypeName\":\"Alarm\",\"childLabel\":\"Alarms\"},{\"relationName\":\"records\",\"childTypeName\":\"Event\",\"childLabel\":\"Events\"}]}",
    "SubElement": "{\"displayName\":\"Sub Element\",\"iconName\":\"widgets\",\"fields\":[{\"key\":\"id\",\"label\":\"ID\",\"type\":\"string\"},{\"key\":\"name\",\"label\":\"Name\",\"type\":\"string\"},{\"key\":\"type\",\"label\":\"Type\",\"type\":\"string\"},{\"key\":\"status\",\"label\":\"Status\",\"type\":\"string\"}]}",
    "Alarm": "{\"displayName\":\"Alarm\",\"iconName\":\"warning\",\"fields\":[{\"key\":\"id\",\"label\":\"Alarm ID\",\"type\":\"string\"},{\"key\":\"target\",\"label\":\"Target\",\"type\":\"string\"},{\"key\":\"severity\",\"label\":\"Severity\",\"type\":\"string\"},{\"key\":\"timestamp\",\"label\":\"Timestamp\",\"type\":\"string\"}]}",
    "Event": "{\"displayName\":\"Event\",\"iconName\":\"event\",\"fields\":[{\"key\":\"id\",\"label\":\"Event ID\",\"type\":\"string\"},{\"key\":\"source\",\"label\":\"Source\",\"type\":\"string\"},{\"key\":\"message\",\"label\":\"Message\",\"type\":\"string\"},{\"key\":\"timestamp\",\"label\":\"Timestamp\",\"type\":\"string\"}]}"
  }
}
```

**Example `schema/hierarchy` document:**

```json
{
  "fields": {
    "pairs": { "arrayValue": { "values": [] } }
  }
}
```

### 5.2 Data collection

**Collection: `data`** (node properties)

| Document ID | Content |
|---|---|
| `{nodeId}` | Flat key-value map of property values for that node. |

**Document fields:** Arbitrary — defined by the type's field schema (e.g. `name`, `description`, etc.).

```
data/{nodeId}
  └─ Document with { field1: value1, field2: value2, ... }
```

### 5.3 Elements collection

**Collection: `elements`**

| Document ID | Fields |
|---|---|
| `elem-{n}` | `parent_node_id` (string), `name` (string), `type` (string), `status` (string) |

Each element document represents a child entity under a parent node, filtered by `parent_node_id`.

### 5.4 Alarms collection

**Collection: `alarms`**

| Document ID | Fields |
|---|---|
| `alarm-{n}` | `parent_node_id` (string), `target` (string), `severity` (string), `timestamp` (string) |

### 5.5 Events collection

**Collection: `events`**

| Document ID | Fields |
|---|---|
| `event-{n}` | `parent_node_id` (string), `source` (string), `message` (string), `timestamp` (string) |

### 5.6 Summary of collection structure

```
schema/
  types               → document (type ontology, serialized as JSON strings)
  hierarchy           → document (type hierarchy pairs)

data/
  {nodeId}            → document (property key-value map)

elements/
  {elementId}         → document (fields: parent_node_id, name, type, status, ...)

alarms/
  {alarmId}           → document (fields: parent_node_id, target, severity, timestamp, ...)

events/
  {eventId}           → document (fields: parent_node_id, source, message, timestamp, ...)
```

## 6. Seeding Test Data

### 6.1 Automated seeding (with emulator setup)

Run the full setup script:

```bash
cd app_flutter && ./scripts/setup-firebase-emulator.sh
```

This starts the emulator and runs the Python seed script automatically.

### 6.2 Manual seeding

If the emulator is already running, seed data manually:

```bash
cd app_flutter && python3 scripts/seed-firebase-data.py
```

The seed script targets `http://localhost:8080` with project ID `demo-project` and populates:

- **Schema:** One `schema/types` document with 4 types (`Item`, `SubElement`, `Alarm`, `Event`) and one `schema/hierarchy` document.
- **Elements:** 15 sample element documents (`elem-1` through `elem-15`).
- **Alarms:** 15 sample alarm documents (`alarm-1` through `alarm-15`).
- **Events:** 15 sample event documents (`event-1` through `event-15`).

### 6.3 Seeding a cloud project

To seed a cloud Firestore instance, edit `seed-firebase-data.py` and change:

```python
BASE = "http://localhost:8080"        # → your Firestore REST endpoint
PROJECT = "demo-project"               # → your Firebase project ID
```

Then run:

```bash
python3 app_flutter/scripts/seed-firebase-data.py
```

For production, consider using the Firebase Admin SDK instead of the REST API for better authentication and transaction support.

## 7. Troubleshooting

### Emulator fails to start

**Symptom:** `firebase emulators:start` exits with an error about port 8080 in use.

**Solution:** Find and kill the process using port 8080:

```bash
lsof -ti:8080 | xargs kill -9
```

Or use a different port by editing `firebase.json`.

### "Cannot connect to emulator" at app startup

**Symptom:** The app hangs or throws a Firestore connection error on launch.

**Solution:** Ensure the emulator is running:

```bash
curl -s http://localhost:8080
```

If it returns OK, check that the seed script ran successfully. If not, start the emulator:

```bash
cd app_flutter && ./scripts/setup-firebase-emulator.sh
```

### App still uses SQLite despite `--dart-define=DATA_SOURCE=firebase`

**Symptom:** The app shows SQLite data instead of Firestore data.

**Solution:** Verify the env var is being passed. Run with verbose output:

```bash
flutter run --dart-define=DATA_SOURCE=firebase -v 2>&1 | grep DATA_SOURCE
```

Check `app_flutter/lib/main.dart:16` — the constant must read `String.fromEnvironment('DATA_SOURCE', defaultValue: 'sqlite')`.

### No types appear in the sidebar

**Symptom:** The sidebar shows an empty tree or a single fallback "Item" type.

**Solution:** Verify the `schema/types` document exists in Firestore:

```bash
curl http://localhost:8080/v1/projects/demo-project/databases/(default)/documents/schema/types
```

If the document is missing, re-run the seed script (see [Section 6](#6-seeding-test-data)).

### Seed script fails with HTTP 404

**Symptom:** `seed-firebase-data.py` reports `404` status codes.

**Solution:** The emulator may not be running, or the project ID does not match. Check the emulator is on port 8080:

```bash
curl http://localhost:8080
```

If running, verify the `PROJECT` variable in the seed script matches the emulator's project ID:

```python
PROJECT = "demo-project"
```

The emulator accepts any project ID by default, but the URL path must match.

### Firebase.initializeApp() throws "No Firebase App" error

**Symptom:** App crashes at startup with a Firebase initialization error.

**Solution:** Ensure platform config files are present (see [Prerequisites](#1-prerequisites)). For the emulator, a dummy config is sufficient — any `google-services.json` or `GoogleService-Info.plist` with a valid project ID works, since the SDK connects to the local emulator and never reaches the cloud.
