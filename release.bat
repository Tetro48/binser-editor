call package.bat

mkdir dist
mkdir dist\windows
mkdir dist\win32
mkdir dist\other

copy /b dist\windows\love.exe+binsereditor.love dist\windows\binsereditor.exe
copy /b dist\win32\love.exe+binsereditor.love dist\win32\binsereditor.exe
copy /b binsereditor.love dist\other\binsereditor.love

copy SOURCES.md dist\windows
copy LICENSE.md dist\windows
copy SOURCES.md dist\win32
copy LICENSE.md dist\win32
copy SOURCES.md dist\other
copy LICENSE.md dist\other

cd dist\windows
tar -a -c -f ..\binsereditor-windows.zip binsereditor.exe *.dll libs *.md
cd ..\..

cd dist\win32
tar -a -c -f ..\binsereditor-win32.zip binsereditor.exe *.dll libs *.md
cd ..\..

cd dist\other
tar -a -c -f ..\binsereditor-other.zip binsereditor.love libs *.md
cd ..\..