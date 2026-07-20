@echo off
setlocal

set "FLUTTER_BIN=flutter"
where flutter >nul 2>nul
if errorlevel 1 (
  if exist "C:\Users\admin\Downloads\flutter\bin\flutter.bat" (
    set "FLUTTER_BIN=C:\Users\admin\Downloads\flutter\bin\flutter.bat"
  ) else if exist "E:\travel_mgmt_app\flutter\bin\flutter.bat" (
    set "FLUTTER_BIN=E:\travel_mgmt_app\flutter\bin\flutter.bat"
  )
)

"%FLUTTER_BIN%" run -d chrome --profile --web-browser-flag=--disable-extensions --web-browser-flag=--disable-background-networking
