@echo off
REM Full rebuild — use if Chrome still shows an old UI after code changes.
cd /d "%~dp0"
echo Running from: %CD%
flutter clean
flutter pub get
flutter run -d chrome
