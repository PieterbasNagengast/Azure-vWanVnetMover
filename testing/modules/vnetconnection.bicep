param vWanHubName string
param vnetConnectionName string
param remoteVnetId string

resource vWANHUBVNETconnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-11-01' = {
  name: '${vWanHubName}/${vnetConnectionName}'
  properties: {
    routingConfiguration: {
      associatedRouteTable: {
        id: resourceId('Microsoft.Network/virtualHubs/hubRouteTables', vWanHubName, 'defaultRouteTable')
      }
      propagatedRouteTables: {
        labels: [
          'default'
        ]
        ids: [
          {
            id: resourceId('Microsoft.Network/virtualHubs/hubRouteTables', vWanHubName, 'defaultRouteTable')
          }
        ]
      }
    }
    remoteVirtualNetwork: {
      id: remoteVnetId
    }
  }
}
