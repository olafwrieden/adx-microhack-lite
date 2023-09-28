@description('Resource Deployment Location')
param deploymentLocation string = 'australiaeast'
@description('Name of the Azure Data Explorer Cluster')
param adxName string = 'adxclusteriot'
@description('Azure Data Explorer SKU')
param adxSKU string = 'Standard_D11_v2'
@description('Name of the Event Hub')
param eventHubName string = 'eventhubiot'
// @description('Do you want to deploy storage storage?')
// param deployStorage bool = false
// @description('The Storage Account Name')
// param saName string = 'iotmonitoringsa'
@description('Unique Suffix for resources')
param deploymentSuffix string = substring(uniqueString(resourceGroup().id), 0, 6)
@description('Do you want to deploy Azure Data Explorer')
param deployADX bool = false
// @description('Contributor: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor')
// var azureRBACContributorRoleID = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
// @description('Owner: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner')
// var azureRBACOwnerRoleID = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'

// ++++++++++++++++++
//  BEGIN DEPLOYMENT
// ++++++++++++++++++

@description('User-Assignment Managed Identity used to execute deployment scripts.')
resource deploymentUAMI 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: toLower('${resourceGroup().name}-uami')
  location: deploymentLocation
}
// var UAMI = deploymentUAMI.properties.principalId

@description('Deploys the ADX Module.')
module adxCluster 'modules/adx.bicep' = {
  name: adxName
  params: {
    adxName: '${adxName}${deploymentSuffix}'
    location: deploymentLocation
    adxSKU: adxSKU
    deployADX: deployADX
  }
}

@description('Deploys the Event Hub Module.')
module eventhub 'modules/eventhub.bicep' = {
  name: eventHubName
  params: {
    eventHubName: '${eventHubName}${deploymentSuffix}'
    location: deploymentLocation
    eventHubSKU: 'Standard'
    adxDeploy: deployADX
  }
}

// @description('Deploys the Storage Module.')
// module storageAccount 'modules/storage.bicep' = if (deployStorage) {
//   name: '${saName}${deploymentSuffix}'
//   params: {
//     saname: '${saName}${deploymentSuffix}'
//     location: deploymentLocation
//     eventHubId: '${eventhub.outputs.eventhubClusterId}/eventhubs/historicdata'
//     deployADX: deployADX
//   }
// }

@description('Get Azure Event Hubs Data receiver role definition. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles')
resource eventHubsDataReceiverRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde'
}

@description('Get Event Hub Reference (deployed in Module)')
resource eventHubReference 'Microsoft.EventHub/namespaces@2021-11-01' existing = {
  name: '${eventHubName}${deploymentSuffix}'
}

@description('Grant Azure Event Hubs Data receiver role to ADX')
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployADX) {
  name: guid(resourceGroup().id, eventHubsDataReceiverRoleDefinition.id)
  scope: eventHubReference
  properties: {
    roleDefinitionId: eventHubsDataReceiverRoleDefinition.id
    principalId: adxCluster.outputs.adxClusterIdentity
  }
}

// @description('Deployment script UAMI is set as Resource Group owner so it can have authorisation to perform post deployment tasks.')
// resource r_deploymentScriptUAMIRGOwner 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
//   name: guid('139d07dd-a26c-4b29-9619-8f70ea215795', subscription().subscriptionId, resourceGroup().id)
//   properties: {
//     roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACOwnerRoleID)
//     principalId: UAMI
//     principalType: 'ServicePrincipal'
//   }
// }

// @description('Completes Data Plane Operations post-resource deployment.')
// resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
//   name: 'add-iot-devices'
//   location: deploymentLocation
//   kind: 'AzureCLI'
//   identity: {
//     type: 'UserAssigned'
//     userAssignedIdentities: {
//       '${deploymentUAMI.id}': {}
//     }
//   }
//   properties: {
//     azCliVersion: '2.40.0'
//     retentionInterval: 'P1D'
//     timeout: 'PT10M'
//     scriptContent: '''
//     az extension add --name kusto --only-show-errors --output none; \
//     az extension update --name kusto --only-show-errors --output none; \
//     '''
//   }
//   dependsOn: [
//     r_deploymentScriptUAMIRGOwner
//   ]
// }

output eventHubConnectionString string = eventhub.outputs.eventHubConnectionString
output eventHubAuthRuleName string = eventhub.outputs.eventHubAuthRuleName
output eventHubName string = eventhub.outputs.eventHubName
output eventhubClusterId string = eventhub.outputs.eventhubClusterId
output eventhubNamespace string = eventhub.outputs.eventhubNamespace
// output saName string = deployStorage ? storageAccount.outputs.saName : 'na'
// output saId string = deployStorage ? storageAccount.outputs.saId : 'na'
output adxName string = deployADX ? adxCluster.outputs.adxName : 'na'
output adxClusterId string = deployADX ? adxCluster.outputs.adxClusterId : 'na'
output location string = deploymentLocation
output deployADX bool = deployADX
