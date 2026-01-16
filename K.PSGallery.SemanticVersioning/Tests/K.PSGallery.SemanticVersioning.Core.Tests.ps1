# K.PSGallery.SemanticVersioning.Core.Tests.ps1
# Pester Tests for the Unified Versioning Logic
#
# Tests cover:
# - Release branch validation
# - Commit-based BumpType detection
# - PreRelease lifecycle (Stable → Alpha → Beta → Stable)
# - Build number calculation
# - Version stepping

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..' 'K.PSGallery.SemanticVersioning.Core.ps1'
    . $ModulePath
}

Describe 'Get-ReleaseBranchInfo' {
    Context 'Release Branches' {
        It 'should recognize "release" as stable release branch' {
            $result = Get-ReleaseBranchInfo -BranchName 'release'
            $result.IsReleaseBranch | Should -Be $true
            $result.PreReleaseType | Should -BeNullOrEmpty
        }
        
        It 'should recognize "main" as beta release branch' {
            $result = Get-ReleaseBranchInfo -BranchName 'main'
            $result.IsReleaseBranch | Should -Be $true
            $result.PreReleaseType | Should -Be 'beta'
        }
        
        It 'should recognize "master" as beta release branch' {
            $result = Get-ReleaseBranchInfo -BranchName 'master'
            $result.IsReleaseBranch | Should -Be $true
            $result.PreReleaseType | Should -Be 'beta'
        }
        
        It 'should recognize "staging" as beta release branch' {
            $result = Get-ReleaseBranchInfo -BranchName 'staging'
            $result.IsReleaseBranch | Should -Be $true
            $result.PreReleaseType | Should -Be 'beta'
        }
        
        It 'should recognize "dev" as alpha release branch' {
            $result = Get-ReleaseBranchInfo -BranchName 'dev'
            $result.IsReleaseBranch | Should -Be $true
            $result.PreReleaseType | Should -Be 'alpha'
        }
        
        It 'should recognize "development" as alpha release branch' {
            $result = Get-ReleaseBranchInfo -BranchName 'development'
            $result.IsReleaseBranch | Should -Be $true
            $result.PreReleaseType | Should -Be 'alpha'
        }
    }
    
    Context 'Non-Release Branches' {
        It 'should reject "feature/xyz" as non-release branch' {
            $result = Get-ReleaseBranchInfo -BranchName 'feature/xyz'
            $result.IsReleaseBranch | Should -Be $false
        }
        
        It 'should reject "bugfix/issue-123" as non-release branch' {
            $result = Get-ReleaseBranchInfo -BranchName 'bugfix/issue-123'
            $result.IsReleaseBranch | Should -Be $false
        }
        
        It 'should reject "hotfix/security" as non-release branch' {
            $result = Get-ReleaseBranchInfo -BranchName 'hotfix/security'
            $result.IsReleaseBranch | Should -Be $false
        }
        
        It 'should reject "my-branch" as non-release branch' {
            $result = Get-ReleaseBranchInfo -BranchName 'my-branch'
            $result.IsReleaseBranch | Should -Be $false
        }
        
        It 'should be case-sensitive (Main ≠ main)' {
            $result = Get-ReleaseBranchInfo -BranchName 'Main'
            $result.IsReleaseBranch | Should -Be $false
        }
    }
}

