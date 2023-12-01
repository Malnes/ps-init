# process module dependencies. Run with -forceReprocess if nessesary
.\setup.ps1 -forceReprocess:$false
$var = Get-Content .\local.settings.json | ConvertFrom-Json

# Write you code below




