@echo off
cd /d "%~dp0"
git add .
git commit -m "Added Pomodoro timer and Inbox navigation, fixed bugs, improved UI"
git push origin main
pause
