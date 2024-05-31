<#
.SYNOPSIS
    This script generates a JSON file with all VNET IDs from a vWAN Hub. This script can be used as an input for Move-VNETconnections.ps1 file.

.DESCRIPTION
    This script generates a JSON file with all VNET IDs from a vWAN Hub.
    The script requires the vWAN Hub ID as input parameter.
    The vWAN Hub ID must be in the following format: /subscriptions/<subscription-id>/resourceGroups/<resource-group-name>/providers/Microsoft.Network/virtualHubs/<vwan-hub-name>
    The script will switch to the subscription of the vWAN Hub and get all VNET connections from the target vWAN Hub.
    The script will create a JSON file with all VNET IDs from the target vWAN Hub.

.PARAMETER vWanHubId
    The vWAN Hub ID in the following format: /subscriptions/<subscription-id>/resourceGroups/<resource-group-name>/providers/Microsoft.Network/virtualHubs/<vwan-hub-name>

.PARAMETER outputFile
    The name of the output JSON file. Default is "vnets.json".

.EXAMPLE
    .\Generate-JSON.ps1 -vWanHubId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/MyResourceGroup/providers/Microsoft.Network/virtualHubs/MyvWANHub"
    This example generates a JSON file with all VNET IDs from the vWAN Hub "MyvWANHub" in the resource group "MyResourceGroup" in the subscription "00000000-0000-0000-0000-000000000000".

.EXAMPLE
    .\Generate-JSON.ps1 -vWanHubId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/MyResourceGroup/providers/Microsoft.Network/virtualHubs/MyvWANHub" -outputFile "myvnets.json"
    This example generates a JSON file with all VNET IDs from the vWAN Hub "MyvWANHub" in the resource group "MyResourceGroup" in the subscription "00000000-0000-0000-0000-000000000000" and saves the output to "myvnets.json".

.NOTES
    File Name      : Generate-JSON.ps1
    Author         : P.Nagengast
    Prerequisite   : PowerShell 7.1.3 or later
#>

[CmdletBinding()] 
param(
    [ValidatePattern('^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Network/virtualHubs/[^/]+$', ErrorMessage = "The vWAN Hub ID is not in the correct format")]
    [Parameter(Mandatory = $true)]
    [string]$vWanHubId,
    [Parameter(Mandatory = $false)]
    [string]$outputFile = "vnets.json"
)

$vwanParts = $vWanHubId -split '/'
$vwanResourceGroupName = $vwanParts[4]
$vwanHubName = $vwanParts[8]
$vwanSubscriptionId = $vwanParts[2]

# switch to target vWAN hub subscription
$context = Get-AzSubscription -SubscriptionId $vwanSubscriptionId | Set-AzContext
Write-Host "Switching to subscription: $($context.Subscription.Name)"

# get all VNET connections from the target vWAN hub
$vnets = Get-AzVirtualHubVnetConnection -ResourceGroupName $vwanResourceGroupName -ParentResourceName $vwanHubName

# Create Array with all VNET IDs from the target vWAN hub
$vnets | ForEach-Object { $_.Id } | ConvertTo-Json -Depth 5 | Out-File -FilePath $outputFile -Force