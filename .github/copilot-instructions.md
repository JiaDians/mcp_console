# MCP Console 的 Copilot 指南

## 建置、測試與檢查指令

- 安裝相依套件：`flutter pub get`
- 啟動 Windows 桌面版：`flutter run -d windows`
- 使用與 CI 相同的分析指令：`flutter analyze --no-fatal-infos`
- 執行全部測試：`flutter test`
- 執行目前唯一的單一測試檔：`flutter test test\widget_test.dart`
- 執行單一具名測試：`flutter test test\widget_test.dart --plain-name "App smoke test"`
- 建置 Windows 發行版：`flutter build windows --release`

CI 目前只在 `windows-latest` 上執行，流程是 `flutter pub get`、`flutter analyze --no-fatal-infos`、`flutter build windows --release`。發版流程則由標籤 `v*.*.*` 觸發，會額外把 Windows 輸出包成 NSIS 安裝程式與 portable zip。

## 高層架構

這是一個使用 Flutter 3 / Dart 3 開發的 Windows 桌面應用，目的在於讀取多種 AI 用戶端的 MCP 設定檔，集中顯示、編輯、檢查版本並更新 MCP 伺服器。`lib\main.dart` 會先初始化 `window_manager`、設定桌面視窗大小，再用 Riverpod 的 `ProviderScope` 啟動 `McpConsoleApp`；`lib\app.dart` 則負責 Material 3 主題與進入 `HomeScreen`。

整體資料流以 Riverpod provider 為核心：

- `aiClientsProvider` 會根據 `ClientPaths` 提供的內建路徑，加上 `SharedPreferences` 儲存的自訂路徑，組成目前可用且可切換啟用狀態的 AI 用戶端清單。
- `mcpListProvider` 會讀取所有已啟用用戶端的設定檔，透過 `ConfigParserService` 解析 `mcpServers`，再把同名的 MCP 合併成單一 `McpServer`，並把來源用戶端記錄在 `clients`。
- `filteredMcpListProvider` 會依 `clientFilterProvider` 的篩選狀態，只顯示特定用戶端或全部 MCP。
- `versionCheckProvider` 是 `FutureProvider.family`，負責針對單一 `McpServer` 觸發版本或連線檢查。

服務層責任切分如下：

- `ConfigParserService` 專門處理 MCP 設定 JSON 的讀寫，支援 stdio 類型的 `command`、`args`、`env`，以及 HTTP/SSE 類型的 `type`、`url`、`headers`。編輯時會盡量保留未知欄位，輸出 JSON 時使用兩格縮排。
- `VersionUtils` 負責從命令列參數中辨識 npm、Python、GitHub 類型的套件資訊，並做基本版本比較。
- `LocalVersionService` 會透過 `npm`、`uv`、`pip` 查本機已安裝版本，並在程式存活期間快取 npm 與 uv 的查詢結果。
- `VersionCheckService` 依 `McpType` 決定要查 npm、PyPI、GitHub release/tag/package.json fallback，或直接做 HTTP/SSE 連線探測。
- `UpdateService` 會用 `ProcessRunner` 執行實際更新指令、串流回傳更新日誌，並在成功後同步改寫相關設定檔中的版本字串。

畫面分工依使用流程劃分：`HomeScreen` 顯示合併後的 MCP 清單，`McpDetailScreen` 顯示詳細資訊、版本／連線狀態，並提供更新與移除入口，`McpEditScreen` 用來編輯該 MCP 在所有相關用戶端中的設定，`SettingsScreen` 則管理主題、用戶端啟用狀態與自訂設定檔路徑。共用 UI 元件集中在 `lib\ui\widgets`。

## 重要慣例

- 使用者可見的 UI 文案以繁體中文為主，請跟現有畫面與 README 保持一致。
- 若要新增內建 AI 用戶端，通常要同時更新 `AiClientType` 的顯示名稱與圖示、`ClientPaths` 的各平台預設路徑，以及 `ClientPaths.knownClients`。
- 這個專案把 MCP 名稱視為主要識別鍵：`McpServer` 的相等比較、跨用戶端合併，以及編輯／刪除時定位設定項目，都是以名稱為準。
- 編輯設定檔時不要重建整份 MCP 結構；只修改已知欄位，並保留原本未知或客戶端特有的欄位。
- 任何會影響設定檔內容或資料來源的操作後，都應使用 Riverpod invalidate 讓畫面重新從磁碟載入，例如 `ref.invalidate(mcpListProvider)`、`ref.invalidateSelf()` 或對應的 family provider。
- 更新流程中若需要即時顯示命令輸出，優先沿用 `ProcessRunner.stream`；它已經統一採用 `runInShell: true`，並把 stderr 行加上 `[stderr]` 前綴。
- 涉及環境變數或 HTTP 標頭這類敏感值時，沿用 `McpDetailScreen` 的做法：預設遮罩，只在使用者明確操作時顯示或複製。
- 桌面版視覺風格集中在 `AppTheme`，新增畫面時優先沿用既有的 Material 3 色彩、字級、Card 與 Chip 風格，不要隨意另起一套視覺規則。
