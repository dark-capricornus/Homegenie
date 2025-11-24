Python & Build Tools setup helpers
=================================

This folder provides small helper scripts to make local setup easier on Windows.

setup_py311_venv.ps1
--------------------
- Creates a Python 3.11 virtual environment `.venv311` and installs `config/requirements.txt`.
- If Python 3.11 isn't available via the `py` launcher, it downloads the official installer to `./bootstrap/`.

install_msvc_build_tools.ps1
---------------------------
- Opens the Visual C++ Build Tools download page. Installing those tools is required
  to build some Python packages (e.g., asyncpg) from source on Windows.

Recommended flow
----------------
1. Preferred: use Python 3.11 (many prebuilt wheels available). Run:
   PowerShell: `.\	ools\setup_py311_venv.ps1`

2. If you must stay on Python 3.14 and pip tries to build native extensions, run:
   `.\scripts\install_msvc_build_tools.ps1` and install the "C++ build tools" workload.
   
Note: We also added support for using `psycopg[binary]` as an alternative async Postgres driver
which typically provides prebuilt wheels for newer Python versions (including 3.14). This
avoids building `asyncpg` from source. The project will attempt to use `asyncpg` if available,
otherwise it will fall back to `psycopg` automatically.

3. After installing build tools or creating a 3.11 venv, activate your venv and install requirements:
   PowerShell:
       .\\.venv311\\Scripts\\Activate.ps1
       pip install -r config/requirements.txt
