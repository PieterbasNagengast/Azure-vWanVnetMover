param location string
param vWanName string
param vWanHubName string
param ipRange string

resource vWan 'Microsoft.Network/virtualWans@2023-09-01' = {
  name: vWanName
  location: location
  properties: {}
}

resource vWanHub 'Microsoft.Network/virtualHubs@2023-11-01' = {
  name: vWanHubName
  location: location
  properties: {
    virtualWan: {
      id: vWan.id
    }
    addressPrefix: ipRange
  }
}

output vWanID string = vWan.id
output vWanHubID string = vWanHub.id
output vwanHubName string = vWanHub.name
