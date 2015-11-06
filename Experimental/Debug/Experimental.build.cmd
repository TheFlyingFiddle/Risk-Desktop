set PATH=C:\D\dmd2\windows\bin;C:\Program Files (x86)\Microsoft Visual Studio 14.0\\Common7\IDE;C:\Program Files (x86)\Windows Kits\8.1\\bin;%PATH%
set DMD_LIB=;..\Base\Debug
dmd -g -debug -unittest -X -Xf"Debug\Experimental.json" -I..\Base -deps="Debug\Experimental.dep" -c -of"Debug\Experimental.obj" encoding\binary.d sidal\parser.d sidal\serializer.d main.d
if errorlevel 1 goto reportError

set LIB="C:\D\dmd2\windows\bin\..\lib"
echo. > C:\GitHub\Risk\Experimental\Debug\Experimental.build.lnkarg
echo "Debug\Experimental.obj","Debug\Experimental.exe","Debug\Experimental.map",Base.lib+ >> C:\GitHub\Risk\Experimental\Debug\Experimental.build.lnkarg
echo user32.lib+ >> C:\GitHub\Risk\Experimental\Debug\Experimental.build.lnkarg
echo kernel32.lib+ >> C:\GitHub\Risk\Experimental\Debug\Experimental.build.lnkarg
echo ..\Base\Debug\/NOMAP/CO/NOI/DELEXE >> C:\GitHub\Risk\Experimental\Debug\Experimental.build.lnkarg

"C:\Program Files (x86)\VisualD\pipedmd.exe" -deps Debug\Experimental.lnkdep C:\D\dmd2\windows\bin\link.exe @C:\GitHub\Risk\Experimental\Debug\Experimental.build.lnkarg
if errorlevel 1 goto reportError
if not exist "Debug\Experimental.exe" (echo "Debug\Experimental.exe" not created! && goto reportError)

goto noError

:reportError
echo Building Debug\Experimental.exe failed!

:noError
