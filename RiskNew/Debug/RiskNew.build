set PATH=C:\D\dmd2\windows\bin;C:\Program Files (x86)\Microsoft Visual Studio 14.0\\Common7\IDE;C:\Program Files (x86)\Windows Kits\8.1\\bin;%PATH%
set DMD_LIB=;..\Base\Debug ..\Framework\Debug ..\ExternalLibs\Debug

echo experimental\serialization\simple.d >Debug\RiskNew.build.rsp
echo experimental\binaryblob.d >>Debug\RiskNew.build.rsp
echo experimental\channel.d >>Debug\RiskNew.build.rsp
echo risk\states\common.d >>Debug\RiskNew.build.rsp
echo risk\states\rendering.d >>Debug\RiskNew.build.rsp
echo risk\states\start.d >>Debug\RiskNew.build.rsp
echo risk\database.d >>Debug\RiskNew.build.rsp
echo risk\database_operations.d >>Debug\RiskNew.build.rsp
echo risk\input.d >>Debug\RiskNew.build.rsp
echo risk\output.d >>Debug\RiskNew.build.rsp
echo risk\screen.d >>Debug\RiskNew.build.rsp
echo main.d >>Debug\RiskNew.build.rsp

dmd -g -debug -X -Xf"Debug\RiskNew.json" -I..\Base -I..\Framework -I..\ExternalLibs -deps="Debug\RiskNew.dep" -c -of"Debug\RiskNew.obj" @Debug\RiskNew.build.rsp
if errorlevel 1 goto reportError

set LIB="C:\D\dmd2\windows\bin\..\lib"
echo. > C:\Risk\Risk-Desktop\RiskNew\Debug\RiskNew.build.lnkarg
echo "Debug\RiskNew.obj","Debug\RiskNew.exe","Debug\RiskNew.map",Base.lib+ >> C:\Risk\Risk-Desktop\RiskNew\Debug\RiskNew.build.lnkarg
echo Framework.lib+ >> C:\Risk\Risk-Desktop\RiskNew\Debug\RiskNew.build.lnkarg
echo ExternalLibs.lib+ >> C:\Risk\Risk-Desktop\RiskNew\Debug\RiskNew.build.lnkarg
echo user32.lib+ >> C:\Risk\Risk-Desktop\RiskNew\Debug\RiskNew.build.lnkarg
echo kernel32.lib+ >> C:\Risk\Risk-Desktop\RiskNew\Debug\RiskNew.build.lnkarg
echo ..\Base\Debug\+ >> C:\Risk\Risk-Desktop\RiskNew\Debug\RiskNew.build.lnkarg
echo ..\Framework\Debug\+ >> C:\Risk\Risk-Desktop\RiskNew\Debug\RiskNew.build.lnkarg
echo ..\ExternalLibs\Debug\/NOMAP/CO/NOI/DELEXE >> C:\Risk\Risk-Desktop\RiskNew\Debug\RiskNew.build.lnkarg

"C:\Program Files (x86)\VisualD\pipedmd.exe" -deps Debug\RiskNew.lnkdep C:\D\dmd2\windows\bin\link.exe @C:\Risk\Risk-Desktop\RiskNew\Debug\RiskNew.build.lnkarg
if errorlevel 1 goto reportError
if not exist "Debug\RiskNew.exe" (echo "Debug\RiskNew.exe" not created! && goto reportError)

goto noError

:reportError
echo Building Debug\RiskNew.exe failed!

:noError
