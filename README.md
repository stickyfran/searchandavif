# searchandavif
Jpeg , png to AVIF Script for Linux systems

---

##  Windows

### Instalación rápida en Windows

No necesitas descargar nada. Abri **PowerShell** y ejecuta este comando para instalar automáticamente la herramienta y los códecs:

```powershell
irm https://raw.githubusercontent.com/stickyfran/searchandavif/main/install.ps1 | iex
```

Te va a "instalar" los codecs que van a quedar en tu carpeta de Docuementos y un .bat en la carpeta de Escritorio.
Ese .bat lo pones en la carpeta que quieras y va a convertir esa carpeta y sus subdirectorios todas las imagenes a lo que elijas (JPEG-XL (lossless) o AVIF (muy eficiente ligero lossy))

## 🐧 Linux

### Para convertir a AVIF y JPEG-XL (requiere libheif y libjxl):

* **Arch Linux / CachyOS:**
```bash
sudo pacman -S libheif libjxl
```

* **Debian / Ubuntu:**
```bash
sudo apt install libheif-examples libjxl-tools
```

### Ejecución en Linux

```bash
# Descargar el script
wget https://raw.githubusercontent.com/stickyfran/searchandavif/main/AviferT3000.sh

# Darle permisos de ejecución
chmod +x AviferT3000.sh

# Ejecutarlo
./AviferT3000.sh
```
