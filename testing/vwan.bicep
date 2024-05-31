targetScope = 'subscription'
param lcoation string
param rgName string
param ipRange string
param vWanHubName string
param vWanName string

param deployVNETconnections bool = false
param amountOfVNETs int = 0
param remoteVnetIds array = []

param deployRoutingIntent bool = false
param azFirewallName string = 'AzFW01'

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgName
  location: lcoation
}

module vwan 'modules/vwan.bicep' = {
  scope: rg
  name: 'Deploy_vWAN'
  params: {
    ipRange: ipRange
    location: lcoation
    vWanHubName: vWanHubName
    vWanName: vWanName
  }
}

module vnetconnections 'modules/vnetconnection.bicep' = [
  for i in range(0, amountOfVNETs): if (deployVNETconnections) {
    name: 'Deploy_VNETconnect${i+1}'
    scope: rg
    params: {
      remoteVnetId: remoteVnetIds[i]
      vnetConnectionName: 'toVNET${i+1}'
      vWanHubName: deployVNETconnections ? vwan.outputs.vwanHubName : ''
    }
  }
]

module azfirewall 'modules/azfirewall.bicep' = if (deployRoutingIntent) {
  name: 'Deploy_AzFirewall'
  scope: rg
  params: {
    azfwTier: 'Standard'
    firewallName: azFirewallName
    location: lcoation
    vWanHubID: deployRoutingIntent ? vwan.outputs.vWanHubID : ''
  }
}

module routingintent 'modules/routingintent.bicep' = if (deployRoutingIntent) {
  name: 'Deploy-RoutingIntent'
  scope: rg
  params: {
    azFirewallId: deployRoutingIntent ? azfirewall.outputs.azFwID : ''
    vWanHubName: deployRoutingIntent ? vwan.outputs.vwanHubName : ''
  }
}

output vWanID string = vwan.outputs.vWanID
output vWanHubID string = vwan.outputs.vWanHubID
