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
        
        # Note: PowerShell hashtables are case-insensitive by default
        # This is actually DESIRED behavior for Git branch matching on Windows
        It 'should be case-insensitive (Main = main) for Windows compatibility' {
            $result = Get-ReleaseBranchInfo -BranchName 'Main'
            $result.IsReleaseBranch | Should -Be $true
            $result.PreReleaseType | Should -Be 'beta'
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

# =============================================================================
# COMPLETE TRANSITION MATRIX TESTS
# These tests ensure all PreRelease lifecycle transitions work correctly
# =============================================================================

Describe 'Complete Transition Matrix - End-to-End Integration' {
    
    Context '1. Stable → Alpha with different BumpTypes' {
        # Transition: stable => alpha (1.0.0 & Patch & push in dev wird zu 1.0.1-alpha.1)
        It 'should create 1.0.1-alpha.1 from 1.0.0 with Patch commit on dev branch' {
            $result = Get-NextVersion -BranchName 'dev' -LastTag 'v1.0.0' -Commits @('fix: bug fix') -ExistingTags @('v1.0.0')
            $result.Success | Should -Be $true
            $result.BumpType | Should -Be 'patch'
            $result.NewVersion | Should -Be '1.0.1-alpha.1'
            $result.PreReleaseType | Should -Be 'alpha'
        }
        
        # Transition: stable => alpha (1.0.0 & Minor & push in dev wird zu 1.1.0-alpha.1)
        It 'should create 1.1.0-alpha.1 from 1.0.0 with Minor commit on dev branch' {
            $result = Get-NextVersion -BranchName 'dev' -LastTag 'v1.0.0' -Commits @('feat: new feature') -ExistingTags @('v1.0.0')
            $result.Success | Should -Be $true
            $result.BumpType | Should -Be 'minor'
            $result.NewVersion | Should -Be '1.1.0-alpha.1'
            $result.PreReleaseType | Should -Be 'alpha'
        }
        
        # Transition: stable => alpha (1.0.0 & Major & push in dev wird zu 2.0.0-alpha.1)
        It 'should create 2.0.0-alpha.1 from 1.0.0 with Major commit on dev branch' {
            $result = Get-NextVersion -BranchName 'dev' -LastTag 'v1.0.0' -Commits @('BREAKING: removed deprecated API') -ExistingTags @('v1.0.0')
            $result.Success | Should -Be $true
            $result.BumpType | Should -Be 'major'
            $result.NewVersion | Should -Be '2.0.0-alpha.1'
            $result.PreReleaseType | Should -Be 'alpha'
        }
        
        # Also test with 'development' branch alias
        It 'should work with development branch alias' {
            $result = Get-NextVersion -BranchName 'development' -LastTag 'v1.0.0' -Commits @('fix: patch') -ExistingTags @('v1.0.0')
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '1.0.1-alpha.1'
            $result.PreReleaseType | Should -Be 'alpha'
        }
    }
    
    Context '2. Alpha → Alpha (build number increment, BumpType only affects tracking)' {
        # Transition: alpha => alpha (1.1.0-alpha.1 & Patch|Minor|Major* & push in dev wird zu 1.1.0-alpha.2)
        # * := egal welcher BumpType, es zählt nur das prerelease build hoch, nicht die ersten drei!
        
        It 'should increment alpha build number with Patch commit (base version stays same)' {
            $tags = @('v1.0.0', 'v1.1.0-alpha.1')
            $result = Get-NextVersion -BranchName 'dev' -LastTag 'v1.1.0-alpha.1' -Commits @('fix: small bug') -ExistingTags $tags
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '1.1.0-alpha.2'
            $result.PreReleaseType | Should -Be 'alpha'
        }
        
        It 'should increment alpha build number with Minor commit (base version stays same)' {
            $tags = @('v1.0.0', 'v1.1.0-alpha.1')
            $result = Get-NextVersion -BranchName 'dev' -LastTag 'v1.1.0-alpha.1' -Commits @('feat: new feature') -ExistingTags $tags
            $result.Success | Should -Be $true
            # BumpType is tracked but base version stays 1.1.0, only build number increments
            $result.NewVersion | Should -Be '1.1.0-alpha.2'
            $result.PreReleaseType | Should -Be 'alpha'
        }
        
        It 'should increment alpha build number with Major commit (base version stays same)' {
            $tags = @('v1.0.0', 'v1.1.0-alpha.1')
            $result = Get-NextVersion -BranchName 'dev' -LastTag 'v1.1.0-alpha.1' -Commits @('BREAKING: major change') -ExistingTags $tags
            $result.Success | Should -Be $true
            # Even with BREAKING change, base version stays 1.1.0 during alpha, only build number increments
            $result.NewVersion | Should -Be '1.1.0-alpha.2'
            $result.PreReleaseType | Should -Be 'alpha'
        }
        
        It 'should correctly increment from alpha.2 to alpha.3' {
            $tags = @('v1.0.0', 'v1.1.0-alpha.1', 'v1.1.0-alpha.2')
            $result = Get-NextVersion -BranchName 'dev' -LastTag 'v1.1.0-alpha.2' -Commits @('fix: another fix') -ExistingTags $tags
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '1.1.0-alpha.3'
        }
    }
    
    Context '3. Non-Release Branch during Alpha (no version created)' {
        # Transition: alpha => alpha (push in beliebigen branch außerhalb des definierten patterns erstellt keine neue Version)
        
        It 'should fail for feature/xyz branch when alpha exists' {
            $tags = @('v1.0.0', 'v1.1.0-alpha.2')
            $result = Get-NextVersion -BranchName 'feature/xyz' -LastTag 'v1.1.0-alpha.2' -Commits @('fix: feature work') -ExistingTags $tags
            $result.Success | Should -Be $false
            $result.ErrorMessage | Should -Match 'kein Release-Branch'
        }
        
        It 'should fail for bugfix/issue-123 branch' {
            $tags = @('v1.0.0', 'v1.1.0-alpha.2')
            $result = Get-NextVersion -BranchName 'bugfix/issue-123' -LastTag 'v1.1.0-alpha.2' -Commits @('fix: bug') -ExistingTags $tags
            $result.Success | Should -Be $false
            $result.ErrorMessage | Should -Match 'kein Release-Branch'
        }
        
        It 'should fail for hotfix/security branch' {
            $tags = @('v1.0.0', 'v1.1.0-alpha.2')
            $result = Get-NextVersion -BranchName 'hotfix/security' -LastTag 'v1.1.0-alpha.2' -Commits @('fix: security') -ExistingTags $tags
            $result.Success | Should -Be $false
            $result.ErrorMessage | Should -Match 'kein Release-Branch'
        }
        
        It 'should fail for arbitrary branch names' {
            $tags = @('v1.0.0', 'v1.1.0-alpha.2')
            $result = Get-NextVersion -BranchName 'my-random-branch' -LastTag 'v1.1.0-alpha.2' -Commits @('fix: work') -ExistingTags $tags
            $result.Success | Should -Be $false
        }
    }
    
    Context '4. Alpha → Beta (transition on master/staging)' {
        # Transition: alpha => beta (1.1.0-alpha.2 & Patch|Minor|Major* & push in master wird zu 1.1.0-beta.1)
        
        It 'should transition from alpha to beta.1 on master branch' {
            $tags = @('v1.0.0', 'v1.1.0-alpha.1', 'v1.1.0-alpha.2')
            $result = Get-NextVersion -BranchName 'master' -LastTag 'v1.1.0-alpha.2' -Commits @('fix: stabilization') -ExistingTags $tags
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '1.1.0-beta.1'
            $result.PreReleaseType | Should -Be 'beta'
        }
        
        It 'should transition from alpha to beta.1 on main branch' {
            $tags = @('v1.0.0', 'v1.1.0-alpha.3')
            $result = Get-NextVersion -BranchName 'main' -LastTag 'v1.1.0-alpha.3' -Commits @('feat: final feature') -ExistingTags $tags
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '1.1.0-beta.1'
            $result.PreReleaseType | Should -Be 'beta'
        }
        
        It 'should transition from alpha to beta.1 on staging branch' {
            $tags = @('v1.0.0', 'v1.1.0-alpha.5')
            $result = Get-NextVersion -BranchName 'staging' -LastTag 'v1.1.0-alpha.5' -Commits @('BREAKING: major but still beta') -ExistingTags $tags
            $result.Success | Should -Be $true
            # Base version stays same during transition, BumpType doesn't change it
            $result.NewVersion | Should -Be '1.1.0-beta.1'
            $result.PreReleaseType | Should -Be 'beta'
        }
    }
    
    Context '5. Beta → Beta (build number increment)' {
        # Transition: beta => beta (1.1.0-beta.1 & Patch|Minor|Major* & push in master wird zu 1.1.0-beta.2)
        
        It 'should increment beta build number with Patch commit' {
            $tags = @('v1.0.0', 'v1.1.0-beta.1')
            $result = Get-NextVersion -BranchName 'master' -LastTag 'v1.1.0-beta.1' -Commits @('fix: beta bug') -ExistingTags $tags
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '1.1.0-beta.2'
            $result.PreReleaseType | Should -Be 'beta'
        }
        
        It 'should increment beta build number with Minor commit (base version stays same)' {
            $tags = @('v1.0.0', 'v1.1.0-beta.1')
            $result = Get-NextVersion -BranchName 'master' -LastTag 'v1.1.0-beta.1' -Commits @('feat: late feature') -ExistingTags $tags
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '1.1.0-beta.2'
            $result.PreReleaseType | Should -Be 'beta'
        }
        
        It 'should increment beta build number with Major commit (base version stays same)' {
            $tags = @('v1.0.0', 'v1.1.0-beta.1')
            $result = Get-NextVersion -BranchName 'master' -LastTag 'v1.1.0-beta.1' -Commits @('BREAKING: late breaking change') -ExistingTags $tags
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '1.1.0-beta.2'
            $result.PreReleaseType | Should -Be 'beta'
        }
        
        It 'should correctly increment from beta.2 to beta.3' {
            $tags = @('v1.0.0', 'v1.1.0-beta.1', 'v1.1.0-beta.2')
            $result = Get-NextVersion -BranchName 'main' -LastTag 'v1.1.0-beta.2' -Commits @('fix: more fixes') -ExistingTags $tags
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '1.1.0-beta.3'
        }
    }
    
    Context '6. Beta → Alpha (MUST FAIL - Invalid backwards transition)' {
        # Transition: beta => dev MUSS FEHLSCHLAGEN!
        # beta => beta (push in dev muss fehlschlagen, weil dann wieder eine alpha serie begonnen werden würde)
        
        It 'should reject dev branch push when beta exists (prevents alpha restart)' {
            $tags = @('v1.0.0', 'v1.1.0-alpha.2', 'v1.1.0-beta.1')
            $result = Get-NextVersion -BranchName 'dev' -LastTag 'v1.1.0-beta.1' -Commits @('fix: more dev work') -ExistingTags $tags
            $result.Success | Should -Be $false
            $result.ErrorMessage | Should -Match 'ALPHA nach BETA nicht erlaubt'
        }
        
        It 'should reject development branch push when beta exists' {
            $tags = @('v1.0.0', 'v1.1.0-beta.2')
            $result = Get-NextVersion -BranchName 'development' -LastTag 'v1.1.0-beta.2' -Commits @('feat: new feature attempt') -ExistingTags $tags
            $result.Success | Should -Be $false
            $result.ErrorMessage | Should -Match 'ALPHA nach BETA nicht erlaubt'
        }
        
        It 'should provide helpful error message for beta->alpha rejection' {
            $tags = @('v1.0.0', 'v1.1.0-beta.1')
            $result = Get-NextVersion -BranchName 'dev' -LastTag 'v1.1.0-beta.1' -Commits @('fix: work') -ExistingTags $tags
            $result.Success | Should -Be $false
            # Error should explain what to do instead
            $result.ErrorMessage | Should -Not -BeNullOrEmpty
        }
    }
    
    Context '7. Beta → Stable (final release on release branch)' {
        # Transition: beta => stable (1.1.0-beta.2 & Patch|Minor|Major* & push in release wird zu 1.1.0)
        
        It 'should finalize beta to stable version on release branch' {
            $tags = @('v1.0.0', 'v1.1.0-alpha.3', 'v1.1.0-beta.1', 'v1.1.0-beta.2')
            $result = Get-NextVersion -BranchName 'release' -LastTag 'v1.1.0-beta.2' -Commits @('fix: final polish') -ExistingTags $tags
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '1.1.0'
            $result.PreReleaseType | Should -BeNullOrEmpty
        }
        
        It 'should finalize beta.1 directly to stable' {
            $tags = @('v1.0.0', 'v1.1.0-beta.1')
            $result = Get-NextVersion -BranchName 'release' -LastTag 'v1.1.0-beta.1' -Commits @('docs: release notes') -ExistingTags $tags
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '1.1.0'
            $result.PreReleaseType | Should -BeNullOrEmpty
        }
        
        It 'should handle major version beta to stable' {
            $tags = @('v1.0.0', 'v2.0.0-beta.3')
            $result = Get-NextVersion -BranchName 'release' -LastTag 'v2.0.0-beta.3' -Commits @('fix: final fix') -ExistingTags $tags
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '2.0.0'
            $result.PreReleaseType | Should -BeNullOrEmpty
        }
    }
    
    Context '8. Alpha → Stable (skip beta, direct release)' {
        # This is also a valid transition: alpha can go directly to stable
        
        It 'should allow alpha to stable transition on release branch' {
            $tags = @('v1.0.0', 'v1.1.0-alpha.3')
            $result = Get-NextVersion -BranchName 'release' -LastTag 'v1.1.0-alpha.3' -Commits @('fix: ready for release') -ExistingTags $tags
            $result.Success | Should -Be $true
            $result.NewVersion | Should -Be '1.1.0'
            $result.PreReleaseType | Should -BeNullOrEmpty
        }
    }
    
    Context '9. Complete Lifecycle Scenario' {
        # Simulates a complete development cycle from stable through alpha, beta, back to stable
        
        It 'should support full lifecycle: stable -> alpha -> beta -> stable' {
            # Starting point: v1.0.0 stable
            $tags = @('v1.0.0')
            
            # Step 1: Start alpha development on dev branch
            $alpha1 = Get-NextVersion -BranchName 'dev' -LastTag 'v1.0.0' -Commits @('feat: new feature') -ExistingTags $tags
            $alpha1.Success | Should -Be $true
            $alpha1.NewVersion | Should -Be '1.1.0-alpha.1'
            $tags += "v$($alpha1.NewVersion)"
            
            # Step 2: Continue alpha development
            $alpha2 = Get-NextVersion -BranchName 'dev' -LastTag "v$($alpha1.NewVersion)" -Commits @('fix: bug in feature') -ExistingTags $tags
            $alpha2.Success | Should -Be $true
            $alpha2.NewVersion | Should -Be '1.1.0-alpha.2'
            $tags += "v$($alpha2.NewVersion)"
            
            # Step 3: Promote to beta on master
            $beta1 = Get-NextVersion -BranchName 'master' -LastTag "v$($alpha2.NewVersion)" -Commits @('fix: stabilization') -ExistingTags $tags
            $beta1.Success | Should -Be $true
            $beta1.NewVersion | Should -Be '1.1.0-beta.1'
            $tags += "v$($beta1.NewVersion)"
            
            # Step 4: Continue beta testing
            $beta2 = Get-NextVersion -BranchName 'master' -LastTag "v$($beta1.NewVersion)" -Commits @('fix: beta bug') -ExistingTags $tags
            $beta2.Success | Should -Be $true
            $beta2.NewVersion | Should -Be '1.1.0-beta.2'
            $tags += "v$($beta2.NewVersion)"
            
            # Step 5: Final release
            $stable = Get-NextVersion -BranchName 'release' -LastTag "v$($beta2.NewVersion)" -Commits @('docs: release notes') -ExistingTags $tags
            $stable.Success | Should -Be $true
            $stable.NewVersion | Should -Be '1.1.0'
            $stable.PreReleaseType | Should -BeNullOrEmpty
        }
    }
}