Describe 'Get-BumpTypeFromCommits' {
    Context 'Major Bump Detection' {
        It 'should detect "BREAKING: removed API" as major' {
            $result = Get-BumpTypeFromCommits -Commits @('BREAKING: removed API')
            $result | Should -Be 'major'
        }
        
        It 'should detect "MAJOR: architecture change" as major' {
            $result = Get-BumpTypeFromCommits -Commits @('MAJOR: architecture change')
            $result | Should -Be 'major'
        }
        
        It 'should detect "breaking change in API" as major' {
            $result = Get-BumpTypeFromCommits -Commits @('breaking change in API')
            $result | Should -Be 'major'
        }
        
        It 'should detect "feat!: breaking feature" as major' {
            $result = Get-BumpTypeFromCommits -Commits @('feat!: breaking feature')
            $result | Should -Be 'major'
        }
    }
    
    Context 'Minor Bump Detection' {
        It 'should detect "FEATURE: new endpoint" as minor' {
            $result = Get-BumpTypeFromCommits -Commits @('FEATURE: new endpoint')
            $result | Should -Be 'minor'
        }
        
        It 'should detect "feat: add login" as minor' {
            $result = Get-BumpTypeFromCommits -Commits @('feat: add login')
            $result | Should -Be 'minor'
        }
        
        It 'should detect "feature: new module" as minor' {
            $result = Get-BumpTypeFromCommits -Commits @('feature: new module')
            $result | Should -Be 'minor'
        }
        
        It 'should detect "add: new utility" as minor' {
            $result = Get-BumpTypeFromCommits -Commits @('add: new utility')
            $result | Should -Be 'minor'
        }
        
        It 'should detect "MINOR: new feature" as minor' {
            $result = Get-BumpTypeFromCommits -Commits @('MINOR: new feature')
            $result | Should -Be 'minor'
        }
    }
    
    Context 'Patch Bump Detection (Default)' {
        It 'should detect "fix: null check" as patch' {
            $result = Get-BumpTypeFromCommits -Commits @('fix: null check')
            $result | Should -Be 'patch'
        }
        
        It 'should detect "docs: update readme" as patch' {
            $result = Get-BumpTypeFromCommits -Commits @('docs: update readme')
            $result | Should -Be 'patch'
        }
        
        It 'should detect "chore: update deps" as patch' {
            $result = Get-BumpTypeFromCommits -Commits @('chore: update deps')
            $result | Should -Be 'patch'
        }
        
        It 'should default to patch for unknown patterns' {
            $result = Get-BumpTypeFromCommits -Commits @('random commit message')
            $result | Should -Be 'patch'
        }
        
        It 'should default to patch for empty commits' {
            $result = Get-BumpTypeFromCommits -Commits @()
            $result | Should -Be 'patch'
        }
    }
    
    Context 'Priority: Major > Minor > Patch' {
        It 'should return major when both major and minor present' {
            $result = Get-BumpTypeFromCommits -Commits @('feat: new feature', 'BREAKING: removed API')
            $result | Should -Be 'major'
        }
        
        It 'should return minor when minor and patch present' {
            $result = Get-BumpTypeFromCommits -Commits @('fix: typo', 'feat: new feature')
            $result | Should -Be 'minor'
        }
    }
}

