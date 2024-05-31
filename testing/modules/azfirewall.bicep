param firewallName string
param location string
@allowed([
  'Standard'
  'Premium'
])
param azfwTier string
param vWanHubID string
param vWanAzFwPublicIPcount int = 1

var azfwSKUname = 'AZFW_Hub'

var firewallPolicyName = '${firewallName}-policy'

resource azfw 'Microsoft.Network/azureFirewalls@2023-06-01' = {
  name: firewallName
  location: location
  zones: []
  properties: {
    sku: {
      name: azfwSKUname
      tier: azfwTier
    }
    firewallPolicy: {
      id: azfwpolicy.id
    }
    virtualHub: {
      id: vWanHubID
    }
    hubIPAddresses: {
      publicIPs: {
        count: vWanAzFwPublicIPcount
      }
    }
  }
}

resource azfwpolicy 'Microsoft.Network/firewallPolicies@2023-06-01' = {
  name: firewallPolicyName
  location: location
  properties: {
    sku: {
      tier: azfwTier
    }
    threatIntelMode: 'Alert'
  }
}

output azFwPrivateIP string = azfw.properties.hubIPAddresses.privateIPAddress
output azFwPublicIP string = azfw.properties.hubIPAddresses.publicIPs.addresses[0].address
output azFwID string = azfw.id
output azFwPolicyName string = azfwpolicy.name
