param location string
param vnetName string
param ipRange string

resource vnet 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        ipRange
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: cidrSubnet(ipRange, 26, 1)
        }
      }
    ]
  }
}

output id string = vnet.id