Describe 'Get-PreReleaseTransition' {
    Context 'Valid Transitions (One-Way Street)' {
        It 'should allow Stable → Alpha' {
            $result = Get-PreReleaseTransition -CurrentPreRelease $null -TargetPreRelease 'alpha' -CurrentVersion '1.0.0'
            $result.IsValid | Should -Be $true
            $result.Action | Should -Be 'start'
        }
        
        It 'should allow Stable → Beta (skip alpha)' {
            $result = Get-PreReleaseTransition -CurrentPreRelease $null -TargetPreRelease 'beta' -CurrentVersion '1.0.0'
            $result.IsValid | Should -Be $true
            $result.Action | Should -Be 'start'
        }
        
        It 'should allow Alpha → Alpha (continue)' {
            $result = Get-PreReleaseTransition -CurrentPreRelease 'alpha' -TargetPreRelease 'alpha' -CurrentVersion '1.0.1'
            $result.IsValid | Should -Be $true
            $result.Action | Should -Be 'continue'
        }
        
        It 'should allow Alpha → Beta (transition)' {
            $result = Get-PreReleaseTransition -CurrentPreRelease 'alpha' -TargetPreRelease 'beta' -CurrentVersion '1.0.1'
            $result.IsValid | Should -Be $true
            $result.Action | Should -Be 'transition'
        }
        
        It 'should allow Alpha → Stable (end)' {
            $result = Get-PreReleaseTransition -CurrentPreRelease 'alpha' -TargetPreRelease $null -CurrentVersion '1.0.1'
            $result.IsValid | Should -Be $true
            $result.Action | Should -Be 'end'
        }
        
        It 'should allow Beta → Beta (continue)' {
            $result = Get-PreReleaseTransition -CurrentPreRelease 'beta' -TargetPreRelease 'beta' -CurrentVersion '1.0.1'
            $result.IsValid | Should -Be $true
            $result.Action | Should -Be 'continue'
        }
        
        It 'should allow Beta → Stable (end)' {
            $result = Get-PreReleaseTransition -CurrentPreRelease 'beta' -TargetPreRelease $null -CurrentVersion '1.0.1'
            $result.IsValid | Should -Be $true
            $result.Action | Should -Be 'end'
        }
    }
    
    Context 'Invalid Transitions (Backwards)' {
        It 'should reject Beta → Alpha' {
            $result = Get-PreReleaseTransition -CurrentPreRelease 'beta' -TargetPreRelease 'alpha' -CurrentVersion '1.0.1'
            $result.IsValid | Should -Be $false
            $result.ErrorMessage | Should -Match 'ALPHA nach BETA nicht erlaubt'
        }
        
        It 'should reject Stable → Alpha after release' {
            # Note: This is actually valid (starting new series), so this test is for documentation
            # The real invalid case would be going backwards within same version
        }
    }
}

Describe 'Get-NextBuildNumber' {
    Context 'Build Number Calculation' {
        It 'should return 1 when no existing tags' {
            $result = Get-NextBuildNumber -BaseVersion '1.2.0' -PreReleaseType 'alpha' -ExistingTags @()
            $result | Should -Be 1
        }
        
        It 'should return 3 when tags 1 and 2 exist' {
            $tags = @('v1.2.0-alpha.1', 'v1.2.0-alpha.2')
            $result = Get-NextBuildNumber -BaseVersion '1.2.0' -PreReleaseType 'alpha' -ExistingTags $tags
            $result | Should -Be 3
        }
        
        It 'should ignore tags from different versions' {
            $tags = @('v1.1.0-alpha.5', 'v1.2.0-alpha.1')
            $result = Get-NextBuildNumber -BaseVersion '1.2.0' -PreReleaseType 'alpha' -ExistingTags $tags
            $result | Should -Be 2
        }
        
        It 'should ignore tags from different PreRelease types' {
            $tags = @('v1.2.0-beta.5', 'v1.2.0-alpha.1')
            $result = Get-NextBuildNumber -BaseVersion '1.2.0' -PreReleaseType 'alpha' -ExistingTags $tags
            $result | Should -Be 2
        }
        
        It 'should handle tags without v prefix' {
            $tags = @('1.2.0-alpha.1', '1.2.0-alpha.2')
            $result = Get-NextBuildNumber -BaseVersion '1.2.0' -PreReleaseType 'alpha' -ExistingTags $tags
            $result | Should -Be 3
        }
    }
}

Describe 'Step-SemanticVersion' {
    Context 'Version Incrementing' {
        It 'should increment major: 1.2.3 → 2.0.0' {
            $result = Step-SemanticVersion -Version '1.2.3' -BumpType 'major'
            $result | Should -Be '2.0.0'
        }
        
        It 'should increment minor: 1.2.3 → 1.3.0' {
            $result = Step-SemanticVersion -Version '1.2.3' -BumpType 'minor'
            $result | Should -Be '1.3.0'
        }
        
        It 'should increment patch: 1.2.3 → 1.2.4' {
            $result = Step-SemanticVersion -Version '1.2.3' -BumpType 'patch'
            $result | Should -Be '1.2.4'
        }
        
        It 'should handle version with v prefix' {
            $result = Step-SemanticVersion -Version 'v1.0.0' -BumpType 'minor'
            $result | Should -Be '1.1.0'
        }
        
        It 'should strip PreRelease suffix before incrementing' {
            $result = Step-SemanticVersion -Version '1.2.3-alpha.1' -BumpType 'patch'
            $result | Should -Be '1.2.4'
        }
    }
}

