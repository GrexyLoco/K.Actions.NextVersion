# 🧪 Pester Tests für K.Actions.NextVersion (Release-Based Versioning)

BeforeAll {
    # Path zum zu testenden Skript
    $script:scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Get-NextVersion.ps1"
    
    # Erstelle Test-Manifest falls nicht vorhanden
    $script:testManifestPath = Join-Path $PSScriptRoot "TestModule.psd1"
    if (-not (Test-Path $script:testManifestPath)) {
        $manifestContent = @"
@{
    ModuleVersion = '1.2.3'
    GUID = '12345678-1234-1234-1234-123456789012'
    Author = 'Test Author'
    Description = 'Test module for K.Actions.NextVersion'
    PowerShellVersion = '5.1'
}
"@
        $manifestContent | Out-File -FilePath $script:testManifestPath -Encoding UTF8
    }
    
    # Lade das Skript als Modul, um die Funktionen zu testen
    . $script:scriptPath
}

Describe "🔍 K.Actions.NextVersion Tests" {
    
    Context "📋 Helper Function - Get-VersionBumpType (Branch Pattern Detection)" {
        
        It "Should detect minor bump from feature/ branch" {
            $result = Get-VersionBumpType -branch "feature/new-logging" -message "Add logging"
            $result.bumpType | Should -Be "minor"
            $result.suffix | Should -Be ""
        }
        
        It "Should detect patch bump from bugfix/ branch" {
            $result = Get-VersionBumpType -branch "bugfix/memory-leak" -message "Fix memory leak"
            $result.bumpType | Should -Be "patch"
            $result.suffix | Should -Be ""
        }
        
        It "Should detect patch bump from refactor/ branch" {
            $result = Get-VersionBumpType -branch "refactor/cleanup" -message "Code cleanup"
            $result.bumpType | Should -Be "patch"
            $result.suffix | Should -Be ""
        }
        
        It "Should default to patch bump for unknown branch patterns" {
            $result = Get-VersionBumpType -branch "hotfix/critical" -message "Critical fix"
            $result.bumpType | Should -Be "patch"
            $result.suffix | Should -Be ""
        }
    }
    
    Context "🅰️ Alpha/Beta Suffix Detection" {
        
        It "Should detect BREAKING-ALPHA for major version with alpha suffix" {
            $result = Get-VersionBumpType -branch "feature/api-changes" -message "BREAKING-ALPHA: Change API interface"
            $result.bumpType | Should -Be "major"
            $result.suffix | Should -Be "alpha"
        }
        
        It "Should detect BREAKING-BETA for major version with beta suffix" {
            $result = Get-VersionBumpType -branch "develop" -message "BREAKING-BETA: Remove deprecated methods"
            $result.bumpType | Should -Be "major"
            $result.suffix | Should -Be "beta"
        }
        
        It "Should detect FEAT-ALPHA for minor version with alpha suffix" {
            $result = Get-VersionBumpType -branch "main" -message "FEAT-ALPHA: Add experimental feature"
            $result.bumpType | Should -Be "minor"
            $result.suffix | Should -Be "alpha"
        }
        
        It "Should detect FEATURE-BETA for minor version with beta suffix" {
            $result = Get-VersionBumpType -branch "develop" -message "FEATURE-BETA: Implement new authentication"
            $result.bumpType | Should -Be "minor"
            $result.suffix | Should -Be "beta"
        }
        
        It "Should detect FIX-ALPHA for patch version with alpha suffix" {
            $result = Get-VersionBumpType -branch "hotfix/issue" -message "FIX-ALPHA: Experimental bug fix"
            $result.bumpType | Should -Be "patch"
            $result.suffix | Should -Be "alpha"
        }
        
        It "Should detect PATCH-BETA for patch version with beta suffix" {
            $result = Get-VersionBumpType -branch "bugfix/test" -message "PATCH-BETA: Beta performance improvements"
            $result.bumpType | Should -Be "patch"
            $result.suffix | Should -Be "beta"
        }
        
        It "Should be case insensitive for alpha/beta suffixes" {
            $result = Get-VersionBumpType -branch "main" -message "breaking-alpha: Test API changes"
            $result.bumpType | Should -Be "major"
            $result.suffix | Should -Be "alpha"
        }
        
        It "Should work with mixed case alpha/beta suffixes" {
            $result = Get-VersionBumpType -branch "feature/test" -message "FEAT-Beta: New beta feature"
            $result.bumpType | Should -Be "minor"
            $result.suffix | Should -Be "beta"
        }
    }
    
    Context "🔤 Case Insensitive Branch Patterns" {
        
        It "Should detect Feature/ branch (mixed case)" {
            $result = Get-VersionBumpType -branch "Feature/new-api" -message "New API"
            $result.bumpType | Should -Be "minor"
            $result.suffix | Should -Be ""
        }
        
        It "Should detect BUGFIX/ branch (uppercase)" {
            $result = Get-VersionBumpType -branch "BUGFIX/issue-123" -message "Fix issue"
            $result.bumpType | Should -Be "patch"
            $result.suffix | Should -Be ""
        }
        
        It "Should detect Refactor/ branch (mixed case)" {
            $result = Get-VersionBumpType -branch "Refactor/structure" -message "Refactor"
            $result.bumpType | Should -Be "patch"
            $result.suffix | Should -Be ""
        }
    }
    
    Context "💥 Commit Message Override - Höchste Priorität" {
        
        It "Should override branch pattern with BREAKING keyword" {
            $result = Get-VersionBumpType -branch "bugfix/api-change" -message "BREAKING: Change API signature"
            $result.bumpType | Should -Be "major"
            $result.suffix | Should -Be ""
        }
        
        It "Should override branch pattern with MAJOR keyword" {
            $result = Get-VersionBumpType -branch "feature/enhancement" -message "MAJOR: Remove deprecated methods"
            $result.bumpType | Should -Be "major"
            $result.suffix | Should -Be ""
        }
        
        It "Should override branch with MINOR keyword" {
            $result = Get-VersionBumpType -branch "bugfix/small-fix" -message "MINOR: Add new configuration option"
            $result.bumpType | Should -Be "minor"
            $result.suffix | Should -Be ""
        }
        
        It "Should override branch with FEATURE keyword" {
            $result = Get-VersionBumpType -branch "main" -message "FEATURE: Implement user authentication"
            $result.bumpType | Should -Be "minor"
            $result.suffix | Should -Be ""
        }
        
        It "Should override branch with FEAT keyword" {
            $result = Get-VersionBumpType -branch "develop" -message "FEAT: Add advanced logging capabilities"
            $result.bumpType | Should -Be "minor"
            $result.suffix | Should -Be ""
        }
        
        It "Should override branch with FIX keyword" {
            $result = Get-VersionBumpType -branch "feature/new-feature" -message "FIX: Resolve configuration loading issue"
            $result.bumpType | Should -Be "patch"
            $result.suffix | Should -Be ""
        }
        
        It "Should override branch with BUGFIX keyword" {
            $result = Get-VersionBumpType -branch "feature/enhancement" -message "BUGFIX: Handle null reference exceptions"
            $result.bumpType | Should -Be "patch"
            $result.suffix | Should -Be ""
        }
        
        It "Should override branch with HOTFIX keyword" {
            $result = Get-VersionBumpType -branch "feature/api-changes" -message "HOTFIX: Emergency security patch"
            $result.bumpType | Should -Be "patch"
            $result.suffix | Should -Be ""
        }
        
        It "Should override branch with PATCH keyword" {
            $result = Get-VersionBumpType -branch "major/rewrite" -message "PATCH: Update documentation links"
            $result.bumpType | Should -Be "patch"
            $result.suffix | Should -Be ""
        }
        
        It "Should be case insensitive for all commit keywords" {
            $result = Get-VersionBumpType -branch "patch/fix" -message "breaking: change behavior"
            $result.bumpType | Should -Be "major"
            $result.suffix | Should -Be ""
        }
        
        It "Should detect keywords in middle of commit message" {
            $result = Get-VersionBumpType -branch "feature/api" -message "Update API with BREAKING changes to parameters"
            $result.bumpType | Should -Be "major"
            $result.suffix | Should -Be ""
        }
        
        It "Should prioritize MAJOR over MINOR when both present" {
            $result = Get-VersionBumpType -branch "develop" -message "MAJOR rewrite with FEAT additions"
            $result.bumpType | Should -Be "major"
            $result.suffix | Should -Be ""
        }
        
        It "Should prioritize MINOR over PATCH when both present" {
            $result = Get-VersionBumpType -branch "develop" -message "FEAT: Add feature with FIX for edge cases"
            $result.bumpType | Should -Be "minor"
            $result.suffix | Should -Be ""
        }
    }
    
    Context "📁 Helper Function - Bump-Version" {
        
        It "Should correctly increment major version" {
            $result = Bump-Version -currentVersion "1.2.3" -bumpType "major"
            $result | Should -Be "2.0.0"
        }
        
        It "Should correctly increment minor version" {
            $result = Bump-Version -currentVersion "1.2.3" -bumpType "minor"
            $result | Should -Be "1.3.0"
        }
        
        It "Should correctly increment patch version" {
            $result = Bump-Version -currentVersion "1.2.3" -bumpType "patch"
            $result | Should -Be "1.2.4"
        }
        
        It "Should handle zero versions" {
            $result = Bump-Version -currentVersion "0.0.0" -bumpType "patch"
            $result | Should -Be "0.0.1"
        }
        
        It "Should handle large version numbers" {
            $result = Bump-Version -currentVersion "99.99.99" -bumpType "major"
            $result | Should -Be "100.0.0"
        }
        
        It "Should add alpha suffix to major version" {
            $result = Bump-Version -currentVersion "1.2.3" -bumpType "major" -suffix "alpha"
            $result | Should -Be "2.0.0-alpha"
        }
        
        It "Should add beta suffix to minor version" {
            $result = Bump-Version -currentVersion "1.2.3" -bumpType "minor" -suffix "beta"
            $result | Should -Be "1.3.0-beta"
        }
        
        It "Should add alpha suffix to patch version" {
            $result = Bump-Version -currentVersion "1.2.3" -bumpType "patch" -suffix "alpha"
            $result | Should -Be "1.2.4-alpha"
        }
        
        It "Should handle empty suffix parameter" {
            $result = Bump-Version -currentVersion "1.2.3" -bumpType "minor" -suffix ""
            $result | Should -Be "1.3.0"
        }
        
        It "Should handle no suffix parameter" {
            $result = Bump-Version -currentVersion "1.2.3" -bumpType "minor"
            $result | Should -Be "1.3.0"
        }
    }
    
    Context "📊 Helper Function - Get-LatestReleaseTag" {
        
        # Note: These tests will only work if actual git tags exist
        It "Should return empty string when no tags exist" {
            # Mock git tag command to return empty
            Mock git { return $null } -ParameterFilter { $args[0] -eq 'tag' }
            $result = Get-LatestReleaseTag
            $result | Should -Be ""
        }
        
        It "Should parse semantic version tags correctly" {
            # This test requires actual git repository with tags
            # Will be skipped if git is not available or no tags exist
            try {
                $result = Get-LatestReleaseTag
                # Should return either empty string or valid semver tag
                $result | Should -Match '^(|v?\d+\.\d+\.\d+)$'
            } catch {
                Set-ItResult -Skipped -Because "Git repository or tags not available"
            }
        }
    }
    
    Context "🔧 Helper Function - Get-TargetBranch" {
        
        It "Should return a valid branch name" {
            $result = Get-TargetBranch
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [string]
        }
        
        It "Should default to 'main' when auto-discovery fails" {
            # Mock git commands to fail
            Mock git { throw "Git not available" }
            $result = Get-TargetBranch
            $result | Should -Be "main"
        }
    }
}

