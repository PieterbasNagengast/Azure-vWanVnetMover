param vWanHubName string
param azFirewallId string

resource vWANHub1RoutingIntent 'Microsoft.Network/virtualHubs/routingIntent@2023-04-01' = {
  name: '${vWanHubName}/${vWanHubName}-RoutingIntent'
  properties: {
    routingPolicies: [
      {
        name: 'PublicTraffic'
        destinations: [
          'Internet'
        ]
        nextHop: azFirewallId
      }
      {
        name: 'PrivateTraffic'
        destinations: [
          'PrivateTraffic'
        ]
        nextHop: azFirewallId
      }
    ]
  }
}
