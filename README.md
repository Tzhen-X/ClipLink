# SyncClipboard HarmonyOS Client (MVP)

This is a minimal viable product (MVP) HarmonyOS client for SyncClipboard, built with ArkTS and the Stage Model.

## Features

### Implemented (MVP Scope)
- ✅ **Three-tab navigation**: Home / History / Settings
- ✅ **Home Page**:
  - Display current clipboard text preview
  - Upload button to sync clipboard to server
  - Download button to fetch server clipboard
  - Auto-sync toggle with configurable polling interval
  - Real-time sync status display
- ✅ **History Page**:
  - List view of clipboard history
  - Syncs with server via `/api/history/query` and `/api/history` endpoints
  - Local persistence using RDB (RelationalStore)
  - Tap to copy history item to clipboard
- ✅ **Settings Page**:
  - Server configuration (URL, username, password)
  - Polling interval adjustment
  - Theme selection (Light/Dark/Auto)
  - Max history size setting
  - Configuration persistence via Preferences API
- ✅ **Service Layer**:
  - `ConfigService`: App config management with Preferences
  - `HttpClient`: Basic HTTP GET/PUT/POST abstraction
  - `SyncClipboardService`: API client for SyncClipboard endpoints
  - `HistoryStorageService`: Local history persistence with RDB
  - `PollingController`: Simple foreground polling timer
  - `ClipboardUtil`: System clipboard read/write via Pasteboard API
  - `HashUtil`: SHA256 hashing (uppercase hex, compatible with existing clients)

### Text Clipboard Flow
- Text clipboard content can be uploaded to and downloaded from server
- Hash calculation compatible with existing SyncClipboard protocol (uppercase SHA256)
- Profile DTO and History DTO models match server format
- Supports `/SyncClipboard.json` endpoint for current clipboard
- Supports `/api/history/query`, `/api/history`, and `/api/history/{profileId}` endpoints for history records

### Deferred (Out of MVP Scope)
- ❌ Image/File clipboard support (models exist but no UI implementation)
- ❌ SignalR real-time sync
- ❌ Share receive/send functionality
- ❌ SMS forwarding
- ❌ Quick actions/shortcuts
- ❌ Background resident service
- ❌ File upload/download implementation

## Project Structure

```
harmony/
├── AppScope/
│   ├── app.json5                    # App bundle config
│   └── resources/                   # App-level resources
├── entry/                           # Entry module (HAP)
│   ├── src/main/
│   │   ├── ets/
│   │   │   ├── entryability/
│   │   │   │   └── EntryAbility.ets    # App entry point
│   │   │   ├── pages/
│   │   │   │   ├── Index.ets           # Tab container
│   │   │   │   ├── HomePage.ets        # Home tab
│   │   │   │   ├── HistoryPage.ets     # History tab
│   │   │   │   └── SettingsPage.ets    # Settings tab
│   │   │   ├── services/
│   │   │   │   ├── ConfigService.ets         # Config persistence
│   │   │   │   ├── HttpClient.ets            # HTTP wrapper
│   │   │   │   ├── SyncClipboardService.ets  # API client
│   │   │   │   ├── HistoryStorageService.ets # Local DB
│   │   │   │   └── PollingController.ets     # Timer
│   │   │   ├── utils/
│   │   │   │   ├── ClipboardUtil.ets   # Clipboard operations
│   │   │   │   └── HashUtil.ets        # SHA256 hashing
│   │   │   └── types/
│   │   │       └── ApiTypes.ets        # DTO models
│   │   ├── resources/                  # Module resources
│   │   └── module.json5                # Module config
│   ├── build-profile.json5
│   ├── hvigorfile.ts
│   └── oh-package.json5
├── build-profile.json5              # Project build config
├── hvigorfile.ts                    # Hvigor build script
├── oh-package.json5                 # Project dependencies
└── README.md                        # This file
```

## Build & Run

### Prerequisites
- OpenHarmony SDK API 20
- DevEco Studio 5.0 or later
- HarmonyOS device or emulator

