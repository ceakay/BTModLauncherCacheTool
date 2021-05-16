# BTModLauncherCacheTool
Tool for fixing RT cache, and any other mods that use Launcher/Git.

# How it works
The tool will scan your computer for a git portable extract (../git-core/git.exe) and your RogueTech Launcher settings XML (This takes a while if you have large drives). Tool will use:
- git-clone to pull down missing git repos (no .git found - will purge folder and download from scratch as required by git-clone)
- git-restore to fix any modified or missing files
- git-status to generate list of files to delete. 

This is done automatically, and should be used only on advice from support team.

If tool reports errors, screenshot and file a ticket on RT discord - https://discord.gg/roguetech. 

# Additional Parameters
- -GITPath: Specify path to git.exe (Containing DIR or exact file)
- -SettingsPath: Specify path to RtlLauncherSettings.xml (Containing DIR or exact file) This is for QA/Testing team, users should not ever need this.

# Warnings
1. Only have ONE copy of git-portable (../git-core/git.exe). Use parameters to target git.exe location if you already have git installed. 
2. Only have ONE RT Launcher and accompanying settings. Having more than one copy has been known to break RT, so this tool is designed around that.

# Requirements
1. Make sure you read the warnings
2. Download and extract portable git to anywhere. https://github.com/git-for-windows/git/releases/latest
3. Download and run latest tool release. https://github.com/ceakay/BTModLauncherCacheTool/releases/latest
