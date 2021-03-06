param (
    [string]$GITPath,
    [string]$SettingsPath
)

$Drives = Get-PSDrive -PSProvider FileSystem #Get all possible drive letters

#Search for git-core/git.exe - this is to ensure there's a clean git-portable
#OR search in provided path for git.exe
$GitSearch = @()
Write-Host "Finding Git Portable..."
if (!$GITPath) {
    foreach ($Drive in $Drives) {
        $GitSearch += Get-ChildItem -Path $Drive.Root -Recurse -Filter "git.exe" -ErrorAction SilentlyContinue
    }
    $GitSearch = $GitSearch | ? {$_.Directory.BaseName -eq 'git-core'}
} else {
    $GitSearchTemp = Get-ChildItem -Path $GITPath -Filter "git.exe" -ErrorAction SilentlyContinue
    $GitSearch += $GitSearchTemp | ? {$_.Name -eq 'git.exe'} #ensure file is correct if specified
}

#Search for settings xml to get the cache path being used.
Write-Host "Finding RT Launcher..."
$RTLSearch = @()
if (!$SettingsPath) {
    foreach ($Drive in $Drives) {
        $RTLSearch += Get-ChildItem -Path $Drive.Root -Recurse -Filter "RtLauncherSettings.xml" -ErrorAction SilentlyContinue
    }
} else {
    $RTLSearchTemp = Get-ChildItem -Path $SettingsPath -Filter "RtLauncherSettings.xml" -ErrorAction SilentlyContinue
    $RTLSearch += $RTLSearchTemp | ? {$_.Name -eq 'RtLauncherSettings.xml'} #ensure file is correct if specified
}

$StoreDIR = $(pwd).Path

