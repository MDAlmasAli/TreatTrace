@echo off
echo Pulling latest TreatTrace updates...
git pull origin main
echo.
echo Installing dependencies...
flutter pub get
echo.
echo Done! You can now run the app.
pause
