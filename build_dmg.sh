#!/bin/bash
# =============================================================================
# build_dmg.sh — builds MDB_Driver_Installer.dmg
# Run ON YOUR MAC:  bash build_dmg.sh
# DMG will be saved next to this script
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="MDB Driver Installer"
DMG_NAME="MDB_Driver_Installer"
WORK=$(mktemp -d)
STAGE="$WORK/stage"
APP="$STAGE/$APP_NAME.app"
CONTENTS="$APP/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"

mkdir -p "$MACOS_DIR" "$RES"

# ---------------------------------------------------------------------------
# Info.plist
# ---------------------------------------------------------------------------
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>       <string>launcher</string>
  <key>CFBundleIdentifier</key>       <string>pl.mdbdriver.installer</string>
  <key>CFBundleName</key>             <string>MDB Driver Installer</string>
  <key>CFBundleDisplayName</key>      <string>MDB Driver Installer</string>
  <key>CFBundleVersion</key>          <string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundlePackageType</key>      <string>APPL</string>
  <key>LSMinimumSystemVersion</key>   <string>12.0</string>
  <key>NSHighResolutionCapable</key>  <true/>
</dict>
</plist>
PLIST

# ---------------------------------------------------------------------------
# Installer script (embedded in Resources)
# ---------------------------------------------------------------------------
cat > "$RES/install.sh" << 'INSTALL'
#!/bin/bash
set -euo pipefail

