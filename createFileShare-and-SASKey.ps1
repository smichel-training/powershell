# Script that will use or create a storage account in order to create dedicated share containers
# Each share will be set to 5 GiB quota and will have a dedicated Access policy
# script returns the URL and SAS token which could be comunicated to the client
# Author : Sébastien Michel
# GitHub Repository : https://github.com/smichel-training/powershell
# -----------------------------------------------------------------------------------------------

$resourceGroup = "pocstorage"
$storageName = "customershareaccount"
$location = "westeurope"

Write-Host "Verify that $storageName is available in $location location"

try{
    Get-AzStorageAccount -ResourceGroupName $resourceGroup –StorageAccountName $storageName -ErrorAction Stop
    Write-Host "-- $storageName is available in $location location"
    }
catch{
    Write-Host "-- $storageName not available in $location location"
    Write-Host "-- Creating $storageName in $location location"
    try{
        New-AzStorageAccount -ResourceGroupName $resourceGroup -StorageAccountName `
            $storageName -Location $Location -SkuName Standard_LRS -EnableHttpsTrafficOnly $True -Verbose
        Write-Host "-- $storageName created in $location location"
    }
    catch{
        Write-Host "-- Failed to create $storageName in $location location"
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host $_.Exception.ItemName -ForegroundColor Red
        Exit
    }
}

#Ask for customer share name
$customerShareName = Read-Host "Enter customer File share name to be created"

#Getting Storage context

try{
    $storageContext = New-AzStorageContext -StorageAccountName $storageName `
        -storageAccountKey (Get-AzStorageAccountKey -ResourceGroupName $resourceGroup -AccountName $storageName).Value[0]
    }
catch{
    try {
        $storageContext = New-AzStorageContext -StorageAccountName $storageName `
        -storageAccountKey (Get-AzStorageAccountKey -ResourceGroupName $resourceGroup -AccountName $storageName).Value[1]
    }
    catch {
        Write-Host "Could not get the storage context"
        Write-Host "Abording operation"
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host $_.Exception.ItemName -ForegroundColor Red
        Exit
    }
}

# Create the file share for Customer

try{
    $CustomerFileShare = New-AzStorageShare -Name $customerShareName -Context  $storageContext -ErrorAction Stop
}
catch{
    Write-Host "Could not create the share $customerShareName in $storageName"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.Exception.ItemName -ForegroundColor Red
    Exit
}

# Set up size quota to 5 GiB
try{
    Set-AzStorageShareQuota -ShareName $customerShareName -Context  $storageContext  -Quota 5 -ErrorAction Stop
}
catch{
    Write-Host "Could not set share Quota to 5GiB"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.Exception.ItemName -ForegroundColor Red
    Write-Host "Removing the share $customerShareName in $storageName"
    try {
        Remove-AzStorageShare -Name $customerShareName -Context $storageContext
    }
    catch {
        Write-Host "Could not remove the share $customerShareName in $storageName"
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host $_.Exception.ItemName -ForegroundColor Red
    }
    Exit
}

# Create access policy for customer

try {
    $SASPolicy = New-AzStorageShareStoredAccessPolicy -ShareName $customerShareName `
    -Policy "$customerShareName-policy" -Context $storageContext -StartTime (Get-Date).DateTime `
    -ExpiryTime (Get-Date).AddYears(1).DateTime -Permission "rcwdl" -ErrorAction Stop
}
catch {
    Write-Host "Could not create the policy"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.Exception.ItemName -ForegroundColor Red
    Write-Host "Removing the share $customerShareName in $storageName"
    try {
        Remove-AzStorageShare -Name $customerShareName -Context $storageContext
    }
    catch {
        Write-Host "Could not remove the share $customerShareName in $storageName"
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host $_.Exception.ItemName -ForegroundColor Red
    }
    Exit
}

# Providing SAS Token and File share URI
$URI = "https:\\$($CustomerFileShare.StorageUri.PrimaryUri.Host)\$($CustomerFileShare.Name)"
Write-Host "File Share URI: $URI"

$SASToken = New-AzStorageShareSASToken -ShareName $customerShareName -Policy $SASPolicy -Context $storageContext
Write-Host "SASToken: $SASToken"

Write-Host "Full URI: $URI$SASToken"





