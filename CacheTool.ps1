$Drives = Get-PSDrive -PSProvider FileSystem #Get all possible drive letters

#Search for git-core/git.exe - this is to ensure there's a clean git-portable
$GitSearch = @()
Write-Host "Finding Git Portable..."
foreach ($Drive in $Drives) {
    $GitSearch += Get-ChildItem -Path $Drive.Root -Recurse -Filter "git.exe" -ErrorAction SilentlyContinue
}
$GitSearch = $GitSearch | ? {$_.Directory.BaseName -eq 'git-core'}

#Search for settings xml to get the cache path being used.
Write-Host "Finding RT Launcher..."
$RTLSearch = @()
foreach ($Drive in $Drives) {
    $RTLSearch += Get-ChildItem -Path $Drive.Root -Recurse -Filter "RtLauncherSettings.xml" -ErrorAction SilentlyContinue
}

$StoreDIR = $(pwd).Path

if ($GitSearch.Count -eq 1 -and $RTLSearch.Count -eq 1) {
    $GitPortable = $GitSearch[0].FullName #get full path to git-portable git.exe to call
    [xml]$RTLXML = Get-Content $($RTLSearch[0].FullName) #load xml
    $CachePath = $RTLXML.RogueTechLauncherSettings.CachePath #get cachepath
    Write-Host "Processing all repos in Cache: $CachePath"
    $AllGits = @($(Get-ChildItem $CachePath -Recurse -Filter ".git" -Force).Parent.FullName) #find all folders under cache path that are git repo roots
    foreach ($Repo in $AllGits) {
        cd $Repo #change into repo dir to allow git work
        & $GitPortable Restore * #Restore modified and missing files
        #search for extra files and delete them
        $RepoStatus = & $GitPortable Status #get status
        $UntrackedFilesLineStart = $($RepoStatus | Select-String 'Untracked files:').LineNumber #find start of extra files list
        $UntrackedFilesLineEnd = $($RepoStatus | Select-String 'nothing added to commit').LineNumber #find end of extra files list
        if (-not !$UntrackedFilesLineStart) {
            $FileList = $RepoStatus[$($UntrackedFilesLineStart + 1)..$($UntrackedFilesLineEnd - 3)] #offset by one because array starts at 0
            foreach ($File in $FileList) {
                Remove-Item $($Repo+"\"+$File.Trim())#delete each file
            }
        }
        #Perform final status check on repo and report if working tree is not clean
        $FinalCheck = & $GitPortable Status
        if (!$($FinalCheck | Select-String 'working tree clean')) {
            Write-Host "Still some cache errors. Screenshot error into ticket for further instructions`n$Repo`n==================================`n$($FinalCheck -join ("`n"))"
        } else {
            Write-Host "$Repo is clean."
        }
    }
#error cases!
} elseif ($GitSearch.Count -eq 0) {
    Write-Host "Git not found. Please download and extract Git Portable."
} elseif ($RTLSearch.Count -eq 0) {
    Write-Host "RT Launcher Settings not found. Have you tried to run the launcher and install yet?"
} elseif ($GitSearch.Count -gt 1) {
    Write-Host "Too many instances of git found. You should clean up!"
} elseif ($RTLSearch.Count -gt 1) {
    Write-Host "Too many instances of RT Launcher settings found. There can only be one!"
}

#Go back to original working directory
cd $StoreDIR
pause