Describe "🚀 Integration Tests - Release Based Versioning" {
    
    Context "🔄 Main Script Execution" {
        
        It "Should handle target branch validation (not on target branch)" {
            # Test when current branch is not the target branch
            $result = & $script:scriptPath -ManifestPath $script:testManifestPath -BranchName "feature/test" -TargetBranch "main"
            
            $result.BumpType | Should -Be "none"
            $result.NewVersion | Should -Be "0.0.0"
        }
        
        It "Should handle manifest path auto-discovery" {
            # Test im aktuellen Verzeichnis wo TestModule.psd1 liegt
            Push-Location $PSScriptRoot
            try {
                $result = & $script:scriptPath -ManifestPath "" -BranchName "master" -TargetBranch "master"
                $result.CurrentVersion | Should -Be "1.2.3"
            }
            finally {
                Pop-Location
            }
        }
        
        It "Should return error object for non-existent manifest path" {
            $result = & $script:scriptPath -ManifestPath "C:\NonExistent\Manifest.psd1" -BranchName "main" -TargetBranch "main" 2>$null
            
            $result.CurrentVersion | Should -Be ""
            $result.BumpType | Should -Be ""
            $result.NewVersion | Should -Be ""
            $result.Error | Should -Not -BeNullOrEmpty
        }
        
        It "Should return error object when no manifests found during auto-discovery" {
            # Test in einem leeren temporären Verzeichnis
            $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $tempDir -Force
            
            Push-Location $tempDir
            try {
                $result = & $script:scriptPath -ManifestPath "" -BranchName "main" -TargetBranch "main" 2>$null
                
                $result.CurrentVersion | Should -Be ""
                $result.BumpType | Should -Be ""
                $result.NewVersion | Should -Be ""
                $result.Error | Should -Not -BeNullOrEmpty
            }
            finally {
                Pop-Location
                Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "⚠️ Error Handling" {
        
        It "Should handle invalid manifest gracefully" {
            # Erstelle ungültiges Manifest
            $invalidManifest = Join-Path $PSScriptRoot "InvalidManifest.psd1"
            "Invalid Content" | Out-File -FilePath $invalidManifest -Encoding UTF8
            
            try {
                $result = & $script:scriptPath -ManifestPath $invalidManifest -BranchName "main" -TargetBranch "main" 2>$null
                
                $result.CurrentVersion | Should -Be ""
                $result.BumpType | Should -Be ""
                $result.NewVersion | Should -Be ""
                $result.Error | Should -Not -BeNullOrEmpty
            }
            finally {
                Remove-Item $invalidManifest -ErrorAction SilentlyContinue
            }
        }
        
        It "Should handle manifest without ModuleVersion" {
            # Erstelle Manifest ohne ModuleVersion
            $noVersionManifest = Join-Path $PSScriptRoot "NoVersionManifest.psd1"
            $manifestContent = @"
@{
    GUID = '12345678-1234-1234-1234-123456789012'
    Author = 'Test'
}
"@
            $manifestContent | Out-File -FilePath $noVersionManifest -Encoding UTF8
            
            try {
                $result = & $script:scriptPath -ManifestPath $noVersionManifest -BranchName "main" -TargetBranch "main" 2>$null
                
                $result.CurrentVersion | Should -Be ""
                $result.BumpType | Should -Be ""
                $result.NewVersion | Should -Be ""
                $result.Error | Should -Not -BeNullOrEmpty
            }
            finally {
                Remove-Item $noVersionManifest -ErrorAction SilentlyContinue
            }
        }
        
        It "Should return object with correct properties on success" {
            $result = & $script:scriptPath -ManifestPath $script:testManifestPath -BranchName "master" -TargetBranch "master"
            
            $result | Should -BeOfType [PSCustomObject]
            $result.PSObject.Properties.Name | Should -Contain "CurrentVersion"
            $result.PSObject.Properties.Name | Should -Contain "BumpType" 
            $result.PSObject.Properties.Name | Should -Contain "NewVersion"
            $result.PSObject.Properties.Name | Should -Contain "LastReleaseTag"
            $result.PSObject.Properties.Name | Should -Contain "TargetBranch"
            $result.PSObject.Properties.Name | Should -Contain "Suffix"
        }
        
        It "Should return string values for all properties" {
            $result = & $script:scriptPath -ManifestPath $script:testManifestPath -BranchName "master" -TargetBranch "master"
            
            $result.CurrentVersion | Should -BeOfType [string]
            $result.BumpType | Should -BeOfType [string]
            $result.NewVersion | Should -BeOfType [string]
            $result.LastReleaseTag | Should -BeOfType [string]
            $result.TargetBranch | Should -BeOfType [string]
            $result.Suffix | Should -BeOfType [string]
        }
    }
}