if ($GitSearch.Count -eq 1 -and $RTLSearch.Count -eq 1) {
    $GitPortable = $GitSearch[0].FullName #get full path to git-portable git.exe to call
    [xml]$RTLXML = Get-Content $($RTLSearch[0].FullName) #load xml
    $CachePath = $RTLXML.RogueTechLauncherSettings.CachePath #get cachepath
    Write-Host "Processing all repos in Cache: $CachePath"
    #Create full path to cachepath if not exist
    if (-not $(Test-Path $CachePath)) {
        New-Item -ItemType Directory -Name $(Split-Path $CachePath -Leaf) -Path $(Split-Path $CachePath)
    }
    $AllGits = @($(Get-ChildItem $CachePath -Recurse -Filter ".git" -Force).Parent.FullName) #find all folders under cache path that are git repo roots
    $CABXML = New-Object System.Xml.XmlDocument
    $CABURL = $($($($RTLXML.RogueTechLauncherSettings.CabDataGitRepoUrl -split ("\.git"))[0] -split ("github\.com")) -join ("raw.githubusercontent.com")) + "/master/CabRepos.xml"
    $CABXML.Load($CABURL) 
    $CABXML.CabRepoData.Repos.CabRepo | % {$_.name = $_.cacheSubPath; $_.cacheSubPath = "CabCache\"+$_.cacheSubPath}
    $GitRepoList = @(
        ([pscustomobject]@{
            name = "RogueData"
            cacheSubPath = "RogueData"
            repoUrl = "https://github.com/wmtorode/RogueLauncherData.git"
        }),
        ([pscustomobject]@{
            name = "RtCache"
            cacheSubPath = "RtCache"
            repoUrl = "https://github.com/BattletechModders/RogueTech.git"
        }),
        ([pscustomobject]@{
            name = "CabSupRepoData"
            cacheSubPath = "CabCache\CabSupRepoData"
            repoUrl = "https://github.com/BattletechModders/Community-Asset-Bundle-Data.git"
        })
    )
    $GitRepoList += $CABXML.CabRepoData.Repos.CabRepo
    $ReposList = $GitRepoList.name
    if (!$AllGits) {
        $MissingRepoList = @(Compare-Object @($ReposList + 1) @(1)) #adding fake data to output formatted data and list all repos as missing
    } else {
        $MissingRepoList = @(Compare-Object $ReposList $(Split-Path $AllGits -Leaf))
    }
    #Create CabCache folder if not exist
    if (-not $(Test-Path "$CachePath\CabCache")) {
        New-Item -ItemType Directory -Name $(Split-Path "$CachePath\CabCache" -Leaf) -Path $(Split-Path "$CachePath\CabCache")
    }
    if ($MissingRepoList.Count -gt 0) {
        Write-Host "Git repos missing. Purging target DIR and scratch installing."
        foreach ($MissingRepoName in $MissingRepoList.InputObject) {
            $MissingRepo = $GitRepoList | ? {$_.name -eq $MissingRepoName}
            Remove-Item -Path $($CachePath+$MissingRepo.cacheSubPath) -Recurse -Force -Filter "*" -ErrorAction SilentlyContinue
            cd $(Split-Path $($CachePath+$MissingRepo.cacheSubPath))
            Write-Host "Cloning $($MissingRepo.name). This may take a while..."
            Invoke-Expression "$GitPortable clone $($MissingRepo.repoUrl) $($MissingRepo.name)"
            Write-Host "$($MissingRepo.name) cloned."
        }
    }
    #Reget allgits after cloning done to validate.
    Write-Host "Doing validations..."
    $AllGits = @($(Get-ChildItem $CachePath -Recurse -Filter ".git" -Force).Parent.FullName) #find all folders under cache path that are git repo roots
    foreach ($Repo in $AllGits) {
        cd $Repo #change into repo dir to allow git work
        Write-Host "Starting on $Repo..."
        $RepoURL = $(& $GitPortable remote get-url origin) #capture repo's URL
        $RepoHEAD = $($(& $GitPortable remote show origin | Select-String "HEAD branch") -split (": "))[1]
        $FSCKErrs = $(& $GitPortable fsck --full 2>&1) #verify object packs, capture errors
        if ($FSCKErrs -ne $null) {
            Write-Host $FSCKErrs
            Write-Host "FSCK errors found. Resetting GIT"
            Remove-Item .git #purge old git
            & $GitPortable init #create blank git
            & $GitPortable remote add origin $RepoURL #relink to repo
        }
        Write-Host "Fetching latest repo"
        & $GitPortable fetch #fetch remote
        & $GitPortable reset --hard HEAD #reset to remote HEAD branch (usually origin/master, but who the fuck knows with github changing shit)
        & $GitPortable restore * #Restore modified and missing files
        #search for extra files/folders and delete them
        $RepoStatus = & $GitPortable status #get status
        $UntrackedFilesLineStart = $($RepoStatus | Select-String 'Untracked files:').LineNumber #find start of extra files list
        $UntrackedFilesLineEnd = $($RepoStatus | Select-String 'nothing added to commit').LineNumber #find end of extra files list
        if (-not !$UntrackedFilesLineStart) {
            $FileList = $RepoStatus[$($UntrackedFilesLineStart + 1)..$($UntrackedFilesLineEnd - 3)] #offset by one because array starts at 0
            foreach ($File in $FileList) {
                Remove-Item $($Repo+"\"+$File.Trim()) -Recurse -Force #delete each file
            }
        }
        #Perform final status check on repo and report if working tree is not clean
        $FinalCheck = & $GitPortable status
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
    Write-Host "RT Launcher Settings not found. Have you tried to run the launcher yet?"
} elseif ($GitSearch.Count -gt 1) {
    Write-Host "THERE CAN ONLY BE ONE: Too many instances of git.exe found. Ensure -GITPath only contains one instance."
} elseif ($RTLSearch.Count -gt 1) {
    Write-Host "THERE CAN ONLY BE ONE: Too many instances of RT Launcher Settings XML found. Ensure -SettingsPath only contains one instance."
}

#Go back to original working directory
cd $StoreDIR
pause