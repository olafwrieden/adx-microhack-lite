param adxName string
param location string = resourceGroup().location
param adxSKU string
param deployADX bool

resource adxCluster 'Microsoft.Kusto/clusters@2022-12-29' = if (deployADX) {
  name: adxName
  location: location
  sku: {
    name: adxSKU
    tier: 'Standard'
    capacity: 2
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource adxDb 'Microsoft.Kusto/clusters/databases@2022-12-29' = if (deployADX) {
  kind: 'ReadWrite'
  name: 'IoTAnalytics'
  location: location
  parent: adxCluster
  properties: {
    softDeletePeriod: 'P60D'
    hotCachePeriod: 'P365D'
  }
}

output adxClusterId string = deployADX ? adxCluster.id : 'na'
output adxClusterIdentity string = deployADX ? adxCluster.identity.principalId : 'na'
output adxName string = deployADX ? adxCluster.name : 'na'
