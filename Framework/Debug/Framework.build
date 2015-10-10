set PATH=C:\D\dmd2\windows\bin;C:\Program Files (x86)\Microsoft Visual Studio 14.0\\Common7\IDE;C:\Program Files (x86)\Windows Kits\8.1\\bin;%PATH%
set DMD_LIB=;..\Base\Debug; ..\ExternalLibs\Debug

echo app\components.d >Debug\Framework.build.rsp
echo app\core.d >>Debug\Framework.build.rsp
echo app\factories.d >>Debug\Framework.build.rsp
echo app\package.d >>Debug\Framework.build.rsp
echo app\screen.d >>Debug\Framework.build.rsp
echo content\content.d >>Debug\Framework.build.rsp
echo content\file.d >>Debug\Framework.build.rsp
echo content\font.d >>Debug\Framework.build.rsp
echo content\package.d >>Debug\Framework.build.rsp
echo content\reloading.d >>Debug\Framework.build.rsp
echo content\sound.d >>Debug\Framework.build.rsp
echo content\texture.d >>Debug\Framework.build.rsp
echo content\textureatlas.d >>Debug\Framework.build.rsp
echo graphics\buffer.d >>Debug\Framework.build.rsp
echo graphics\color.d >>Debug\Framework.build.rsp
echo graphics\common.d >>Debug\Framework.build.rsp
echo graphics\context.d >>Debug\Framework.build.rsp
echo graphics\convinience.d >>Debug\Framework.build.rsp
echo graphics\enums.d >>Debug\Framework.build.rsp
echo graphics\font.d >>Debug\Framework.build.rsp
echo graphics\frame.d >>Debug\Framework.build.rsp
echo graphics\framebuffer.d >>Debug\Framework.build.rsp
echo graphics\package.d >>Debug\Framework.build.rsp
echo graphics\program.d >>Debug\Framework.build.rsp
echo graphics\shader.d >>Debug\Framework.build.rsp
echo graphics\texture.d >>Debug\Framework.build.rsp
echo graphics\textureatlas.d >>Debug\Framework.build.rsp
echo network\file.d >>Debug\Framework.build.rsp
echo network\luagen.d >>Debug\Framework.build.rsp
echo network\message.d >>Debug\Framework.build.rsp
echo network\router.d >>Debug\Framework.build.rsp
echo network\server.d >>Debug\Framework.build.rsp
echo network\service.d >>Debug\Framework.build.rsp
echo network\util.d >>Debug\Framework.build.rsp
echo rendering\asyncrenderbuffer.d >>Debug\Framework.build.rsp
echo rendering\combined.d >>Debug\Framework.build.rsp
echo rendering\package.d >>Debug\Framework.build.rsp
echo rendering\renderer.d >>Debug\Framework.build.rsp
echo rendering\shapes.d >>Debug\Framework.build.rsp
echo sound\package.d >>Debug\Framework.build.rsp
echo sound\player.d >>Debug\Framework.build.rsp
echo window\clipboard.d >>Debug\Framework.build.rsp
echo window\gamepad.d >>Debug\Framework.build.rsp
echo window\keyboard.d >>Debug\Framework.build.rsp
echo window\mouse.d >>Debug\Framework.build.rsp
echo window\package.d >>Debug\Framework.build.rsp
echo window\window.d >>Debug\Framework.build.rsp
echo external_libraries.d >>Debug\Framework.build.rsp

"C:\Program Files (x86)\VisualD\pipedmd.exe" dmd -g -debug -lib -X -Xf"Debug\Framework.json" -I..\Base -I..\ExternalLibs -deps="Debug\Framework.dep" -of"Debug\Framework.lib" -map "Debug\Framework.map" -L/NOMAP @Debug\Framework.build.rsp
if errorlevel 1 goto reportError
if not exist "Debug\Framework.lib" (echo "Debug\Framework.lib" not created! && goto reportError)

goto noError

:reportError
echo Building Debug\Framework.lib failed!

:noError
