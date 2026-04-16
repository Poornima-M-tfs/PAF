$OutputCsvPath = ("C:\temp\PowerAutomateInventory_{0}.csv" -f (Get-Date -Format "yyyy-MM-dd-HH-mm"))
# Interactive connection details
$TenantName = "olink.onmicrosoft.com"

Add-PowerAppsAccount -Endpoint "prod" -TenantID $TenantName

$env = Get-AdminPowerAppEnvironment
$export = @()

#$ReportRowLimit = 10
#$ProcessedCount = 0

#$PAExport = "$env:AGENT_TEMPDIRECTORY" + "/PA_" +(get-date -Format yyyy-MM-dd-hh-mm) +".csv"

foreach ($e in $env){
#if ($ProcessedCount -ge $ReportRowLimit) { break }
$flows= Get-AdminFlow -EnvironmentName $e.EnvironmentName 
foreach ($fl in $flows){
#if ($ProcessedCount -ge $ReportRowLimit) { break }
$f = Get-AdminFlow -EnvironmentName $e.EnvironmentName -FlowName $fl.FlowName
if($f.FlowName -ne $null){
$connectors = $f.Internal.properties.connectionReferences

    $connectorOverview = ''
    $connectors.PSObject.Properties | ForEach-Object {

         $connectorOverview += $_.Value.DisplayName + ";"

    }
        $sites = $f.Internal.properties.referencedResources.resource.site
    $sitesOverview = ''
    $sites| ForEach-Object {

         $sitesOverview += $_ + ";"

    }
            $lists = $f.Internal.properties.referencedResources.resource.list
    $listssOverview = ''
    $lists | ForEach-Object {

         $listssOverview += $_ + ";"

    }
$ExportItem = New-Object PSObject 
$ExportItem | Add-Member -MemberType NoteProperty "DisplayName" -Value $f.DisplayName
$ExportItem | Add-Member -MemberType NoteProperty "FlowName" -Value $f.FlowName
$ExportItem | Add-Member -MemberType NoteProperty "Enabled" -Value $f.Enabled
$ExportItem | Add-Member -MemberType NoteProperty "CreatedBy" -Value $f.CreatedBy.userId
$ExportItem | Add-Member -MemberType NoteProperty "LastModifiedTime" -Value $f.LastModifiedTime
$ExportItem | Add-Member -MemberType NoteProperty "Connectors" -Value $connectorOverview
$ExportItem | Add-Member -MemberType NoteProperty "Sites" -Value $sitesOverview 
$ExportItem | Add-Member -MemberType NoteProperty "Lists" -Value $listssOverview

$export += $ExportItem
#$ProcessedCount++

}
}
}
$export | export-csv $OutputCsvPath  -NoTypeInformation