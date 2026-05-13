@echo off
REM Always runs Flutter from this folder (avoids building another copy of the project).
cd /d "%~dp0"
echo Running from: %CD%
flutter pub get
flutter run -d chrome
