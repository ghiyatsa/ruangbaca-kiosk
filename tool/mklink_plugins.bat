@echo off
setlocal
set "SLINKS=D:\ruangbaca-kiosk\windows\flutter\ephemeral\.plugin_symlinks"
if not exist "%SLINKS%" mkdir "%SLINKS%"
if not exist "%SLINKS%\camera_desktop" mklink /J "%SLINKS%\camera_desktop" "C:\\Users\\Ghiyatsa\\AppData\\Local\\Pub\\Cache\\hosted\\pub.dev\\camera_desktop-1.2.1" >nul
if not exist "%SLINKS%\file_selector_windows" mklink /J "%SLINKS%\file_selector_windows" "C:\\Users\\Ghiyatsa\\AppData\\Local\\Pub\\Cache\\hosted\\pub.dev\\file_selector_windows-0.9.3+6" >nul
if not exist "%SLINKS%\flutter_zxing" mklink /J "%SLINKS%\flutter_zxing" "C:\\Users\\Ghiyatsa\\AppData\\Local\\Pub\\Cache\\hosted\\pub.dev\\flutter_zxing-3.0.1" >nul
if not exist "%SLINKS%\image_picker_windows" mklink /J "%SLINKS%\image_picker_windows" "C:\\Users\\Ghiyatsa\\AppData\\Local\\Pub\\Cache\\hosted\\pub.dev\\image_picker_windows-0.2.2" >nul
if not exist "%SLINKS%\screen_retriever_windows" mklink /J "%SLINKS%\screen_retriever_windows" "C:\\Users\\Ghiyatsa\\AppData\\Local\\Pub\\Cache\\hosted\\pub.dev\\screen_retriever_windows-0.2.2" >nul
if not exist "%SLINKS%\window_manager" mklink /J "%SLINKS%\window_manager" "C:\\Users\\Ghiyatsa\\AppData\\Local\\Pub\\Cache\\hosted\\pub.dev\\window_manager-0.5.2" >nul
echo DONE