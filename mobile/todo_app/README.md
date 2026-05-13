# todo_app

Flutter client for the course TODO fullstack project.

## Run (Chrome)

From this directory (`mobile/todo_app`):

```text
flutter pub get
flutter run -d chrome
```

On Windows you can double‑click **`run_chrome.bat`** (same folder as `pubspec.yaml`). If the browser still shows an old UI after edits, use **`run_chrome_fresh.bat`** or run `flutter clean`, then `flutter pub get`, then `flutter run -d chrome`.

## Run from Cursor / VS Code

Prefer opening the repo via **`kurs_todo_fullstack.code-workspace`** at the repository root. That adds a second workspace root named **`flutter_app`** pointing at this same folder (`mobile/todo_app`), so the integrated terminal’s default directory matches where you run Flutter.

Use **Run and Debug** and pick:

- **Flutter: todo_app (Chrome) — workspace file** — when you opened `kurs_todo_fullstack.code-workspace`.
- **Flutter: todo_app (Chrome, opened repo as folder)** — when you used **Open Folder** on the full repo only.
- **Flutter: todo_app (Chrome, opened only mobile/todo_app)** — when the workspace root is this directory alone.

## Troubleshooting

- **Log line `web_entrypoint.dart`:** normal for Flutter web; your code still starts from `lib/main.dart`.
- **Stale UI in Chrome:** hard refresh (**Ctrl+Shift+R**), try an incognito window, or clear site data for `localhost`.
- **Wrong code running:** confirm the file path you edit is under this same `mobile/todo_app` folder as `flutter run` (not a duplicate project elsewhere).

## API base URL

See `lib/main.dart` (`defaultBaseUrl`): web/desktop typically use `http://127.0.0.1:8000`; Android emulator often uses `http://10.0.2.2:8000`.
