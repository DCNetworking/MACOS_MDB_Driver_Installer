# MDB Driver for macOS

Read Microsoft Access databases on macOS with Python — finally.

`.mdb` · `.accdb` · `pyodbc` · Apple Silicon · Intel

---

## The pain

You have an `.mdb` or `.accdb` file. You want to read it in Python. You're on a Mac. You try pyodbc and get this:

```
pyodbc.Error: ('01000', "Can't open lib 'MDB Tools ODBC' : file not found")
```

You google it. You find Stack Overflow threads from 2014. You try `odbcinst -i` — it silently fails. You try editing config files. Nothing works.

**This installer fixes all of it. Automatically.**

---

## Get started in 30 seconds

1. Download **MDB_Driver_Installer.dmg** from [Releases](../../releases/latest)
2. Open the `.dmg` and double-click **MDB Driver Installer.app**
3. Terminal opens — watch it install everything
4. Restart your IDE and ship code

```python
import pyodbc

conn = pyodbc.connect(
    "DRIVER={MDB Tools ODBC};"
    "DBQ=/path/to/your/file.mdb"
)

cursor = conn.cursor()
cursor.execute("SELECT * FROM Customers")

for row in cursor.fetchall():
    print(row)
```

No manual config. No digging through Homebrew Cellar paths. No editing `.ini` files by hand.

---

## What gets installed

The installer sets up the full driver stack — and handles the edge cases that every other guide misses.

```
Homebrew
  ├── mdbtools          open-source Access file engine
  └── unixodbc          ODBC driver manager for Unix

~/.zshrc
  ├── ODBCSYSINI        tells pyodbc where to find the config
  └── ODBCINI           without this, pyodbc.drivers() returns []

/opt/homebrew/etc/odbcinst.ini
  └── [MDB Tools ODBC]  registered directly — bypasses the broken odbcinst CLI
```

The reason every manual setup fails: `odbcinst -i` silently errors on modern Homebrew builds, so the driver never gets registered. This installer writes the config directly and sets the environment variables that make pyodbc actually find it.

---

## Requirements

- macOS 12 Monterey or later
- [Homebrew](https://brew.sh) — if you don't have it yet, the installer will tell you
- Python 3.9+
- ~50 MB disk space

Works on **Apple Silicon** (M1/M2/M3/M4) and **Intel** Macs.

---

## How it works

### The root cause

pyodbc on macOS looks for ODBC drivers in `/etc/odbcinst.ini` by default — but Homebrew installs everything under `/opt/homebrew/etc/`. Without `ODBCSYSINI` pointing to the right place, `pyodbc.drivers()` returns an empty list even after a correct installation.

On top of that, `odbcinst -i` — the standard tool for registering ODBC drivers — fails silently on recent Homebrew builds of unixODBC. So every tutorial that tells you to run `odbcinst -i -d -f driver.ini` just... doesn't work.

### The fix

Two things need to happen.

Write the driver entry directly to `odbcinst.ini`:

```ini
[MDB Tools ODBC]
Description = MDB Tools ODBC Driver
Driver      = /opt/homebrew/Cellar/mdbtools/1.0.1_1/lib/odbc/libmdbodbc.dylib
Setup       = /opt/homebrew/Cellar/mdbtools/1.0.1_1/lib/odbc/libmdbodbc.dylib
FileUsage   = 1
```

Set `ODBCSYSINI` so pyodbc finds it:

```bash
export ODBCSYSINI=/opt/homebrew/etc
export ODBCINI=/opt/homebrew/etc/odbc.ini
```

The installer does both, adds them to your shell profile, and verifies the result before closing.

---

## Build the DMG yourself

```bash
git clone https://github.com/your-username/mdb-driver-macos
cd mdb-driver-macos
bash build_dmg.sh
```

`MDB_Driver_Installer.dmg` appears in the same folder (~2 MB).

---

## Troubleshooting

**`pyodbc.drivers()` still returns `[]`**

The `ODBCSYSINI` variable needs to be picked up by your shell. Open a new terminal window and try again. If you're using PyCharm or VS Code, restart the IDE.

**Homebrew not found**

Install Homebrew first, then run the installer again:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**`libmdbodbc.dylib` not found**

```bash
brew reinstall mdbtools
find $(brew --prefix) -name "libmdbodbc.dylib"
```

**Gatekeeper blocks the app**

Go to **System Settings → Privacy & Security** and click **Open Anyway**.

---

## Stack

[mdbtools](https://github.com/mdbtools/mdbtools) · [unixODBC](https://www.unixodbc.org) · [pyodbc](https://github.com/mkleehammer/pyodbc) · [Homebrew](https://brew.sh)

---

MIT License · Made for developers who just want to read a database file
