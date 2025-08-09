# Public entrypoint and internal helpers for NextVersion module
# All functions exported via NextVersion.psd1

function Get-ReleaseVersionBumpType {
	[CmdletBinding()]
	[OutputType([hashtable])]
	param (
		[string]$lastReleaseTag = '',
		[Parameter(Mandatory)]
		[string]$targetBranch
	)

	if ([string]::IsNullOrWhiteSpace($lastReleaseTag)) {
		$gitLogCmd = "git log --merges --oneline --format='%H|%s' $targetBranch"
	} else {
		$gitLogCmd = "git log --merges --oneline --format='%H|%s' ${lastReleaseTag}..$targetBranch"
	}

	try {
		$mergeCommits = Invoke-Expression $gitLogCmd 2>$null
		if (-not $mergeCommits) { return @{ bumpType = 'patch'; suffix = '' } }
	} catch {
		Write-Warning "Failed to execute git log: $($_.Exception.Message)"
		return @{ bumpType = 'patch'; suffix = '' }
	}

	$highestBump = 'none'
	$bumpPriority = @{ 'none' = 0; 'patch' = 1; 'minor' = 2; 'major' = 3 }
	$finalSuffix = ''

	foreach ($commit in $mergeCommits) {
		if ([string]::IsNullOrWhiteSpace($commit)) { continue }
		$parts = $commit -split '\|', 2
		if ($parts.Count -lt 2) { continue }
		$commitMessage = $parts[1]

		$branchName = ''
		if ($commitMessage -match "Merge (pull request #\d+ from |branch ')([^']+)") {
			$branchName = $matches[2]
		} elseif ($commitMessage -match "Merge branch '([^']+)'") {
			$branchName = $matches[1]
		}

		$mergeBumpResult = Get-VersionBumpType -branch $branchName -message $commitMessage
		$mergeBumpType = $mergeBumpResult.bumpType
		$mergeSuffix = $mergeBumpResult.suffix

		if ($bumpPriority[$mergeBumpType] -gt $bumpPriority[$highestBump]) {
			$highestBump = $mergeBumpType
			$finalSuffix = $mergeSuffix
		} elseif ($bumpPriority[$mergeBumpType] -eq $bumpPriority[$highestBump] -and $mergeSuffix) {
			$finalSuffix = $mergeSuffix
		}
	}

	if ($highestBump -eq 'none') { return @{ bumpType = 'patch'; suffix = '' } }
	return @{ bumpType = $highestBump; suffix = $finalSuffix }
}

function Get-LatestReleaseTag {
	[CmdletBinding()]
	[OutputType([string])]
	param ()

	try {
		$allTags = git tag -l 2>$null
		if (-not $allTags) { return '' }
		$semverTags = $allTags | Where-Object { $_ -match '^v?\d+\.\d+\.\d+$' }
		if (-not $semverTags) { return '' }

		$latestTag = ''
		$latestVersion = [Version]'0.0.0'
		foreach ($tag in $semverTags) {
			$versionString = $tag -replace '^v',''
			try {
				$version = [Version]$versionString
				if ($version -gt $latestVersion) { $latestVersion = $version; $latestTag = $tag }
			} catch { continue }
		}
		return $latestTag
	} catch {
		Write-Warning "Failed to retrieve git tags: $($_.Exception.Message)"
		return ''
	}
}

function Get-TargetBranch {
	[CmdletBinding()]
	[OutputType([string])]
	param ()

	try {
		$defaultBranch = git symbolic-ref refs/remotes/origin/HEAD 2>$null
		if ($defaultBranch) { return ($defaultBranch -split '/')[ -1 ] }

		$commonBranches = @('main','master','release','develop')
		$availableBranches = git branch -r 2>$null | ForEach-Object { ($_ -replace '^\s*origin/','').Trim() }
		foreach ($b in $commonBranches) { if ($availableBranches -contains $b) { return $b } }

		$current = git branch --show-current 2>$null
		if ($current -and $current -in @('main','master','release')) { return $current }
		return 'main'
	} catch {
		return 'main'
	}
}

