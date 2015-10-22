set PATH=C:\D\dmd2\windows\bin;C:\Program Files (x86)\Microsoft Visual Studio 14.0\\Common7\IDE;C:\Program Files (x86)\Windows Kits\8.1\\bin;%PATH%
set DMD_LIB=;..\Base\Debug ..\Framework\Debug ..\ExternalLibs\Debug

echo desktop\build.d >win64\Risk.build.rsp
echo desktop\combat.d >>win64\Risk.build.rsp
echo desktop\mission.d >>win64\Risk.build.rsp
echo desktop\move.d >>win64\Risk.build.rsp
echo desktop\risk.d >>win64\Risk.build.rsp
echo screens\attack.d >>win64\Risk.build.rsp
echo screens\build.d >>win64\Risk.build.rsp
echo screens\loading.d >>win64\Risk.build.rsp
echo screens\move.d >>win64\Risk.build.rsp
echo screens\risk_screen.d >>win64\Risk.build.rsp
echo screens\start.d >>win64\Risk.build.rsp
echo screens\world.d >>win64\Risk.build.rsp
echo blob.d >>win64\Risk.build.rsp
echo data.d >>win64\Risk.build.rsp
echo eventmanager.d >>win64\Risk.build.rsp
echo events.d >>win64\Risk.build.rsp
echo event_queue.d >>win64\Risk.build.rsp
echo game_events.d >>win64\Risk.build.rsp
echo inplace.d >>win64\Risk.build.rsp
echo main.d >>win64\Risk.build.rsp
echo network_events.d >>win64\Risk.build.rsp
echo network_manager.d >>win64\Risk.build.rsp
echo risk.d >>win64\Risk.build.rsp

dmd -g -debug -X -Xf"win64\Risk.json" -I..\Base -I..\Framework -I..\ExternalLibs -deps="win64\Risk.dep" -c -of"win64\Risk.obj" @win64\Risk.build.rsp
if errorlevel 1 goto reportError

set LIB="C:\D\dmd2\windows\bin\..\lib"
echo. > C:\Risk\Risk-Desktop\Risk\win64\Risk.build.lnkarg
echo "win64\Risk.obj","win64\Risk.exe","win64\Risk.map",Base.lib+ >> C:\Risk\Risk-Desktop\Risk\win64\Risk.build.lnkarg
echo Framework.lib+ >> C:\Risk\Risk-Desktop\Risk\win64\Risk.build.lnkarg
echo ExternalLibs.lib+ >> C:\Risk\Risk-Desktop\Risk\win64\Risk.build.lnkarg
echo user32.lib+ >> C:\Risk\Risk-Desktop\Risk\win64\Risk.build.lnkarg
echo kernel32.lib+ >> C:\Risk\Risk-Desktop\Risk\win64\Risk.build.lnkarg
echo ..\Base\Debug\+ >> C:\Risk\Risk-Desktop\Risk\win64\Risk.build.lnkarg
echo ..\Framework\Debug\+ >> C:\Risk\Risk-Desktop\Risk\win64\Risk.build.lnkarg
echo ..\ExternalLibs\Debug\/NOMAP/CO/NOI/DELEXE >> C:\Risk\Risk-Desktop\Risk\win64\Risk.build.lnkarg

"C:\Program Files (x86)\VisualD\pipedmd.exe" -deps win64\Risk.lnkdep C:\D\dmd2\windows\bin\link.exe @C:\Risk\Risk-Desktop\Risk\win64\Risk.build.lnkarg
if errorlevel 1 goto reportError
if not exist "win64\Risk.exe" (echo "win64\Risk.exe" not created! && goto reportError)

goto noError

:reportError
echo Building win64\Risk.exe failed!

:noError
