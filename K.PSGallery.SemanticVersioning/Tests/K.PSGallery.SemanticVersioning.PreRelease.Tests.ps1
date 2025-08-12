BeforeAll {
    # Import module with full path to avoid conflicts
    $ModulePath = Join-Path $PSScriptRoot ".." "K.PSGallery.SemanticVersioning.psd1"
    Import-Module $ModulePath -Force -Global
    
    # Mock logging functions to prevent output during tests
    function Write-SafeInfoLog { param($Message, $Context) }
    function Write-SafeDebugLog { param($Message, $Context) }
    function Write-SafeErrorLog { param($Message, $Context) }
    function Write-SafeWarningLog { param($Message, $Context) }
    function Write-SafeTaskSuccessLog { param($Message, $Context) }
    
    # Create test manifest for consistent testing
    $TestManifestPath = Join-Path $TestDrive "TestModule.psd1"
    @"
@{
    ModuleVersion = '1.0.0'
    GUID = '12345678-1234-1234-1234-123456789012'
    Author = 'Test Author'
    Description = 'Test Module for Pre-Release Testing'
}
"@ | Set-Content -Path $TestManifestPath
}

AfterAll {
    # Clean up module
    Remove-Module K.PSGallery.SemanticVersioning -Force -ErrorAction SilentlyContinue
}

Describe "Pre-Release Detection from Commit Messages" {
    Context "Get-PreReleaseSuffixFromCommits" {
        It "Should detect alpha suffix from commit keywords" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Mock -CommandName "git" -MockWith {
                    if ($args[0] -eq "log") {
                        return @(
                            "feat-alpha: Add new experimental feature",
                            "fix: Normal bug fix",
                            "docs: Update documentation"
                        )
                    }
                    return @()
                }
                
                $result = Get-PreReleaseSuffixFromCommits
                $result | Should -Be "alpha"
            }
        }
        
        It "Should detect beta suffix from commit keywords" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Mock -CommandName "git" -MockWith {
                    if ($args[0] -eq "log") {
                        return @(
                            "feature-beta: New feature in beta",
                            "breaking-beta: Breaking change in beta"
                        )
                    }
                    return @()
                }
                
                $result = Get-PreReleaseSuffixFromCommits
                $result | Should -Be "beta"
            }
        }
        
        It "Should detect various keyword combinations with suffixes" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                $testCases = @(
                    @{ Keywords = @("BREAKING-ALPHA: Major change"); Expected = "alpha" },
                    @{ Keywords = @("MAJOR-BETA: Breaking update"); Expected = "beta" },
                    @{ Keywords = @("FEATURE-ALPHA: New feature"); Expected = "alpha" },
                    @{ Keywords = @("MINOR-BETA: Minor update"); Expected = "beta" },
                    @{ Keywords = @("FEAT-ALPHA: Short form"); Expected = "alpha" },
                    @{ Keywords = @("PATCH-BETA: Patch with beta"); Expected = "beta" },
                    @{ Keywords = @("FIX-ALPHA: Bug fix alpha"); Expected = "alpha" },
                    @{ Keywords = @("BUGFIX-BETA: Bug fix beta"); Expected = "beta" },
                    @{ Keywords = @("HOTFIX-ALPHA: Hotfix alpha"); Expected = "alpha" }
                )
                
                foreach ($testCase in $testCases) {
                    Mock -CommandName "git" -MockWith {
                        if ($args[0] -eq "log") { return $testCase.Keywords }
                        return @()
                    }
                    
                    $result = Get-PreReleaseSuffixFromCommits
                    $result | Should -Be $testCase.Expected -Because "Should detect $($testCase.Expected) from: $($testCase.Keywords -join ', ')"
                }
            }
        }
        
        It "Should return null for standard commit messages" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Mock -CommandName "git" -MockWith {
                    if ($args[0] -eq "log") {
                        return @(
                            "feat: Add new feature",
                            "fix: Bug fix",
                            "breaking: Breaking change",
                            "major: Major update"
                        )
                    }
                    return @()
                }
                
                $result = Get-PreReleaseSuffixFromCommits
                $result | Should -BeNullOrEmpty
            }
        }
        
        It "Should handle first releases (no LastReleaseTag)" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Mock -CommandName "git" -MockWith {
                    if ($args[0] -eq "log" -and $args[1] -eq "--oneline" -and $args[2] -eq "--all") {
                        return @("feat-alpha: Initial feature")
                    }
                    return @()
                }
                
                $result = Get-PreReleaseSuffixFromCommits -LastReleaseTag $null
                $result | Should -Be "alpha"
            }
        }
        
        It "Should handle commits since last release" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Mock -CommandName "git" -MockWith {
                    if ($args[0] -eq "log" -and $args[1] -eq "v1.0.0..HEAD") {
                        return @("feature-beta: New beta feature")
                    }
                    return @()
                }
                
                $result = Get-PreReleaseSuffixFromCommits -LastReleaseTag "v1.0.0"
                $result | Should -Be "beta"
            }
        }
        
        It "Should return first found prerelease suffix if multiple exist" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Mock -CommandName "git" -MockWith {
                    if ($args[0] -eq "log") {
                        return @(
                            "feat-alpha: First feature",
                            "fix-beta: Beta fix", 
                            "patch-alpha: Another alpha"
                        )
                    }
                    return @()
                }
                
                $result = Get-PreReleaseSuffixFromCommits
                $result | Should -Be "alpha"  # Should return first match
            }
        }
        
        It "Should handle git errors gracefully" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Mock -CommandName "git" -MockWith { throw "Git not found" }
                
                $result = Get-PreReleaseSuffixFromCommits
                $result | Should -BeNullOrEmpty
            }
        }
    }
}

