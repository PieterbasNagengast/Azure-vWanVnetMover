targetScope = 'subscription'

param location string = deployment().location

param ipCIDRrange string = '172.31.0.0/16'

// Target vWAN
param target_SubscriptionID string
param target_RGname string = 'rg-vwan-new'
param target_vWANname string = 'vWAN-new'
param target_vWANHUBname string = 'vWANHUB-new'

// target IP range for vWAN HUB only
var target_ipRange = cidrSubnet(ipCIDRrange, 24, 255)

// source vWAN
param source_SubscriptionID string
param source_RGname string = 'rg-vwan-old'
param source_vWANname string = 'vWAN-old'
param source_vWANHUBname string = 'vWANHUB-old'

// source IP ranges for vWAN HUB and VNETs
var source_ipRange = cidrSubnet(ipCIDRrange, 24, 0)

// source VNETs
param vnets_SubscriptionID string
param vnets_RGname string = 'rg-vnets'
param amountOfVNETs int = 100

// Ip Ranges for VNETs
var vnet_ipRanges = [for i in range(1, amountOfVNETs): cidrSubnet(ipCIDRrange, 24, i)]

module sourceVwan 'vwan.bicep' = {
  name: 'Deploy_Source'
  scope: subscription(source_SubscriptionID)
  params: {
    lcoation: location
    rgName: source_RGname
    ipRange: source_ipRange
    vWanHubName: source_vWANHUBname
    vWanName: source_vWANname
    deployVNETconnections: true
    amountOfVNETs: amountOfVNETs
    remoteVnetIds: vnets.outputs.vnetIDs
  }
}

module targetVwan 'vwan.bicep' = {
  name: 'Deploy_target'
  scope: subscription(target_SubscriptionID)
  params: {
    lcoation: location
    rgName: target_RGname
    ipRange: target_ipRange
    vWanHubName: target_vWANHUBname
    vWanName: target_vWANname
    deployRoutingIntent: true
  }
}

module vnets 'vnets.bicep' = {
  name: 'Deploy_VNETs'
  scope: subscription(vnets_SubscriptionID)
  params: {
    lcoation: location
    rgName: vnets_RGname
    amountOfVNETs: amountOfVNETs
    ipRanges: vnet_ipRanges
  }
}

output vnetIDs array = vnets.outputs.vnetIDs
output vnetIpRanges array = vnet_ipRanges
output source_vWAN_ipRange string = source_ipRange
output target_vWAN_ipRange string = target_ipRange
