@echo off
cd /d "%~dp0"
set "GODOT=%USERPROFILE%\OneDrive\바탕 화면\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" set "GODOT=%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" set "GODOT=%~dp0..\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" goto nogodot
start "" "%GODOT%" --path "%~dp0." 
exit /b 0
:nogodot
echo.
echo  [오류] Godot_v4.7.2-stable_win64.exe 를 찾지 못했습니다.
echo  바탕 화면에 고도트 실행 파일이 있는지 확인해 주세요.
pause
exit /b 1
