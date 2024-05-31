<#
.SYNOPSIS
    This script moves VNET connections from one vWAN hub to another vWAN hub.
    
.DESCRIPTION
    This script moves VNET connections from one vWAN hub to another vWAN hub. The script reads a JSON file that contains the list of VNET connections to move. The script will remove the VNET connection from the source vWAN hub and connect it to the target vWAN hub. The script also updates the VNET DNS servers and enables PrivateEndpointNetworkPolicies on the VNET subnets.

.PARAMETER target_vWanHubId
    The target vWAN Hub ID in the format: /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualHubs/{vWANHubName}

.PARAMETER vnetJsonFile
    The JSON file that contains the list of VNET connections to move. The JSON file should be in the following format:
    [
        "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualHubs/{vWANHubName}/hubVirtualNetworkConnections/{vnetConnectionName}",
        "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualHubs/{vWANHubName}/hubVirtualNetworkConnections/{vnetConnectionName}"
    ]

.PARAMETER RemoveAndConnect
    A switch parameter that specifies whether to remove the VNET connection from the source vWAN hub and connect it to the target vWAN hub. If this parameter is not specified, the script will only check if the VNET connection exists in the source vWAN hub.

.PARAMETER VNET_DNSServers
    An optional parameter that specifies the DNS servers to set for the VNET. The parameter should be an array of IP addresses.
    [
        "1.2.3.4",
        "5.6.7.8"
    ]

.PARAMETER EnablePrivateEndpointNetworkPolicies
    An optional switch parameter that specifies whether to enable PrivateEndpointNetworkPolicies on the VNET subnets. If this parameter is not specified, the script will not enable PrivateEndpointNetworkPolicies on the VNET subnets.

.PARAMETER logFile
    An optional parameter that specifies the log file to write the output of the script. The default log file is "move-VNETconnections.log".

.INPUTS
    None

.OUTPUTS
    None

.EXAMPLE
    .\Move-VNETconnections.ps1 -target_vWanHubId "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualHubs/{vWANHubName}" -vnetJsonFile "vnets.json" -RemoveAndConnect -VNET_DNSServers "1.2.3.4","6.7.8.9"

    This example moves the VNET connections listed in the "vnets.json" file to the target vWAN hub specified by the target_vWanHubId parameter. The script will remove the VNET connections from the source vWAN hub and connect them to the target vWAN hub. The script will also update the VNET DNS servers.

.EXAMPLE
    .\Move-VNETconnections.ps1 -target_vWanHubId "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualHubs/{vWANHubName}" -vnetJsonFile "vnets.json" -RemoveAndConnect

    This example moves the VNET connections listed in the "vnets.json" file to the target vWAN hub specified by the target_vWanHubId parameter. The script will remove the VNET connections from the source vWAN hub and connect them to the target vWAN hub.

.EXAMPLE
    .\Move-VNETconnections.ps1 -target_vWanHubId "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualHubs/{vWANHubName}" -vnetJsonFile "vnets.json"

    This example moves the VNET connections listed in the "vnets.json" file to the target vWAN hub specified by the target_vWanHubId parameter. The script will only check if the VNET connections exist in the source vWAN hub.

.EXAMPLE 
    .\Move-VNETconnections.ps1 -target_vWanHubId "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualHubs/{vWANHubName}" -vnetJsonFile "vnets.json" -RemoveAndConnect -VNET_DNSServers "1.2.3.4","6.7.8.9" -EnablePrivateEndpointNetworkPolicies

    This example moves the VNET connections listed in the "vnets.json" file to the target vWAN hub specified by the target_vWanHubId parameter. The script will remove the VNET connections from the source vWAN hub and connect them to the target vWAN hub. The script will also enable PrivateEndpointNetworkPolicies on the VNET subnets. The script will also update the VNET DNS servers.

.NOTES
    File Name      : Move-VNETconnections.ps1
    Author         : P.Nagengast
    Prerequisite   : PowerShell 7.1 or later
#>

[CmdletBinding()] param(
    [parameter(Mandatory = $true)]
    [ValidatePattern('^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Network/virtualHubs/[^/]+$', ErrorMessage = "The target vWAN Hub ID is not in the correct format")]
    [string]$target_vWanHubId,
    [parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf }, ErrorMessage = "The VNET JSON file does not exist")]
    [string]$vnetJsonFile,
    [parameter(Mandatory = $false)]
    [switch]$RemoveAndConnect,
    [parameter(Mandatory = $false)]
    [ValidateScript({ $_ -contains [IPAddress]$_ }, ErrorMessage = "The VNET DNS Servers must be a valid IP address")]
    [string[]]$VNET_DNSServers,
    [parameter(Mandatory = $false)]
    [switch]$EnablePrivateEndpointNetworkPolicies,
    [parameter(Mandatory = $false)]
    [string]$logFile = "move-VNETconnections.log"
) 

