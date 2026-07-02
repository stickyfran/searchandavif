# searchandavif
Jpeg , png to AVIF Script for Linux systems

---

##  Windows

### Instalación rápida en Windows

No necesitas descargar nada. Abri **PowerShell** y ejecuta este comando para instalar automáticamente la herramienta y los códecs:

```powershell
irm https://raw.githubusercontent.com/stickyfran/searchandavif/main/install.ps1 | iex
```

---

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
wget https://raw.githubusercontent.com/stickyfran/searchandavif/main/searchandavif.sh

# Darle permisos de ejecución
chmod +x searchandavif.sh

# Ejecutarlo
./searchandavif.sh
```