function Get-VersionBumpType {
	[CmdletBinding()]
	[OutputType([hashtable])]
	param (
		[Parameter(Mandatory)][string]$branch,
		[Parameter(Mandatory)][string]$message
	)

	if ($message -match '(?i)BREAKING|MAJOR') {
		if ($message -match '(?i)BREAKING-ALPHA|MAJOR-ALPHA') { return @{ bumpType = 'major'; suffix = 'alpha' } }
		elseif ($message -match '(?i)BREAKING-BETA|MAJOR-BETA') { return @{ bumpType = 'major'; suffix = 'beta' } }
		else { return @{ bumpType = 'major'; suffix = '' } }
	}

	if ($message -match '(?i)MINOR|FEATURE|FEAT') {
		if ($message -match '(?i)MINOR-ALPHA|FEATURE-ALPHA|FEAT-ALPHA') { return @{ bumpType = 'minor'; suffix = 'alpha' } }
		elseif ($message -match '(?i)MINOR-BETA|FEATURE-BETA|FEAT-BETA') { return @{ bumpType = 'minor'; suffix = 'beta' } }
		else { return @{ bumpType = 'minor'; suffix = '' } }
	}

	if ($message -match '(?i)PATCH|FIX|BUGFIX|HOTFIX') {
		if ($message -match '(?i)PATCH-ALPHA|FIX-ALPHA|BUGFIX-ALPHA|HOTFIX-ALPHA') { return @{ bumpType = 'patch'; suffix = 'alpha' } }
		elseif ($message -match '(?i)PATCH-BETA|FIX-BETA|BUGFIX-BETA|HOTFIX-BETA') { return @{ bumpType = 'patch'; suffix = 'beta' } }
		else { return @{ bumpType = 'patch'; suffix = '' } }
	}

	switch -regex ($branch) {
		'(?i)^feature/' { return @{ bumpType = 'minor'; suffix = '' } }
		'(?i)^bugfix/'  { return @{ bumpType = 'patch'; suffix = '' } }
		'(?i)^refactor/'{ return @{ bumpType = 'patch'; suffix = '' } }
		default         { return @{ bumpType = 'patch'; suffix = '' } }
	}
}

function Update-Version {
	[CmdletBinding()]
	[OutputType([string])]
	param (
		[Parameter(Mandatory)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$currentVersion,
		[Parameter(Mandatory)][ValidateSet('major','minor','patch')][string]$bumpType,
		[ValidateSet('','alpha','beta')][string]$suffix = ''
	)

	$parts = $currentVersion -split '\.'
	$major = [int]$parts[0]
	$minor = [int]$parts[1]
	$patch = [int]$parts[2]

	switch ($bumpType) {
		'major' { $newVersion = "$(($major+1)).0.0" }
		'minor' { $newVersion = "$major.$(($minor+1)).0" }
		'patch' { $newVersion = "$major.$minor.$(($patch+1))" }
		default { throw "Invalid bump type: $bumpType" }
	}

	if ($suffix) { $newVersion = "$newVersion-$suffix" }
	return $newVersion
}

function Get-NextVersion {
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[string]$ManifestPath = '',
		[string]$BranchName = $env:GITHUB_REF_NAME,
		[string]$CommitMessage = '',
		[string]$TargetBranch = ''
	)

	try {
		if ([string]::IsNullOrWhiteSpace($TargetBranch)) {
			$TargetBranch = Get-TargetBranch
		}

		if ($BranchName -ne $TargetBranch) {
			return [pscustomobject]@{
				CurrentVersion = '0.0.0'
				BumpType       = 'none'
				NewVersion     = '0.0.0'
				Message        = 'Not on target branch for release'
				LastReleaseTag = ''
				TargetBranch   = $TargetBranch
				Suffix         = ''
			}
		}

		if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
			$manifestFiles = Get-ChildItem -Recurse -Filter '*.psd1' -ErrorAction SilentlyContinue
			if ($manifestFiles.Count -eq 0) { throw 'No PowerShell manifest files (.psd1) found. Provide -ManifestPath.' }
			$ManifestPath = $manifestFiles[0].FullName
		}
		if (-not (Test-Path -Path $ManifestPath -PathType Leaf)) { throw "Manifest not found: $ManifestPath" }

		$manifest = Import-PowerShellDataFile -Path $ManifestPath
		if (-not $manifest.ModuleVersion) { throw "ModuleVersion not found in manifest: $ManifestPath" }
		$currentVersion = [string]$manifest.ModuleVersion

		$latestReleaseTag = Get-LatestReleaseTag
		if ([string]::IsNullOrWhiteSpace($latestReleaseTag)) {
			$bumpResult = Get-ReleaseVersionBumpType -lastReleaseTag '' -targetBranch $TargetBranch
			$bumpType = $bumpResult.bumpType; $suffix = $bumpResult.suffix
			$newVersion = Update-Version -currentVersion '0.0.0' -bumpType $bumpType -suffix $suffix
		} else {
			$bumpResult = Get-ReleaseVersionBumpType -lastReleaseTag $latestReleaseTag -targetBranch $TargetBranch
			$bumpType = $bumpResult.bumpType; $suffix = $bumpResult.suffix
			$newVersion = Update-Version -currentVersion $currentVersion -bumpType $bumpType -suffix $suffix
		}

		return [pscustomobject]@{
			CurrentVersion = $currentVersion
			BumpType       = $bumpType
			NewVersion     = $newVersion
			LastReleaseTag = $latestReleaseTag
			TargetBranch   = $TargetBranch
			Suffix         = $suffix
		}
	} catch {
		Write-Error "Failed to determine next version: $($_.Exception.Message)"
		return [pscustomobject]@{
			CurrentVersion = ''
			BumpType       = ''
			NewVersion     = ''
			LastReleaseTag = ''
			TargetBranch   = ''
			Suffix         = ''
			Error          = $_.Exception.Message
		}
	}
}