$json = Get-Content $vnetJsonFile | ConvertFrom-Json
$jobs = New-Object System.Collections.Generic.List[System.Object]
$logs = New-Object System.Collections.Generic.List[System.Object]

$target_vWanHubId_split = $target_vWanHubId.Split('/')

# write some stats before starting the jobs
Write-Verbose "Total VNET connections to process: $($json.Count)"
Write-Verbose "Target vWAN Hub: $($target_vWanHubId_split[-1])"
Write-Verbose "Remove and Connect: $RemoveAndConnect"
Write-Verbose "VNET DNS Servers: $($VNET_DNSServers | ConvertTo-Json -Compress)"
Write-Verbose "Starting jobs..."

# start jobs for each VNET connection
$json | ForEach-Object {
    $jobs.Add(( start-job -ScriptBlock {
                [CmdletBinding()] param (
                    [string]$source_HubConnectionId,
                    [string[]]$target_vWanHubId_split,
                    [bool]$RemoveAndConnect,
                    [string[]]$VNET_DNSServers,
                    [bool]$EnablePrivateEndpointNetworkPolicies
                )

                # Variables for source vWAN hub
                $source_HubConnectionId_split = $source_HubConnectionId.Split('/')
                $source_SubscriptionId = $source_HubConnectionId_split[2]
                $source_ResourceGroupName = $source_HubConnectionId_split[4]
                $source_HubName = $source_HubConnectionId_split[8]
                $source_HubVNETConnectionName = $source_HubConnectionId_split[-1]

                # Variables for target vWAN hub
                $target_subscriptionId = $target_vWanHubId_split[2]
                $target_ResourceGroupName = $target_vWanHubId_split[4]
                $target_HubName = $target_vWanHubId_split[8]
        
                # STEP 1: Check if VNET connection exists in source vWAN hub
                # switch to source vWAN hub subscription
                $context = Get-AzSubscription -SubscriptionId $source_SubscriptionId | Set-AzContext
                Write-output "0/Switching to subscription: $($context.Subscription.Name)"

                # validate that the source vWAN HUB VNET connection exist
                $vnetConnection = Get-AzVirtualHubVnetConnection -ResourceGroupName $source_ResourceGroupName -ParentResourceName $source_HubName -Name $source_HubVNETConnectionName -ErrorAction SilentlyContinue
        
                if ($vnetConnection) {
                    Write-output "10/Checked VNET Connection: $($vnetConnection.Name)"
                    if ($RemoveAndConnect) {

                        # STEP 2: Remove VNET connection from source vWAN hub
                        Write-Output "20/Removing VNET connection: $($vnetConnection.Name) from source vWAN hub"
                        $remove = Remove-AzVirtualHubVnetConnection -ResourceGroupName $source_ResourceGroupName -ParentResourceName $source_HubName -Name $source_HubVNETConnectionName -Force
                        if ($null -eq $remove) {
                            Write-Output "30/removed VNET connection $($vnetConnection.Name) successfully"
                        }
                        else {
                            Write-Output "30/FAILED: to remove VNET connection $($vnetConnection.Name) from source vWAN hub"
                            break
                        }
        
                        # STEP 3: Connect VNET connection to target vWAN hub
                        # switch to target vWAN hub subscription
                        $context = Get-AzSubscription -SubscriptionId $target_subscriptionId | Set-AzContext
                        Write-output "40/Switching to subscription: $($context.Subscription.Name)"
        
                        # connect VNET connection to target vWAN hub
                        Write-Output "50/Connecting VNET connection $($vnetConnection.Name) to target vWAN hub"
                        $connect = New-AzVirtualHubVnetConnection -ResourceGroupName $target_ResourceGroupName -ParentResourceName $target_HubName -Name $vnetConnection.Name -RemoteVirtualNetworkId $vnetConnection.RemoteVirtualNetwork.Id -ErrorAction SilentlyContinue
                        if ($connect) {
                            Write-Output "60/moved VNET connection $($vnetConnection.Name) successfully"

                            # STEP 4: update VNET DNS servers
                            # switch to target VNET subscription
                            $vnetConnection_split = $vnetConnection.RemoteVirtualNetwork.Id.Split('/')
                            $context = Get-AzSubscription -SubscriptionId $vnetConnection_split[2] | Set-AzContext
                            Write-output "70/Switching to subscription: $($context.Subscription.Name)"
                
                            if ($VNET_DNSServers && $EnablePrivateEndpointNetworkPolicies) {
                                # update VNET DNS servers
                                $vnet = get-azvirtualnetwork -ResourceGroupName $vnetConnection_split[4]  -Name $vnetConnection_split[-1] -ErrorAction SilentlyContinue
                                Write-Output "75/Checking VNET: $($vnet.Name)"

                                if ($vnet) {
                                    # STEP 4a: Update VNET DNS servers
                                    if ($VNET_DNSServers) {
                                        Write-Output "75/Updating VNET DNS servers for VNET: $($vnet.Name) to: $($VNET_DNSServers |ConvertTo-Json -Compress)"
                                        $vnet.dhcpoptions.dnsservers = $VNET_DNSServers
                                    }

                                    # STEP 4b: Enable PrivateEndpointNetworkPolicies on VNET subnets
                                    foreach ($subnet in $vnet.Subnets) {
                                        if ($subnet.PrivateEndpoints) {
                                            Write-Output "80/Private Endpoints found on subnet: $($subnet.Name)"
                                            if ($subnet.PrivateEndpointNetworkPolicies -eq "Disabled") {
                                                write-output "85/Enabling PrivateEndpointNetworkPolicies on subnet: $($subnet.Name)"
                                                $subnet.PrivateEndpointNetworkPolicies = "Enabled"
                                            }
                                        }
                                        else {
                                            Write-Output "80/No Private Endpoints found on subnet: $($subnet.Name)"
                                        }
                                    }

                                    $vnet = Set-AzVirtualNetwork -VirtualNetwork $vnet -ErrorAction SilentlyContinue
                                    if ($vnet) {
                                        Write-Output "90/VNET updated successfully on: $($vnet.Name)"
                                    }
                                }
                                else {
                                    Write-Output "90/FAILED: to update VNET: $($vnet.Name)"
                                }                
                            }
                            else {
                                Write-Output "75/Skipping VNET DNS server update and PrivateEndpointNetworkPolicies"
                            }
                        }
                        else {
                            Write-Output "60/FAILED: to connect VNET connection $($vnetConnection.Name) to target vWAN hub"
                        }   
                    }
                    else {
                        Write-Output "10/Skipping VNET connection removal and connection"
                    }

                    Write-Output "100/Completed processing VNET connection: $($vnetConnection.Name)"
                }
                else {
                    Write-Output "0/FAILED: VNET connection: $($source_HubVNETConnectionName) does not exist in source vWAN hub"
                }


            } -ArgumentList $_, $target_vWanHubId_split, $RemoveAndConnect, $VNET_DNSServers, $EnablePrivateEndpointNetworkPolicies -Name $_.Split('/')[10]
        ))
}

