// ---------------------------------------------------------------------------
// Test: Validate module composition
// Run with: az bicep build --file tests/main.test.bicep
// These tests verify that modules compile and accept expected parameters.
// ---------------------------------------------------------------------------

// Test: Key Vault module compiles with minimal required parameters
module kvTest '../modules/key-vault/main.bicep' = {
  name: 'test-kv'
  params: {
    location: 'eastus2'
    keyVaultName: 'kv-test-001'
    adminObjectId: '00000000-0000-0000-0000-000000000000'
    enablePrivateEndpoint: false
    tags: { environment: 'test' }
  }
}

// Test: Storage module compiles with minimal required parameters
module stgTest '../modules/storage/main.bicep' = {
  name: 'test-stg'
  params: {
    location: 'eastus2'
    storageAccountName: 'sttest001'
    enablePrivateEndpoint: false
    tags: { environment: 'test' }
  }
}

// Test: NSG module compiles with default rules
module nsgTest '../modules/nsg/main.bicep' = {
  name: 'test-nsg'
  params: {
    location: 'eastus2'
    nsgName: 'nsg-test-001'
    tags: { environment: 'test' }
  }
}
