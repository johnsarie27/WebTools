# ==============================================================================
# Updated:      2021-12-08
# Created by:   Justin Johns
# Filename:     WebTools.psm1
# ==============================================================================

# IMPORT ALL FUNCTIONS
foreach ( $directory in @('Public', 'Private') ) {
    foreach ( $fn in (Get-ChildItem -Path "$PSScriptRoot\$directory\*.ps1") ) { . $fn.FullName }
}

# VARIABLES
New-Variable -Name 'ETL_Schema' -Option ReadOnly -Value (Get-Content -Path "$PSScriptRoot\Private\ETL-Schema.json" -Raw)

# EXPORT MEMBERS
# THESE ARE SPECIFIED IN THE MODULE MANIFEST AND THEREFORE DON'T NEED TO BE LISTED HERE
#Export-ModuleMember -Function *
#Export-ModuleMember -Variable *