Describe "Pre-Release Suffix Application" {
    Context "Add-PreReleaseSuffix" {
        It "Should add alpha suffix correctly" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                $result = Add-PreReleaseSuffix -Version "1.2.3" -SuffixType "alpha" -BuildNumber 1
                $result | Should -Be "1.2.3-alpha.1"
            }
        }
        
        It "Should add beta suffix correctly" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                $result = Add-PreReleaseSuffix -Version "2.0.0" -SuffixType "beta" -BuildNumber 5
                $result | Should -Be "2.0.0-beta.5"
            }
        }
        
        It "Should handle build number correctly" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                $result1 = Add-PreReleaseSuffix -Version "1.0.0" -SuffixType "alpha" -BuildNumber 1
                $result2 = Add-PreReleaseSuffix -Version "1.0.0" -SuffixType "alpha" -BuildNumber 15
            
                $result1 | Should -Be "1.0.0-alpha.1"
                $result2 | Should -Be "1.0.0-alpha.15"
            }
        }
        
        It "Should default to build number 1 if not specified" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                $result = Add-PreReleaseSuffix -Version "1.0.0" -SuffixType "beta"
                $result | Should -Be "1.0.0-beta.1"
            }
        }
        
        It "Should throw error for invalid version format" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                { Add-PreReleaseSuffix -Version "invalid" -SuffixType "alpha" } | Should -Throw
            }
        }
        
        It "Should throw error for unknown suffix type" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                { Add-PreReleaseSuffix -Version "1.0.0" -SuffixType "unknown" } | Should -Throw
            }
        }
    }
}

Describe "Build Number Management" {
    Context "Get-NextBuildNumber" {
        It "Should return 1 for new suffix type" {
            InModuleScope K.PSGallery.SemanticVersioning {
                # Mock git to return no tags
                Mock -CommandName "git" -MockWith { return @() }
                
                $result = Get-NextBuildNumber -SuffixType "alpha"
                $result | Should -Be 1
                $result | Should -BeOfType [int]
            }
        }
        
        It "Should increment from existing build numbers" {
            InModuleScope K.PSGallery.SemanticVersioning {
                # Mock git to return tags with alpha builds  
                Mock -CommandName "git" -MockWith {
                    if ($args[0] -eq "tag" -and $args[1] -eq "-l") {
                        return @(
                            "v1.0.0-alpha.1",
                            "v1.0.0-alpha.3", 
                            "v1.1.0-alpha.1"
                        )
                    }
                    return @()
                }
                
                $result = Get-NextBuildNumber -SuffixType "alpha" -BaseVersion "1.0.0"
                $result | Should -BeOfType [int]
                $result | Should -Be 4  # Should be max(1,3) + 1 = 4
            }
        }
        
        It "Should handle git errors gracefully" {
            InModuleScope K.PSGallery.SemanticVersioning {
                # Mock git to throw an error
                Mock -CommandName "git" -MockWith { throw "Git not found" }
                
                $result = Get-NextBuildNumber -SuffixType "beta"
                $result | Should -Be 1
                $result | Should -BeOfType [int]
            }
        }
    }
}

Describe "Integration with Main Functions" {
    Context "Get-NextSemanticVersion with Pre-Release from Commits" {
        It "Should detect prerelease from commit messages in first release" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                # Mock git commands for first release scenario
                Mock -CommandName "git" -MockWith {
                    if ($args[0] -eq "tag") {
                        return @()  # No existing tags
                    }
                    if ($args[0] -eq "log" -and $args[1] -eq "--oneline" -and $args[2] -eq "--all") {
                        return @("feat-alpha: Initial experimental feature")
                    }
                    return @()
                }
                
                # This would need the full Get-NextSemanticVersion integration
                $suffixType = Get-PreReleaseSuffixFromCommits -LastReleaseTag $null
                $suffixType | Should -Be "alpha"
            }
        }
        
        It "Should detect prerelease from commit messages in subsequent releases" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                # Mock git commands for subsequent release scenario  
                Mock -CommandName "git" -MockWith {
                    if ($args[0] -eq "log" -and $args[1] -eq "v1.0.0..HEAD") {
                        return @("feature-beta: Beta feature development")
                    }
                    return @()
                }
                
                $suffixType = Get-PreReleaseSuffixFromCommits -LastReleaseTag "v1.0.0"
                $suffixType | Should -Be "beta"
            }
        }
        
        It "Should not detect prerelease from standard commit messages" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Mock -CommandName "git" -MockWith {
                    if ($args[0] -eq "log") {
                        return @(
                            "feat: Standard feature",
                            "fix: Standard fix",
                            "breaking: Standard breaking change"
                        )
                    }
                    return @()
                }
                
                $suffixType = Get-PreReleaseSuffixFromCommits
                $suffixType | Should -BeNullOrEmpty
            }
        }
    }
}

