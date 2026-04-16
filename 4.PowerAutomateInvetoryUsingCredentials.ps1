$OutputCsvPath = ("C:\temp\PowerAutomateInventory_{0}.csv" -f (Get-Date -Format "yyyy-MM-dd-HH-mm"))
# Interactive connection details
$TenantName = "olink.onmicrosoft.com"

Add-PowerAppsAccount -Endpoint "prod" -TenantID $TenantName

function Get-NestedPropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Object,
        [Parameter(Mandatory = $true)]
        [string[]]$PropertyPaths
    )

    foreach ($path in $PropertyPaths) {
        $value = $Object
        $resolved = $true

        foreach ($segment in ($path -split '\.')) {
            if ($null -eq $value) {
                $resolved = $false
                break
            }

            $prop = $value.PSObject.Properties[$segment]
            if ($null -eq $prop) {
                $resolved = $false
                break
            }

            $value = $prop.Value
        }

        if ($resolved -and $null -ne $value) {
            return $value
        }
    }

    return $null
}

$env = Get-AdminPowerAppEnvironment
$export = @()

foreach ($e in $env) {
    $flows = Get-AdminFlow -EnvironmentName $e.EnvironmentName
    foreach ($fl in $flows) {
        $f = Get-AdminFlow -EnvironmentName $e.EnvironmentName -FlowName $fl.FlowName
        if ($f.FlowName -ne $null) {
            $connectors = $f.Internal.properties.connectionReferences

            $connectorOverview = ''
            $connectors.PSObject.Properties | ForEach-Object {
                $connectorOverview += $_.Value.DisplayName + ";"
            }

            $sites = $f.Internal.properties.referencedResources.resource.site
            $sitesOverview = ''
            $sites | ForEach-Object {
                $sitesOverview += $_ + ";"
            }

            $lists = $f.Internal.properties.referencedResources.resource.list
            $listssOverview = ''
            $lists | ForEach-Object {
                $listssOverview += $_ + ";"
            }

            $sharedUsers = ''
            $flowRoles = Get-AdminFlowOwnerRole -EnvironmentName $e.EnvironmentName -FlowName $f.FlowName -ErrorAction SilentlyContinue
            if ($flowRoles) {
                $sharedUsers = (($flowRoles |
                    Where-Object { $_.PrincipalType -eq 'User' -and $_.RoleType -ne 'Owner' } |
                    ForEach-Object {
                        Get-NestedPropertyValue -Object $_ -PropertyPaths @(
                            'Principal.email',
                            'Principal.userDetails.email',
                            'Principal.displayName',
                            'Principal.objectId'
                        )
                    }) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique) -join ';'
            }

            $createdTime = Get-NestedPropertyValue -Object $f -PropertyPaths @(
                'CreatedTime',
                'Internal.properties.createdTime',
                'Internal.properties.creationTime'
            )

            $createdByEmail = Get-NestedPropertyValue -Object $f -PropertyPaths @(
                'CreatedBy.userEmail',
                'CreatedBy.email',
                'Internal.properties.creator.email',
                'Internal.properties.createdBy.user.email',
                'CreatedBy.userId'
            )

            $modifiedBy = Get-NestedPropertyValue -Object $f -PropertyPaths @(
                'LastModifiedBy.userEmail',
                'LastModifiedBy.email',
                'Internal.properties.lastModifiedBy.user.email',
                'Internal.properties.lastModifiedBy'
            )

            $lastRunTime = Get-NestedPropertyValue -Object $f -PropertyPaths @(
                'Internal.properties.lastRunTime',
                'LastRunTime',
                'Internal.properties.run.lastRunTime'
            )

            $environmentId = Get-NestedPropertyValue -Object $e -PropertyPaths @(
                'EnvironmentName',
                'EnvironmentId',
                'EnvironmentInternal.id'
            )

            $ExportItem = New-Object PSObject
            $ExportItem | Add-Member -MemberType NoteProperty "DisplayName" -Value $f.DisplayName
            $ExportItem | Add-Member -MemberType NoteProperty "FlowName" -Value $f.FlowName
            $ExportItem | Add-Member -MemberType NoteProperty "Enabled" -Value $f.Enabled
            $ExportItem | Add-Member -MemberType NoteProperty "Created" -Value $createdTime
            $ExportItem | Add-Member -MemberType NoteProperty "CreatedBy" -Value $f.CreatedBy.userId
            $ExportItem | Add-Member -MemberType NoteProperty "CreatedByUserEmail" -Value $createdByEmail
            $ExportItem | Add-Member -MemberType NoteProperty "SharedWithUsers" -Value $sharedUsers
            $ExportItem | Add-Member -MemberType NoteProperty "ModifiedBy" -Value $modifiedBy
            $ExportItem | Add-Member -MemberType NoteProperty "LastModifiedTime" -Value $f.LastModifiedTime
            $ExportItem | Add-Member -MemberType NoteProperty "EnvironmentName" -Value $e.DisplayName
            $ExportItem | Add-Member -MemberType NoteProperty "EnvironmentID" -Value $environmentId
            $ExportItem | Add-Member -MemberType NoteProperty "LastRunTime" -Value $lastRunTime
            $ExportItem | Add-Member -MemberType NoteProperty "Connectors" -Value $connectorOverview
            $ExportItem | Add-Member -MemberType NoteProperty "Sites" -Value $sitesOverview
            $ExportItem | Add-Member -MemberType NoteProperty "Lists" -Value $listssOverview

            $export += $ExportItem
        }
    }
}

$export | Export-Csv $OutputCsvPath -NoTypeInformation
