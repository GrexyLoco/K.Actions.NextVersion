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

Describe "Pre-Release Suffix Configuration" {
    Context "Get-PreReleaseSuffixConfig" {
        It "Should return valid configuration structure" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                $config = Get-PreReleaseSuffixConfig
                
                $config | Should -Not -BeNullOrEmpty
                $config.Keys | Should -Contain "alpha"
                $config.Keys | Should -Contain "beta" 
                $config.Keys | Should -Contain "rc"
                
                # Test alpha configuration
                $config["alpha"] | Should -Not -BeNullOrEmpty
                $config["alpha"].BranchPatterns | Should -Not -BeNullOrEmpty
                $config["alpha"].Priority | Should -Be 1
                $config["alpha"].Format | Should -Be "alpha.{0}"
            }
        }
        
        It "Should have correct priority ordering" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                $config = Get-PreReleaseSuffixConfig
                
                $config["alpha"].Priority | Should -BeLessThan $config["beta"].Priority
                $config["beta"].Priority | Should -BeLessThan $config["rc"].Priority
            }
        }
    }
}

Describe "Pre-Release Suffix Type Detection" {
    Context "Get-PreReleaseSuffixType" {
        It "Should detect alpha suffix from branch patterns" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Get-PreReleaseSuffixType -BranchName "alpha/new-feature" | Should -Be "alpha"
                Get-PreReleaseSuffixType -BranchName "experimental/test" | Should -Be "alpha"
                Get-PreReleaseSuffixType -BranchName "poc/validation" | Should -Be "alpha"
            }
        }
        
        It "Should detect beta suffix from branch patterns" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Get-PreReleaseSuffixType -BranchName "beta/release-prep" | Should -Be "beta"
                Get-PreReleaseSuffixType -BranchName "preview/new-ui" | Should -Be "beta"
                Get-PreReleaseSuffixType -BranchName "staging/final-test" | Should -Be "beta"
            }
        }
        
        It "Should detect rc suffix from branch patterns" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Get-PreReleaseSuffixType -BranchName "rc/v2.0" | Should -Be "rc"
                Get-PreReleaseSuffixType -BranchName "release/candidate" | Should -Be "rc"
                Get-PreReleaseSuffixType -BranchName "candidate/final" | Should -Be "rc"
            }
        }
        
        It "Should return null for standard branches" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Get-PreReleaseSuffixType -BranchName "main" | Should -BeNullOrEmpty
                Get-PreReleaseSuffixType -BranchName "feature/standard" | Should -BeNullOrEmpty
                Get-PreReleaseSuffixType -BranchName "bugfix/issue-123" | Should -BeNullOrEmpty
            }
        }
        
        It "Should prioritize higher priority suffixes" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                # If a branch could match multiple patterns, higher priority wins
                Get-PreReleaseSuffixType -BranchName "rc/beta-test" | Should -Be "rc"
            }
        }
        
        It "Should be case insensitive" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Get-PreReleaseSuffixType -BranchName "ALPHA/TEST" | Should -Be "alpha"
                Get-PreReleaseSuffixType -BranchName "Beta/Feature" | Should -Be "beta"
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
        
        It "Should add rc suffix correctly" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                $result = Add-PreReleaseSuffix -Version "1.5.2" -SuffixType "rc" -BuildNumber 2
                $result | Should -Be "1.5.2-rc.2"
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

Describe "Pre-Release Version Validation" {
    Context "Test-PreReleaseSuffixFormat" {
        It "Should validate correct alpha format" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Test-PreReleaseSuffixFormat -Version "1.2.3-alpha.1" | Should -Be $true
                Test-PreReleaseSuffixFormat -Version "2.0.0-alpha.15" | Should -Be $true
            }
        }
        
        It "Should validate correct beta format" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Test-PreReleaseSuffixFormat -Version "1.5.0-beta.1" | Should -Be $true
                Test-PreReleaseSuffixFormat -Version "3.2.1-beta.8" | Should -Be $true
            }
        }
        
        It "Should validate correct rc format" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Test-PreReleaseSuffixFormat -Version "2.1.0-rc.1" | Should -Be $true
                Test-PreReleaseSuffixFormat -Version "1.0.0-rc.3" | Should -Be $true
            }
        }
        
        It "Should reject invalid formats" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Test-PreReleaseSuffixFormat -Version "1.2.3-invalid.1" | Should -Be $false
                Test-PreReleaseSuffixFormat -Version "1.2.3-alpha" | Should -Be $false
                Test-PreReleaseSuffixFormat -Version "invalid-alpha.1" | Should -Be $false
                Test-PreReleaseSuffixFormat -Version "1.2-alpha.1" | Should -Be $false
            }
        }
        
        It "Should reject standard versions" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                Test-PreReleaseSuffixFormat -Version "1.2.3" | Should -Be $false
            }
        }
    }
}

Describe "Build Number Management" {
    Context "Get-NextBuildNumber (Internal Function)" {
        It "Should return 1 for new suffix type" {
            InModuleScope K.PSGallery.SemanticVersioning {
                # Mock git to return no tags
                Mock -CommandName "git" -MockWith { return @() }
                
                $result = Get-NextBuildNumber -SuffixType "rc"
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
    Context "Get-NextSemanticVersion with Pre-Release Suffixes" {
        It "Should detect alpha suffix type correctly" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                $suffixType = Get-PreReleaseSuffixType -BranchName "alpha/new-feature"
                $suffixType | Should -Be "alpha"
            }
        }
        
        It "Should detect beta suffix type correctly" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                $suffixType = Get-PreReleaseSuffixType -BranchName "beta/release-prep"
                $suffixType | Should -Be "beta"
            }
        }
        
        It "Should add alpha suffix correctly" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                $version = Add-PreReleaseSuffix -Version "1.0.1" -SuffixType "alpha" -BuildNumber 1
                $version | Should -Be "1.0.1-alpha.1"
            }
        }
        
        It "Should add beta suffix correctly" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                $version = Add-PreReleaseSuffix -Version "1.0.1" -SuffixType "beta" -BuildNumber 2
                $version | Should -Be "1.0.1-beta.2"
            }
        }
        
        It "Should calculate next build number correctly" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                # Mock git to return no existing tags for this test
                Mock -CommandName "git" -MockWith { return @() }
                
                $buildNumber = Get-NextBuildNumber -SuffixType "alpha" -BaseVersion "1.0.1"
                $buildNumber | Should -Be 1
                $buildNumber | Should -BeOfType [int]
            }
        }
    }
    
    Context "First Release with Pre-Release Suffixes" {
        It "Should handle first release suffix detection" {
            InModuleScope -ModuleName "K.PSGallery.SemanticVersioning" {
                $suffixType = Get-PreReleaseSuffixType -BranchName "alpha/initial"
                $suffixType | Should -Be "alpha"
                
                $suffixType = Get-PreReleaseSuffixType -BranchName "main"
                $suffixType | Should -BeNullOrEmpty
            }
        }
    }
}
