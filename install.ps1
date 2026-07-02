Write-Host "Iniciando instalación de Search and AviferXL..." -ForegroundColor Cyan

$repoUrl = "https://github.com/stickyfran/searchandavif/archive/refs/heads/main.zip"
$zipPath = "$env:TEMP\repo.zip"

Write-Host "Descargando repositorio..."
Invoke-WebRequest -Uri $repoUrl -OutFile $zipPath

Write-Host "Extrayendo archivos..."
Expand-Archive -Path $zipPath -DestinationPath "$env:TEMP" -Force

if (Test-Path "$env:TEMP\searchandavif-main") { 
    $folder="searchandavif-main" 
} else { 
    $folder="searchandavif-master" 
}

Write-Host "Instalando códecs en Documentos..."
New-Item -ItemType Directory -Force -Path "$home\Documents\codecs" | Out-Null
Copy-Item -Path "$env:TEMP\$folder\codecs\*" -Destination "$home\Documents\codecs" -Recurse -Force

Write-Host "Enviando AviferXL.bat al Escritorio..."
Copy-Item -Path "$env:TEMP\$folder\AviferXL.bat" -Destination "$home\Desktop\AviferXL.bat" -Force

Write-Host "Limpiando archivos temporales..."
Remove-Item -Path $zipPath, "$env:TEMP\$folder" -Recurse -Force

Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host " Instalación completada con éxito." -ForegroundColor Green
Write-Host " AviferXL.bat ya está listo en tu Escritorio." -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green