R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' B='\033[1m' N='\033[0m'

clear
echo ""
echo "┌─────────────────────────────────────────────────────┐"
echo "│        MDB / ACCDB Driver Installer for macOS       │"
echo "│        Enables: DRIVER={MDB Tools ODBC} in pyodbc   │"
echo "└─────────────────────────────────────────────────────┘"
echo ""

# ── Homebrew ──────────────────────────────────────────────────────────────────
echo -e "${B}[1/5]${N} Checking Homebrew..."
if ! command -v brew &>/dev/null; then
    for P in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        [ -f "$P" ] && eval "$($P shellenv)" && break
    done
fi
if ! command -v brew &>/dev/null; then
    echo -e "${R}❌  Homebrew is not installed.${N}"
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    read -rp "Press Enter to close..."; exit 1
fi
BREW=$(command -v brew)
BREW_PREFIX=$("$BREW" --prefix)
echo -e "${G}✔${N}  Homebrew: $BREW_PREFIX"

# ── mdbtools ──────────────────────────────────────────────────────────────────
echo -e "${B}[2/5]${N} Installing mdbtools..."
"$BREW" list mdbtools &>/dev/null || "$BREW" install mdbtools
echo -e "${G}✔${N}  mdbtools $("$BREW" list --versions mdbtools | awk '{print $2}')"

# ── unixODBC ──────────────────────────────────────────────────────────────────
echo -e "${B}[3/5]${N} Installing unixODBC..."
"$BREW" list unixodbc &>/dev/null || "$BREW" install unixodbc
echo -e "${G}✔${N}  unixODBC $("$BREW" list --versions unixodbc | awk '{print $2}')"

# ── Register driver ───────────────────────────────────────────────────────────
echo -e "${B}[4/5]${N} Registering ODBC driver..."
LIB=$(find "$BREW_PREFIX" -name "libmdbodbc.dylib" 2>/dev/null | head -1 || true)
if [ -z "$LIB" ]; then
    echo -e "${R}❌  libmdbodbc.dylib not found.${N}"
    read -rp "Press Enter to close..."; exit 1
fi
echo "    Library: $LIB"

ODBCINST_INI="$BREW_PREFIX/etc/odbcinst.ini"
touch "$ODBCINST_INI"

# Remove old entry if present
python3 - "$ODBCINST_INI" << 'PY'
import sys, re
p = sys.argv[1]
txt = open(p).read()
txt = re.sub(r'\[MDB Tools ODBC\][^\[]*', '', txt).strip()
open(p, 'w').write(txt + '\n')
PY

# Write fresh entry
cat >> "$ODBCINST_INI" << EOF

[MDB Tools ODBC]
Description = MDB Tools ODBC Driver
Driver      = $LIB
Setup       = $LIB
FileUsage   = 1
EOF
echo -e "${G}✔${N}  Entry added to $ODBCINST_INI"

# Set ODBCSYSINI in shell rc
EXPORT_SYS="export ODBCSYSINI=$BREW_PREFIX/etc"
EXPORT_INI="export ODBCINI=$BREW_PREFIX/etc/odbc.ini"
for RC in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bash_profile" "$HOME/.bashrc"; do
    if [ -f "$RC" ]; then
        grep -qF "ODBCSYSINI" "$RC" || echo "$EXPORT_SYS" >> "$RC"
        grep -qF "ODBCINI="   "$RC" || echo "$EXPORT_INI" >> "$RC"
        echo "    Environment variables added to $RC"; break
    fi
done
export ODBCSYSINI="$BREW_PREFIX/etc"
export ODBCINI="$BREW_PREFIX/etc/odbc.ini"

# ── pyodbc ────────────────────────────────────────────────────────────────────
echo -e "${B}[5/5]${N} Checking pyodbc..."
if ! python3 -c "import pyodbc" &>/dev/null; then
    echo "    Installing pyodbc..."
    LDFLAGS="-L$BREW_PREFIX/lib" CPPFLAGS="-I$BREW_PREFIX/include" \
    pip3 install --upgrade pyodbc --quiet
fi
echo -e "${G}✔${N}  pyodbc $(python3 -c 'import pyodbc; print(pyodbc.version)')"

# ── Verify ────────────────────────────────────────────────────────────────────
echo ""
python3 - "$BREW_PREFIX" << 'PY'
import sys, os
os.environ['ODBCSYSINI'] = sys.argv[1] + '/etc'
import pyodbc
mdb = [d for d in pyodbc.drivers() if 'mdb' in d.lower()]
if mdb:
    print(f"\033[0;32m✔\033[0m  pyodbc sees: {mdb}")
    print("")
    print("┌─────────────────────────────────────────────────────┐")
    print("│  ✅  Installation complete!                         │")
    print("│                                                      │")
    print("│  import pyodbc                                       │")
    print('│  conn = pyodbc.connect(                             │')
    print('│      "DRIVER={MDB Tools ODBC};"                     │')
    print('│      "DBQ=/path/to/file.mdb"                        │')
    print('│  )                                                   │')
    print("│                                                      │")
    print("│  ⚠️  Restart PyCharm if it was already open.        │")
    print("└─────────────────────────────────────────────────────┘")
else:
    print(f"\033[1;33m⚠\033[0m  Driver installed but pyodbc does not see it yet.")
    print("   Open a new terminal and check:")
    print('   python3 -c "import pyodbc; print(pyodbc.drivers())"')
PY

echo ""
read -rp "Press Enter to close..."
INSTALL

chmod +x "$RES/install.sh"

# ---------------------------------------------------------------------------
# Launcher
# ---------------------------------------------------------------------------
cat > "$MACOS_DIR/launcher" << 'LAUNCHER'
#!/bin/bash
SCRIPT="$(cd "$(dirname "$0")/../Resources" && pwd)/install.sh"
osascript << OSAS
tell application "Terminal"
    activate
    do script "bash '$SCRIPT'"
end tell
OSAS
LAUNCHER

chmod +x "$MACOS_DIR/launcher"

# ---------------------------------------------------------------------------
# Build DMG — single command, no mount/detach
# ---------------------------------------------------------------------------
DMG_OUT="$SCRIPT_DIR/$DMG_NAME.dmg"

echo ""
echo "Building .dmg..."

rm -f "$DMG_OUT"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    -fs HFS+ \
    "$DMG_OUT"

rm -rf "$WORK"

# ---------------------------------------------------------------------------
if [ -f "$DMG_OUT" ]; then
    SIZE=$(du -sh "$DMG_OUT" | awk '{print $1}')
    echo ""
    echo "┌─────────────────────────────────────────────────────┐"
    echo "│  ✅  DMG ready for distribution!                    │"
    printf "│  📦 %s (%s)\n" "$DMG_NAME.dmg" "$SIZE"
    echo "│  📁 Saved next to this script                       │"
    echo "└─────────────────────────────────────────────────────┘"
    echo ""
    open "$SCRIPT_DIR"
else
    echo "❌ DMG was not created."
fi