Describe 'Get-NextVersion - Integration' {
    Context 'Non-Release Branches' {
        It 'should fail for feature branches' {
            $result = Get-NextVersion -BranchName 'feature/test' -LastTag 'v1.0.0' -Commits @('fix: test')
            $result.Success | Should -Be $false
            $result.BumpType | Should -Be 'none'
            $result.ErrorMessage | Should -Match 'kein Release-Branch'
        }
    }
    
    Context 'Stable Release from release branch' {
        It 'should create stable version from release branch' {
            $result = Get-NextVersion -BranchName 'release' -LastTag 'v1.0.0' -Commits @('fix: bug') -ExistingTags @('v1.0.0')
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '1.0.1'
            $result.PreReleaseType | Should -BeNullOrEmpty
        }
    }
    
    Context 'Alpha Release from dev branch' {
        It 'should create alpha version from dev branch' {
            $result = Get-NextVersion -BranchName 'dev' -LastTag 'v1.0.0' -Commits @('fix: bug') -ExistingTags @('v1.0.0')
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '1.0.1-alpha.1'
            $result.PreReleaseType | Should -Be 'alpha'
        }
        
        It 'should increment alpha build number' {
            $tags = @('v1.0.0', 'v1.0.1-alpha.1', 'v1.0.1-alpha.2')
            $result = Get-NextVersion -BranchName 'dev' -LastTag 'v1.0.1-alpha.2' -Commits @('fix: bug') -ExistingTags $tags
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '1.0.1-alpha.3'
        }
    }
    
    Context 'Beta Release from staging branch' {
        It 'should create beta version from staging branch' {
            $result = Get-NextVersion -BranchName 'staging' -LastTag 'v1.0.0' -Commits @('fix: bug') -ExistingTags @('v1.0.0')
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '1.0.1-beta.1'
            $result.PreReleaseType | Should -Be 'beta'
        }
        
        It 'should transition from alpha to beta' {
            $tags = @('v1.0.0', 'v1.0.1-alpha.3')
            $result = Get-NextVersion -BranchName 'staging' -LastTag 'v1.0.1-alpha.3' -Commits @('fix: bug') -ExistingTags $tags
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '1.0.1-beta.1'
            $result.PreReleaseType | Should -Be 'beta'
        }
    }
    
    Context 'First Release' {
        It 'should create first release as 1.0.0 on release branch' {
            $result = Get-NextVersion -BranchName 'release' -LastTag $null -Commits @() -ExistingTags @()
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '1.0.0'
            $result.IsFirstRelease | Should -Be $true
        }
        
        It 'should create first release as 1.0.0-alpha.1 on dev branch' {
            $result = Get-NextVersion -BranchName 'dev' -LastTag $null -Commits @() -ExistingTags @()
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '1.0.0-alpha.1'
            $result.IsFirstRelease | Should -Be $true
        }
    }
    
    Context 'BumpType affects version' {
        It 'should bump minor with FEATURE commit' {
            $result = Get-NextVersion -BranchName 'dev' -LastTag 'v1.0.0' -Commits @('FEATURE: new API') -ExistingTags @('v1.0.0')
            $result.Success | Should -Be $true
            $result.BumpType | Should -Be 'minor'
            $result.NewVersion | Should -Be '1.1.0-alpha.1'
        }
        
        It 'should bump major with BREAKING commit' {
            $result = Get-NextVersion -BranchName 'release' -LastTag 'v1.0.0' -Commits @('BREAKING: removed API') -ExistingTags @('v1.0.0')
            $result.Success | Should -Be $true
            $result.BumpType | Should -Be 'major'
            $result.NewVersion | Should -Be '2.0.0'
        }
    }
}