while ($jobs | Where-Object { $_.State -eq 'Running' }) {
    foreach ($job in $jobs | Where-Object { $_.State -eq 'Running' }) {
        $output = Receive-Job -Job $job -Keep
        if ($output) {
            $lastOutput = $output[-1].ToString()
            if ($lastOutput.Contains('/')) {
                $splitOutput = $lastOutput.Split('/')
                $status = $splitOutput[1]
                $percentage = $splitOutput[0]
                
                Write-Progress -Activity "Processing job: $($job.Name)" -Status $status -PercentComplete $percentage -id $job.Id
            }
        }
    } 
}

$jobs | ForEach-Object {
    $output = Receive-Job -Job $_ 
    Write-Output "JobID: $($_.Id), Job: $($_.Name), State: $($_.State) Status: $(($output[-1].ToString()).Split('/')[1])"

    # write log files based on output, append to existing file, include JobID and Job name
    foreach ($line in $output) {
        $logs.add("JobID: $($_.Id), Job: $($_.Name), Output: $($line)")
    }

    # calculate the duration of the job and write to log file
    $duration = (($_.PSEndTime - $_.PSBeginTime).ToString("mm'min:'ss'sec'"))
    $logs.Add("JobID: $($_.Id), Job: $($_.Name), Duration: $($duration)")

    Remove-Job -Job $_
}
$logs | Out-File -FilePath $logFile -Append