### Steps
1. **Import Project**:
   - Open DevEco Studio
   - File → Open → Select `harmony/` directory
   - Wait for project sync

2. **Configure Signing**:
    - File → Project Structure → Signing Configs
    - Configure automatic signing or manual signing certificate
   - Keep signing materials in your local environment only; this repository does not commit them

3. **Build**:
   - Build → Make Module 'entry'
   - Or use Hvigor CLI: `hvigorw assembleHap`

4. **Run**:
    - Connect HarmonyOS device or start emulator
    - Run → Run 'entry'
    - Or use: `hvigorw installHapDebug`

### Local CLI Setup
1. Set `OHOS_BASE_SDK_HOME` to your local OpenHarmony SDK root.
2. Put your local SDK path into `local.properties` as `sdk.dir=...`.
3. Fill `app.signingConfigs` in `build-profile.json5` before installing to a device.

### First Launch Configuration
1. Launch the app
2. Navigate to **Settings** tab
3. Configure your SyncClipboard server:
   - Server URL: `http://your-server:5033`
   - Username: (optional, if auth enabled)
   - Password: (optional, if auth enabled)
4. Adjust polling interval if needed (default: 5 seconds)
5. Tap **Save**

## API Compatibility

This client is compatible with existing SyncClipboard server endpoints:

### Profile Endpoint
- `GET /SyncClipboard.json` - Get current clipboard
- `PUT /SyncClipboard.json` - Upload current clipboard

### History API
- `POST /api/history/query` - Query history records
- `GET /api/history/{profileId}` - Get single record
- `POST /api/history` - Upload new record

### Data Format
- **ProfileDto**: `{ type, hash, text, hasData, dataName, size }`
- **HistoryRecordDto**: `{ hash, type, text, createTime, lastModified, starred, pinned, hasData, size, version, isDeleted }`
- **Hash Rule**: Uppercase hex SHA256 of text content

## Development Notes

### Hash Compatibility
The `HashUtil.calculateTextHash()` implementation uses HarmonyOS `cryptoFramework` API to compute SHA256 hashes in uppercase hex format, matching the existing RN client behavior.

### Clipboard Operations
- `ClipboardUtil` uses `@ohos.pasteboard` for text read/write
- Only text clipboard is fully implemented in MVP
- Image/File types exist in type definitions but lack implementation

### HTTP Authentication
- Basic Auth is implemented in `HttpClient`
- Base64 encoding is done manually (no built-in util used)

### Local Storage
- App config: `dataPreferences` API (key-value store)
- History records: `relationalStore` API (SQLite-based RDB)

### Polling
- Foreground-only polling via simple `setInterval`
- No background service (out of MVP scope)
- Stops when app is backgrounded (no persistent sync)

## Limitations & Known Issues

1. **Local Signing Required**: The repository does not include signing materials or machine-specific SDK paths. Add them locally before device installation.

2. **No Runtime Testing**: Code is based on HarmonyOS API documentation but has not been executed on device/emulator.

3. **Text-Only**: Only text clipboard is functional. Image/File support requires additional implementation.

4. **Basic UI**: Minimal styling and no advanced animations. Focused on functionality over polish.

5. **Error Handling**: Basic error handling implemented, but production apps would need more robust retry logic and user feedback.

6. **No Localization**: All strings are hardcoded in English (also available in resources but not fully i18n ready).

## Future Enhancements (Beyond MVP)

- Image clipboard support with file upload/download
- File clipboard support
- SignalR integration for real-time push sync
- Background service for continuous sync
- Share extension for receiving content from other apps
- SMS forwarding integration
- Quick actions (widgets, shortcuts)
- Advanced UI with animations and transitions
- Full localization support
- Unit tests and integration tests
- Performance optimization for large history

## License

Same as parent SyncClipboard project.

## References

- HarmonyOS Documentation: https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/
- SyncClipboard Protocol: See parent project `/docs` or existing RN client implementation
- ArkTS Language: https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-get-started-V5

---

**MVP Status**: Core text sync functionality complete. Ready for DevEco import and basic testing.
