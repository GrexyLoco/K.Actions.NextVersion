#Requires -Module Pester

Describe "K.PSGallery.SemanticVersioning Basic Tests" {
    
    BeforeEach {
        # Import the module
        $ModuleRoot = Split-Path $PSScriptRoot -Parent
        $ModulePath = Join-Path $ModuleRoot "K.PSGallery.SemanticVersioning.psd1"
        
        Get-Module K.PSGallery.SemanticVersioning | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module $ModulePath -Force
        
        # Create test manifest
        $TestManifestPath = Join-Path $PSScriptRoot "TestModule.psd1"
        if (-not (Test-Path $TestManifestPath)) {
            @"
@{
    ModuleVersion = '1.2.3'
    GUID = '12345678-1234-1234-1234-123456789012'
    Author = 'Test Author'
    Description = 'Test module for K.PSGallery.SemanticVersioning'
    PowerShellVersion = '5.1'
}
"@ | Out-File -FilePath $TestManifestPath -Encoding UTF8 -Force
        }
    }
    
    AfterEach {
        $TestManifestPath = Join-Path $PSScriptRoot "TestModule.psd1"
        if (Test-Path $TestManifestPath) {
            Remove-Item $TestManifestPath -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Module Loading" {
        It "Should import the module successfully" {
            { Get-Command -Name "Get-NextSemanticVersion" -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should export Get-NextSemanticVersion function" {
            Get-Command -Name "Get-NextSemanticVersion" | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Get-FirstSemanticVersion function" {
            Get-Command -Name "Get-FirstSemanticVersion" | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Basic Function Tests" {
        It "Should return structured object with all required properties" {
            $TestManifestPath = Join-Path $PSScriptRoot "TestModule.psd1"
            
            $result = Get-NextSemanticVersion -ManifestPath $TestManifestPath -BranchName "main"
            
            # Verify all properties exist
            $result.PSObject.Properties.Name | Should -Contain "CurrentVersion"
            $result.PSObject.Properties.Name | Should -Contain "BumpType"
            $result.PSObject.Properties.Name | Should -Contain "NewVersion"
            $result.PSObject.Properties.Name | Should -Contain "LastReleaseTag"
            $result.PSObject.Properties.Name | Should -Contain "IsFirstRelease"
            $result.PSObject.Properties.Name | Should -Contain "Error"
            $result.PSObject.Properties.Name | Should -Contain "Instructions"
            $result.PSObject.Properties.Name | Should -Contain "GitContext"
        }
        
        It "Should load current version from manifest" {
            $TestManifestPath = Join-Path $PSScriptRoot "TestModule.psd1"
            
            $result = Get-NextSemanticVersion -ManifestPath $TestManifestPath -BranchName "main"
            
            $result.CurrentVersion | Should -Be "1.2.3"
        }
    }
}
