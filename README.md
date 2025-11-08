# 🧹 Interactive System & Developer Cache Cleanup

A full-featured **PowerShell cleanup utility** for Windows that safely purges junk, caches, and temporary files from both your **development environment** and your **system**, without touching personal data or breaking configurations.

---

## ✨ Features

✅ **Interactive prompts** – you choose what to clean (no accidental nuking).  
✅ **Safe by design** – preserves settings, credentials, logins, and history.  

✅ **Multi-tool developer cleanup:**
- npm / node_modules
- pip / conda / Python (detects all installs automatically)
- Docker, Bun, Gradle, Flutter, VS / JetBrains IDEs
- LM Studio (keeps chat history + settings)
  
✅ **System cleanup:**
- Windows Temp, Prefetch, and optional Search Index rebuild
  
✅ **Browser cleanup (optional):**
- Chrome, Edge, Brave, Firefox, Tor, Mullvad, Comet, Incognition, and others  
- Clears cache only (sessions and profiles remain intact)
  
✅ **Readable, modular PowerShell code**  
✅ **No reinstalls, no registry edits, no unsafe operations**

---

## 🧰 Installation & Usage
If your system blocks scripts:

1. **Download or clone** this repo:
   ```powershell
   git clone https://github.com/LizzieNya/clear-dev-caches-win.git
   cd clear-dev-caches-win
2. Run PowerShell as **Administrator**.
3. Execute the script
   ```powershell
    .\interactive_cleanup.ps1
Follow on-screen prompts (type y or n for each section.

What if cleans:

| Category         | Description                                                                 |
| ---------------- | --------------------------------------------------------------------------- |
| **Dev caches**   | npm, pip, conda, Docker, Bun, Gradle, Flutter, VSCode, IntelliJ, etc.       |
| **Python**       | Detects all python.exe installations and purges pip caches.                 |
| **LM Studio**    | Removes models/logs but preserves history & settings.json.                  |
| **Windows temp** | Clears `%TEMP%`, `%windir%\Temp`, and Prefetch safely.                      |
| **Search index** | Deletes and optionally rebuilds Windows Search index.                       |
| **Browsers**     | Wipes cache, GPU cache, shader cache for Chromium & Firefox-based browsers. |

## ⚠️ Safety Notes
- Make sure no browsers or IDEs are open while running the cleanup.

- Always close running containers or VMs before deleting Docker data.
- Everything removed will rebuild automatically when reopened.
- For peace of mind, create a restore point before running.

## 🧭 Why This Exists
If you’re a developer with:
- Multiple Python installs,
- Half a dozen browsers,
- Endless toolchains like npm, conda, Docker, Flutter, etc.,

this script gives you a clean slate — without reinstalling anything.
Think of it as “the digital equivalent of emptying your junk drawer."


## 🛡 License
This project is released under the MIT License.
Use, modify, and share freely — just don’t blame it if your system runs too fast afterward (or not at all!).

## 💬 Contributing
Issues and PRs are welcome!
Got an edge case or another browser to add? Open a pull request.

## 🌟 Support
If you find this useful:

⭐ Star the repo
🐛 Open an issue for bugs
🧩 Share improvements or feature requests
Or contribute!

Built with 🥀 and a severe lack of storage space.

@@ 🧑‍💻 Example Output
```mathematica
=== INTERACTIVE CLEANUP ===

Delete developer caches? (y/n) y
Deleting C:\Users\notebook\.npm
Deleting C:\Users\notebook\.docker
Cleaning LM Studio (keeping history & settings)
Purging pip cache for C:\Users\notebook\miniconda3\python.exe
...
✅ Cleanup finished. Restart is recommended.
