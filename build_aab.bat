@echo off
cd /d "C:\Users\Kirill\FlutterProjects\smart_buy"
set PATH=C:\flutter\bin;%PATH%
flutter build appbundle --release
pause
