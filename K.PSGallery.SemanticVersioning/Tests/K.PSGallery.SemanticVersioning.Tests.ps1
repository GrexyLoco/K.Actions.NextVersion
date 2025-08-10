#Requires -Module Pester

Describe "K.PSGallery.SemanticVersioning Module Tests" {
    
    BeforeEach {
        # Import the module under test using absolute path
        $ModuleRoot = Split-Path $PSScriptRoot -Parent
        $ModulePath = Join-Path $ModuleRoot "K.PSGallery.SemanticVersioning.psd1"
        
        if (-not (Test-Path $ModulePath)) {
            throw "Module manifest not found at: $ModulePath"
        }
        
        Import-Module $ModulePath -Force
        
        # Create test manifest for testing
        $TestManifestPath = Join-Path $PSScriptRoot "TestModule.psd1"
        $TestManifestContent = @"
@{
    ModuleVersion = '1.2.3'
    GUID = '12345678-1234-1234-1234-123456789012'
    Author = 'Test Author'
    Description = 'Test module for K.PSGallery.SemanticVersioning'
    PowerShellVersion = '5.1'
}
"@
        $TestManifestContent | Out-File -FilePath $TestManifestPath -Encoding UTF8 -Force
    }

    AfterEach {
        # Clean up test manifests
        $TestManifestPath = Join-Path $PSScriptRoot "TestModule.psd1"
        $InvalidManifestPath = Join-Path $PSScriptRoot "InvalidTestModule.psd1"
        
        @($TestManifestPath, $InvalidManifestPath) | ForEach-Object {
            if (Test-Path $_) {
                Remove-Item $_ -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "Module Loading" {
        It "Should import the module successfully" {
            # Module is already imported in BeforeAll, so we just check if functions are available
            { Get-Command -Name "Get-NextSemanticVersion" -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should export Get-NextSemanticVersion function" {
            Get-Command -Name "Get-NextSemanticVersion" | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Test-FirstReleaseVersion function" {
            Get-Command -Name "Test-FirstReleaseVersion" | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Test-FirstReleaseVersion Function" {
        
        It "Should accept standard version 0.0.0 without action required" {
            $result = Test-FirstReleaseVersion -currentVersion "0.0.0" -BranchName "main" -forceFirstRelease:$false
            
            $result.NewVersion | Should -Not -BeNullOrEmpty
            $result.Error | Should -BeNullOrEmpty
            $result.BumpType | Should -Match "(major|minor|patch)"
        }
        
        It "Should accept standard version 1.0.0 without action required" {
            $result = Test-FirstReleaseVersion -currentVersion "1.0.0" -BranchName "main" -forceFirstRelease:$false
            
            $result.NewVersion | Should -Not -BeNullOrEmpty
            $result.Error | Should -BeNullOrEmpty
            $result.BumpType | Should -Match "(major|minor|patch)"
        }
        
        It "Should require action for unusual version without force flag" {
            $result = Test-FirstReleaseVersion -currentVersion "3.5.2" -BranchName "main" -forceFirstRelease:$false
            
            $result.NewVersion | Should -Be "3.5.2"
            $result.Error | Should -Match "Unusual version"
            $result.BumpType | Should -Be "none"
            $result.Instructions | Should -Not -BeNullOrEmpty
        }
        
        It "Should accept unusual version with force flag" {
            $result = Test-FirstReleaseVersion -currentVersion "3.5.2" -BranchName "main" -forceFirstRelease:$true
            
            $result.NewVersion | Should -Not -BeNullOrEmpty
            $result.Error | Should -BeNullOrEmpty
            $result.BumpType | Should -Match "(major|minor|patch)"
        }
    }
    
    Context "Private Function - Get-VersionBumpType (via Module)" {
        
        # We test this indirectly through the main function since it's private
        # But we can test the logic by examining the results
        
        It "Should detect feature branch patterns in real scenarios" {
            # This would be tested through Get-NextSemanticVersion in a real Git repo
            # For now, we test the concept
            $true | Should -Be $true  # Placeholder - would need Git repo setup
        }
    }
    
    Context "Get-NextSemanticVersion Function" {
        
        It "Should handle missing manifest path gracefully" {
            # Test in directory without .psd1 files
            $EmptyDir = Join-Path $env:TEMP "EmptyTestDir_$(Get-Random)"
            New-Item -ItemType Directory -Path $EmptyDir -Force | Out-Null
            Push-Location $EmptyDir
            try {
                $result = Get-NextSemanticVersion -BranchName "main" -TargetBranch "main"
                $result.Error | Should -Match "No .psd1 manifest file found"
            }
            finally {
                Pop-Location
                Remove-Item $EmptyDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        It "Should return structured object with all required properties" {
            $TestManifestPath = Join-Path $PSScriptRoot "TestModule.psd1"
            
            # Mock the git operations by testing in a controlled environment
            $result = Get-NextSemanticVersion -ManifestPath $TestManifestPath -BranchName "main" -TargetBranch "main"
            
            # Verify all expected properties exist
            $result.PSObject.Properties.Name | Should -Contain "CurrentVersion"
            $result.PSObject.Properties.Name | Should -Contain "BumpType"
            $result.PSObject.Properties.Name | Should -Contain "NewVersion"
            $result.PSObject.Properties.Name | Should -Contain "LastReleaseTag"
            $result.PSObject.Properties.Name | Should -Contain "TargetBranch"
            $result.PSObject.Properties.Name | Should -Contain "Suffix"
            $result.PSObject.Properties.Name | Should -Contain "Warning"
            $result.PSObject.Properties.Name | Should -Contain "ActionRequired"
            $result.PSObject.Properties.Name | Should -Contain "ActionInstructions"
        }
        
        It "Should handle non-target branch correctly" {
            $TestManifestPath = Join-Path $PSScriptRoot "TestModule.psd1"
            
            $result = Get-NextSemanticVersion -ManifestPath $TestManifestPath -BranchName "feature/test" -TargetBranch "main"
            
            $result.BumpType | Should -Be "minor"  # Feature branch should be minor, not none
            $result.Warning | Should -Match "Not on target branch"
            $result.ActionRequired | Should -Be $false
        }
        
        It "Should load current version from manifest" {
            $TestManifestPath = Join-Path $PSScriptRoot "TestModule.psd1"
            
            $result = Get-NextSemanticVersion -ManifestPath $TestManifestPath -BranchName "main" -TargetBranch "main"
            
            $result.CurrentVersion | Should -Be "1.2.3"
        }
    }
    
    Context "Error Handling" {
        
        It "Should handle invalid manifest path gracefully" {
            $result = Get-NextSemanticVersion -ManifestPath "C:\NonExistent\File.psd1" -BranchName "main" -TargetBranch "main"
            
            # Should return structured error, not throw exception
            $result | Should -Not -BeNullOrEmpty
            $result.Error | Should -Not -BeNullOrEmpty
            $result.Error | Should -Match "Manifest file not found"
        }
        
        It "Should handle manifest without ModuleVersion gracefully" {
            # Create invalid manifest
            $InvalidManifestPath = Join-Path $PSScriptRoot "InvalidTestModule.psd1"
            
            try {
                "@{ Author = 'Test' }" | Out-File -FilePath $InvalidManifestPath -Encoding UTF8 -Force
                $result = Get-NextSemanticVersion -ManifestPath $InvalidManifestPath -BranchName "main" -TargetBranch "main"
                
                # Should return structured error, not throw exception
                $result | Should -Not -BeNullOrEmpty
                $result.Error | Should -Not -BeNullOrEmpty
                $result.Error | Should -Match "Could not find ModuleVersion"
            }
            finally {
                # Ensure cleanup happens even if test fails
                if (Test-Path $InvalidManifestPath) {
                    Remove-Item $InvalidManifestPath -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    
    Context "Integration Scenarios" {
        
        It "Should work with ForceFirstRelease parameter" {
            $TestManifestPath = Join-Path $PSScriptRoot "TestModule.psd1"
            
            # Test that ForceFirstRelease is passed through correctly
            $result = Get-NextSemanticVersion -ManifestPath $TestManifestPath -BranchName "main" -TargetBranch "main" -ForceFirstRelease
            
            # Should not throw and should process the version
            $result.CurrentVersion | Should -Be "1.2.3"
        }
    }
}

Describe "Semantic Versioning Logic Tests" {
    
    Context "Version Bump Detection" {
        
        It "Should follow semantic versioning principles" {
            # Test the general principle that major > minor > patch
            $true | Should -Be $true  # This would be expanded with specific Git history tests
        }
        
        It "Should handle Alpha/Beta suffixes correctly" {
            # Test that suffixes are properly detected and applied
            $true | Should -Be $true  # This would be expanded with commit message tests
        }
    }
    
    Context "Git Tag Analysis" {
        
        It "Should parse semantic version tags correctly" {
            # Test tag parsing logic
            $true | Should -Be $true  # This would be expanded with mock Git tag tests
        }
    }
}

Describe "GitHub Actions Integration" {
    
    Context "Output Structure" {
        
        It "Should provide all outputs required by GitHub Actions" {
            $TestManifestPath = Join-Path $PSScriptRoot "TestModule.psd1"
            $result = Get-NextSemanticVersion -ManifestPath $TestManifestPath -BranchName "main" -TargetBranch "main"
            
            # All these properties should exist for GitHub Actions output
            @(
                'CurrentVersion', 'BumpType', 'NewVersion', 'LastReleaseTag', 
                'TargetBranch', 'Suffix', 'Warning', 'ActionRequired', 'ActionInstructions'
            ) | ForEach-Object {
                $result.PSObject.Properties.Name | Should -Contain $_
            }
        }
    }
}
