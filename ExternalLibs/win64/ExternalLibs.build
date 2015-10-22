set PATH=C:\D\dmd2\windows\bin;C:\Program Files (x86)\Microsoft Visual Studio 14.0\\Common7\IDE;C:\Program Files (x86)\Windows Kits\8.1\\bin;%PATH%

echo derelict\freeimage\freeimage.d >win64\ExternalLibs.build.rsp
echo derelict\freeimage\functions.d >>win64\ExternalLibs.build.rsp
echo derelict\freeimage\types.d >>win64\ExternalLibs.build.rsp
echo derelict\freetype\ft.d >>win64\ExternalLibs.build.rsp
echo derelict\freetype\functions.d >>win64\ExternalLibs.build.rsp
echo derelict\freetype\types.d >>win64\ExternalLibs.build.rsp
echo derelict\glfw3\glfw3.d >>win64\ExternalLibs.build.rsp
echo derelict\ogg\ogg.d >>win64\ExternalLibs.build.rsp
echo derelict\ogg\oggfunctions.d >>win64\ExternalLibs.build.rsp
echo derelict\ogg\oggtypes.d >>win64\ExternalLibs.build.rsp
echo derelict\ogg\vorbis.d >>win64\ExternalLibs.build.rsp
echo derelict\ogg\vorbisenc.d >>win64\ExternalLibs.build.rsp
echo derelict\ogg\vorbisencfunctions.d >>win64\ExternalLibs.build.rsp
echo derelict\ogg\vorbisenctypes.d >>win64\ExternalLibs.build.rsp
echo derelict\ogg\vorbisfile.d >>win64\ExternalLibs.build.rsp
echo derelict\ogg\vorbisfilefunctions.d >>win64\ExternalLibs.build.rsp
echo derelict\ogg\vorbisfiletypes.d >>win64\ExternalLibs.build.rsp
echo derelict\ogg\vorbisfunctions.d >>win64\ExternalLibs.build.rsp
echo derelict\ogg\vorbistypes.d >>win64\ExternalLibs.build.rsp
echo derelict\opengl3\arb.d >>win64\ExternalLibs.build.rsp
echo derelict\opengl3\cgl.d >>win64\ExternalLibs.build.rsp
echo derelict\opengl3\constants.d >>win64\ExternalLibs.build.rsp
echo derelict\opengl3\deprecatedConstants.d >>win64\ExternalLibs.build.rsp
echo derelict\opengl3\deprecatedFunctions.d >>win64\ExternalLibs.build.rsp
echo derelict\opengl3\ext.d >>win64\ExternalLibs.build.rsp
echo derelict\opengl3\functions.d >>win64\ExternalLibs.build.rsp
echo derelict\opengl3\gl.d >>win64\ExternalLibs.build.rsp
echo derelict\opengl3\gl3.d >>win64\ExternalLibs.build.rsp
echo derelict\opengl3\glx.d >>win64\ExternalLibs.build.rsp
echo derelict\opengl3\glxext.d >>win64\ExternalLibs.build.rsp
echo derelict\opengl3\internal.d >>win64\ExternalLibs.build.rsp
echo derelict\opengl3\types.d >>win64\ExternalLibs.build.rsp
echo derelict\opengl3\wgl.d >>win64\ExternalLibs.build.rsp
echo derelict\opengl3\wglext.d >>win64\ExternalLibs.build.rsp
echo derelict\sdl2\functions.d >>win64\ExternalLibs.build.rsp
echo derelict\sdl2\image.d >>win64\ExternalLibs.build.rsp
echo derelict\sdl2\mixer.d >>win64\ExternalLibs.build.rsp
echo derelict\sdl2\net.d >>win64\ExternalLibs.build.rsp
echo derelict\sdl2\sdl.d >>win64\ExternalLibs.build.rsp
echo derelict\sdl2\ttf.d >>win64\ExternalLibs.build.rsp
echo derelict\sdl2\types.d >>win64\ExternalLibs.build.rsp
echo derelict\util\exception.d >>win64\ExternalLibs.build.rsp
echo derelict\util\loader.d >>win64\ExternalLibs.build.rsp
echo derelict\util\sharedlib.d >>win64\ExternalLibs.build.rsp
echo derelict\util\system.d >>win64\ExternalLibs.build.rsp
echo derelict\util\wintypes.d >>win64\ExternalLibs.build.rsp
echo derelict\util\xtypes.d >>win64\ExternalLibs.build.rsp

"C:\Program Files (x86)\VisualD\pipedmd.exe" dmd -O -inline -release -lib -noboundscheck -X -Xf"win64\ExternalLibs.json" -deps="win64\ExternalLibs.dep" -of"win64\ExternalLibs.lib" -map "win64\ExternalLibs.map" -L/NOMAP @win64\ExternalLibs.build.rsp
if errorlevel 1 goto reportError
if not exist "win64\ExternalLibs.lib" (echo "win64\ExternalLibs.lib" not created! && goto reportError)

goto noError

:reportError
echo Building win64\ExternalLibs.lib failed!

:noError