Describe "Multiple Prerelease Keywords Priority Logic" {
    Context "Get-PreReleaseSuffixFromCommits Priority Handling" {
        It "Should prioritize beta over alpha when both are present" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Mock -CommandName "git" -MockWith {
                    if ($args[0] -eq "log") {
                        return @(
                            "feat-alpha: Alpha feature",
                            "fix-beta: Beta bug fix",
                            "patch-alpha: Another alpha commit"
                        )
                    }
                    return @()
                }
                
                $result = Get-PreReleaseSuffixFromCommits
                $result | Should -Be "beta"
            }
        }
        
        It "Should select alpha when only alpha keywords are present" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Mock -CommandName "git" -MockWith {
                    if ($args[0] -eq "log") {
                        return @(
                            "feat-alpha: Alpha feature",
                            "fix-alpha: Alpha bug fix",
                            "major-alpha: Alpha breaking change"
                        )
                    }
                    return @()
                }
                
                $result = Get-PreReleaseSuffixFromCommits
                $result | Should -Be "alpha"
            }
        }
        
        It "Should select beta when only beta keywords are present" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Mock -CommandName "git" -MockWith {
                    if ($args[0] -eq "log") {
                        return @(
                            "feature-beta: Beta feature",
                            "breaking-beta: Beta breaking change"
                        )
                    }
                    return @()
                }
                
                $result = Get-PreReleaseSuffixFromCommits
                $result | Should -Be "beta"
            }
        }
        
        It "Should handle mixed case keywords correctly" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Mock -CommandName "git" -MockWith {
                    if ($args[0] -eq "log") {
                        return @(
                            "Feat-Alpha: Mixed case alpha",
                            "FIX-BETA: Upper case beta"
                        )
                    }
                    return @()
                }
                
                $result = Get-PreReleaseSuffixFromCommits
                $result | Should -Be "beta"
            }
        }
        
        It "Should return null when no prerelease keywords found" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Mock -CommandName "git" -MockWith {
                    if ($args[0] -eq "log") {
                        return @(
                            "feat: Normal feature",
                            "fix: Normal bug fix",
                            "breaking: Normal breaking change"
                        )
                    }
                    return @()
                }
                
                $result = Get-PreReleaseSuffixFromCommits
                $result | Should -BeNullOrEmpty
            }
        }
    }
}

Describe "Prerelease Build Number Management" {
    Context "Get-NextBuildNumber with Existing Tags" {
        It "Should find highest build number and increment" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Mock -CommandName "git" -MockWith {
                    if ($args[0] -eq "tag" -and $args[1] -eq "-l") {
                        return @(
                            "v1.0.0-alpha.1",
                            "v1.0.0-alpha.5",
                            "v1.0.0-alpha.2",
                            "v1.0.0-beta.1",
                            "v1.1.0-alpha.1"
                        )
                    }
                    return @()
                }
                
                $result = Get-NextBuildNumber -SuffixType "alpha" -BaseVersion "1.0.0"
                $result | Should -Be 6  # max(1,5,2) + 1 = 6
            }
        }
        
        It "Should handle different base versions separately" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Mock -CommandName "git" -MockWith {
                    if ($args[0] -eq "tag" -and $args[1] -eq "-l") {
                        return @(
                            "v1.0.0-beta.3",
                            "v1.1.0-beta.1",
                            "v2.0.0-beta.1"
                        )
                    }
                    return @()
                }
                
                $result = Get-NextBuildNumber -SuffixType "beta" -BaseVersion "1.0.0"
                $result | Should -Be 4  # max(3) + 1 = 4
            }
        }
        
        It "Should return 1 for new suffix type with existing base version" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Mock -CommandName "git" -MockWith {
                    if ($args[0] -eq "tag" -and $args[1] -eq "-l") {
                        return @(
                            "v1.0.0",
                            "v1.0.1",
                            "v1.1.0"
                        )
                    }
                    return @()
                }
                
                $result = Get-NextBuildNumber -SuffixType "alpha" -BaseVersion "1.0.0"
                $result | Should -Be 1  # No alpha tags found
            }
        }
    }
}
    }
}
