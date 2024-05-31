targetScope = 'subscription'
param lcoation string
param rgName string
param amountOfVNETs int
param ipRanges array

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgName
  location: lcoation
}

module vnets 'modules/vnet.bicep' = [
  for i in range(1, amountOfVNETs): {
    scope: rg
    name: 'Deploy-VNET${i}'
    params: {
      ipRange: ipRanges[i - 1]
      location: lcoation
      vnetName: 'vnet-${i}'
    }
  }
]

output vnetIDs array = [for i in range(1, amountOfVNETs): vnets[i - 1].outputs.id]
