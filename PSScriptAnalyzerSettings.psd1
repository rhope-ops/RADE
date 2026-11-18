# PSScriptAnalyzer settings for the built RADE bundle, read by scripts/lint.sh (-Settings).
# Severities Error, Warning and ParseError; syntax checked against Windows PowerShell 5.1; Write-Host allowed.
@{
    Severity     = @('Error', 'Warning', 'ParseError')
    Rules        = @{
        PSUseCompatibleSyntax = @{ Enable = $true; TargetVersions = @('5.1') }
    }
    ExcludeRules = @('PSAvoidUsingWriteHost')
}
