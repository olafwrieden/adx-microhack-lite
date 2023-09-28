param saname string
param location string = resourceGroup().location
param eventHubId string
param deployADX bool

resource storageaccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  kind: 'StorageV2'
  location: location
  name: saname
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Disabled'
    allowBlobPublicAccess: false
  }
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = if (deployADX) {
  name: '${saname}/default/adxscript'
  dependsOn: [
    storageaccount
  ]
}

resource hackcontainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = if (deployADX == false) {
  name: '${saname}/default/data'
  dependsOn: [
    storageaccount
  ]
}

resource eventgrid 'Microsoft.EventGrid/systemTopics@2022-06-15' = if (deployADX) {
  name: 'BlobCreate'
  location: location
  properties: {
    source: storageaccount.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }

  resource eventSub 'eventSubscriptions' = if (deployADX) {
    name: 'HistoricData'
    properties: {
      destination: {
        endpointType: 'EventHub'
        properties: {
          resourceId: eventHubId
        }
      }
      filter: {
        includedEventTypes: [
          'Microsoft.Storage.BlobCreated'
        ]
        subjectEndsWith: ''
        enableAdvancedFilteringOnArrays: true
      }
      eventDeliverySchema: 'EventGridSchema'
      retryPolicy: {
        maxDeliveryAttempts: 30
        eventTimeToLiveInMinutes: 1440
      }
    }
  }
}

output saName string = storageaccount.name
output saId string = storageaccount.id
output keys object = storageaccount
