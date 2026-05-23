@echo off
echo Pushing local changes to Git...
echo.

git add .

set /p msg="Commit message: "

if "%msg%"=="" (
    echo Commit message cannot be empty!
    pause
    exit /b 1
)

git commit -m "%msg%"

echo.
echo Pushing to origin main...
git push origin main

echo.
echo Done! Changes pushed to Git.
pause
