# Get-VMInfo
# This script takes 4 parameters and returns basic information about the Azure virtual machines associated with the login
# you provide.  This script is meant as an example of how you could connect to Azure and run PowerShell.
#
# Parameter $LoginName:  This is the username you would use to log into your Azure account
# Parameter $SecurePasswordLocation: This is the path to a text file that will contain your encrypted password.  this parameter expects
# the full path to the file, for example, c:\Source\Password.txt, or a relative path
# Parameter $RunPasswordPrompt if this is set to true, the user will be prompted to enter their password.  This password will be saved
# in the location you enter for $SecurePasswordLocation.
# Parameter $IgnoreDetachedNics: This parameter will NOT output the detached nics you will only get VM information
# Author: Michael Rasmussen
# Version: 1.0.0.0
# changed the functionality of the script, now I get all nics and all vms and compare them to find out which ones belong together
# Version 1.5.0.0

param(
    # Account to use to get info.  Must have Read access on the objects referenced
    [string] $LoginName = "hockey@michaelrasmussenlive.onmicrosoft.com",
    # text file contains encrypted password
    [string] $SecurePasswordLocation = "c:\Source\mysecurestring.txt",
    # if the encrypted text file is not present on your device, set this to true to create it
    [bool] $RunPasswordPrompt = $false,
    # can list nics that are not attached to a VM
    [bool] $IgnoreDetatchedNics = $true,
    # List storage blob names visable by this account
    [bool] $ListBlobNames = $false
)

$VMList = New-Object System.Collections.ArrayList
$DetachedNics = New-Object System.Collections.ArrayList
$PublicIPList = New-Object System.Collections.ArrayList
$DetachedVHDList = New-Object System.Collections.ArrayList
$NicArrayList = New-Object System.Collections.ArrayList

Function Get-VmInfo
{
    [cmdletbinding()]
    Param
    (

    )
}
Function Find-UnattachedVHDs
{
    [cmdletbinding()]
    Param(
        [string]$StorageAccountName,
        [bool]$DeleteUnattachedVHDs = $false,
        [Microsoft.Azure.Commands.Profile.Models.PSAzureProfile]$SubscriptionProfile,
        [string]$ResourceGroupName
    )
    $disk = Get-AzureRmDisk -ResourceGroupName $ResourceGroupName -DiskName $StorageAccountName
    $SubscriptionProfileeqqqq
    #$deleteUnattachedVHDs=0
    $storageAccounts = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName #-Name $StorageAccountName
    foreach($storageAccount in $storageAccounts)
    {
        
        #$storageKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $storageAccount.ResourceGroupName -Name $storageAccount.StorageAccountName)[0].Value
        $context = $storageAccount.Context #New-AzStorageContext -StorageAccountName $storageAccount.StorageAccountName -StorageAccountKey $storageKey
        $containers = Get-AzureStorageContainer -Name "*" -Context $context
        #$containers = Get-AzStorageContainer -Context $context
        foreach($container in $containers)
        {
            $blobs = Get-AzureStorageBlob -Container $container.Name -Context $context # Get-AzStorageBlob -Container $container.Name -Context $context
            #Fetch all the Page blobs with extension .vhd as only Page blobs can be attached as disk to Azure VMs
            foreach($blob in $blobs)
            {
            #$blob.ICloudBlob.ContentType
            $blob.ICloudBlob.Properties.ContentType
            #$blob.ICloudBlob.BlobType
                
                if($blob.ICloudBlob.Properties.ContentType)
                {
                    if($blob.ICloudBlob.Properties.ContentType.Equals("*/VHD"))
                    {
                        if($blob.ICloudBlob.Properties.LeaseStatus -eq "Unlocked")
                        {
                            $DetachedVHDList.Add($Blob.ICloudBlob.Uri.AbsoluteUri)
                        }
                    }
                }
            }
            # $blobs | Where-Object {$_.BlobType -eq 'PageBlob' -and $_.Name.EndsWith('.vhd')} | ForEach-Object { 
            #     #If a Page blob is not attached as disk then LeaseStatus will be unlocked
            #     if($_.ICloudBlob.Properties.LeaseStatus -eq 'Unlocked'){
            #             #if($deleteUnattachedVHDs -eq 1){
            #             #    Write-Host "Deleting unattached VHD with Uri: $($_.ICloudBlob.Uri.AbsoluteUri)"
            #             #    $_ | Remove-AzStorageBlob -Force
            #             #    Write-Host "Deleted unattached VHD with Uri: $($_.ICloudBlob.Uri.AbsoluteUri)"
            #             #}
            #             #else{
            #                 $DetachedVHDList.Add($_.ICloudBlob.Uri.AbsoluteUri)
            #             #}
            #     }
            # }
        }   
    }
}
Function Get-AzureIDValue
{
    [cmdletbinding()]
    Param (
    [string]$Name,
    [string]$IDPayload
    
    )
    $returnValue = ""
    $IDPayloadJSON = ""
    if(($Name -and $IDPayload) -or ($IDPayload.ToLower() -eq "null"))
    {
        if($IDPayload -match '[{}]' )
        {
            $IDPayloadJSON = ConvertFrom-Json -InputObject $IDPayload
            $fullText = $IDPayloadJSON[0]
            $returnValue = Get-AzureIDValue -IDPayload $fullText.ID -Name $Name
            return $returnValue
        }
        $nameValCollection = $IDPayload.Split('/')
        # could add a $test + 1 to get the next value of the array, which would be what we want.  No need to loop
        #$test = $nameValCollection.IndexOf($Name)
        for($x=0;$x -le $nameValCollection.Count;$x++)
        {
            try
            {
                if($nameValCollection[$x].ToLower().Equals($Name.ToLower()))
                {
                    # check if $nameValueCollection[$x+1] is valid
                    if($nameValCollection.Length -le ($x+1))
                    {
                        #out of range
                        $returnValue = "OutOfRange"
                    }
                    $returnValue = $nameValCollection[$x+1]
                    break
                }
            }
            catch 
            {
                #something went wrong
            }
        }
    }
    return $returnValue
}

#logging in, either promot for info or use text file
#region "Login"
if($RunPasswordPrompt)
{
    Read-host "Enter your password" -assecurestring | convertfrom-securestring | out-file $SecurePasswordLocation
}
if(!(Test-Path -Path $SecurePasswordLocation))
{
    $enterPassword = Read-Host -Prompt "There isn't a password file in the location you specified ($SecurePasswordLocation).  Do you want to enter a password now?"
    if($enterPassword)
    {
        Read-host "Enter your password" -assecurestring | convertfrom-securestring | out-file $SecurePasswordLocation
    }
}
$password = Get-Content $SecurePasswordLocation | ConvertTo-SecureString
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $LoginName, $password
try 
{
    $subscription = Connect-AzureRmAccount -Credential $cred 
    if(!($subscription))
    {
        # error logging into account, exit
        Write-Host "Could not log into account, exiting"
        exit
    }
}
catch 
{
    Write-Host "Could not log into account, exiting"
    exit   
}



$password = Get-Content $SecurePasswordLocation | ConvertTo-SecureString
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $LoginName, $password
$subscription = Connect-AzureRmAccount -Credential $cred 
#$subscription.GetType()
#endregion 

#get VMs and Nics
$nics = Get-AzureRmNetworkInterface
$VMListAr = Get-AzureRmVm 

foreach($nic in $nics)
{
    $localNicName = Get-AzureIDValue -IDPayload $nic.IpConfigurationsText -Name "networkInterfaces"
    #check if valid NicName
    if($nic.IpConfigurationsText.ToLower().Equals("null") -or ($nic.VirtualMachineText.ToLower().Equals("null"))) # -or $nic.IpConfigurationsText -eq $null)
    {
        $payload = ConvertFrom-Json -InputObject $nic.IpConfigurationsText
        $dNicName = Get-AzureIDValue -Name "networkInterfaces" -IDPayload $payload.Id
        $DetachedNics.Add($dNicName) | Out-Null
        continue
    }
    $localVMName = Get-AzureIDValue -IDPayload $nic.VirtualMachineText -Name "virtualMachines"
    #check if valid VMName
    $nicNameValue = ConvertFrom-Json -InputObject $nic.IpConfigurationsText
    foreach($config in $nicNameValue)
    {
        try 
        {            
            $PublicIp = [PSCustomObject]@{
            Name = ""
            PublicIPVersion = ""
            PublicIPAllocationMethod = ""
            ResourceGroup = ""
            VMHostName = ""
        }
            #maybe test IPConfiguration for null
            $PublicIp.Name = Get-AzureIDValue -Name "publicIPAddresses" -IDPayload $config[0].PublicIpAddress.Id     
            $pubIp = Get-AzureRmPublicIpAddress -Name $PublicIp.Name -ResourceGroupName $nic.ResourceGroupName
            $PublicIp.Name = Get-AzureIDValue -Name "publicIPAddresses" -IDPayload $config[0].PublicIpAddress.Id 
            $PublicIp.PublicIPAllocationMethod = $pubIp.PublicIpAllocationMethod
            $PublicIp.PublicIPVersion = $pubIp.PublicIpAddressVersion
            $PublicIp.ResourceGroup = $pubIp.ResourceGroupName
            $PublicIp.VMHostName = $localVMName
            foreach($ip in $PublicIPList)
            {
                if($ip.name.Equals($pubIp.Name))
                {
                    continue
                }
                $PublicIPList.Add($PublicIp)
            }
        }
        catch 
        {
            
        }
        if($config.Name.Length -gt 0)
        {
            $VmNic = [PSCustomObject]@{
                Name = ""
                PrivateIP = ""
                PrivateIPVersion = ""
                PrivateIPAllocationMethod = ""
                ResourceGroup = ""
                Id = ""
                Subnet = ""
                PublicIPAddresses = ""
                IsPrimary = $false
                MacAddress = ""
                VMName = ""
            }
            #Populate VMNic 
            $VmNic.Name = $nic.Name
            $VmNic.ResourceGroup = $nic.ResourceGroupName
            $VmNic.VMName = $localVMName
            
            # is it private or public?

            if($config.PrivateIpAddress.Length -gt 0)
            {
                #private
                $VmNic.PrivateIP = $config.PrivateIpAddress
            }
            elseif($config.PublicIpAddress)
            {
                #might be public    
            }
            else 
            {
                
            }
            $NicArrayList.Add($vmNic) | Out-Null
        } #config
    }#nic
}

#get VM info
foreach($vm in $VMListAr)
{
    $VmInfoObj = [PSCustomObject]@{
        VMName = ""
        VMEnabled = $false
        BootDiagnosticStorageUri = ""
        VMSize = ""
        IsWindows = $false
        IsLinux = $false
        Location = ""
        automaticUpdatesEnabled = $false
        PrivateIP = ""
        PrivateIPVersion = ""
        PrivateIPAllocationMethod = ""
        ResourceGroup = ""
        Id = ""
        Subnet = ""
        PublicIPAddresses = ""
        Nics = New-Object System.Collections.ArrayList
        NICName = ""
        IsPrimary = $false
        ImageReference = [PSCustomObject]@{
            Publisher = ""
            Offer = ""
            Sku = ""
            Version = ""
            Id = ""
        }
    }

    if($vm.StorageProfile.ImageReference.Publisher)
    {
        $VmInfoObj.ImageReference.Publisher = $vm.StorageProfile.ImageReference.Publisher
        $VmInfoObj.ImageReference.Offer = $vm.StorageProfile.ImageReference.Offer
        $VmInfoObj.ImageReference.Sku = $vm.StorageProfile.ImageReference.Sku
        $VmInfoObj.ImageReference.Version = $vm.StorageProfile.ImageReference.Version
        $VmInfoObj.ImageReference.Id = $vm.StorageProfile.ImageReference.Id
    }
    
    $VmInfoObj.Location = $vm.Location
    if($vm.BootDiagnostics.Enabled)
    {
        $VmInfoObj.Enabled = $true
        $VmInfoObj.BootDiagnosticStorageUri = $vm.BootDiagnostics.StorageUri
    }
    $VmInfoObj.VMSize = $vm.HardwareProfile.VmSize

    if($vm.OSProfile.WindowsConfiguration)
    {
        $VmInfoObj.IsWindows = $true
        $VmInfoObj.automaticUpdatesEnabled = $vm.OSProfile.WindowsConfiguration.EnableAutomaticUpdates
    }
    elseif($vm.LinuxConfiguration)
    {
        $VmVmInfoObjInfo.OSProfile.IsLinux = $true
    }
    else 
    {
        
    }

    $VmInfoObj.VMName = $vm.Name
    $vm.Type
    $VmInfoObj.Id = $vm.VmId
    $VmInfoObj.ResourceGroup = $vm.ResourceGroupName
    $VMList.Add($VmInfoObj) | Out-Null
}

#output

"`r`n"
"VMs********************`r`n"
foreach($v in $VMList)
{
    foreach($n in $NicArrayList)
    {
        if((!($null)) -and $n.VMName.Equals($v.VMName))
        {
            $v.Nics.Add($n) | Out-Null
        }
    }
}



foreach($vmLocal in $VMList)
{
    "VM Name: `t`t`t" + $vmLocal.VMName
    "Resource Group `t`t`t" + $vm.ResourceGroupName
    "Location `t`t`t" + $vm.Location
    foreach($localNic in $vmLocal.Nics)
    {
        "NIC Name: `t`t`t" +$localNic.Name
        "Private IP: `t`t`t" + $localNic.PrivateIP
        "Private IP Alloc Mtd: `t`t" + $localNic.PrivateIPAllocationMethod
        
    }

    #"NIC Name: `t`t`t" + $vmLocal.NICName
    "Automatic Updates Enabled: `t" + $vmLocal.automaticUpdatesEnabled
    "Boot Diagnostic Storage URI: `t" + $vmLocal.BootDiagnosticStorageUri
    if($vmLocal.IsWindows)
    {
        "Operating System: `t`t Windows"
    }
    elseif($vmLocal.IsLinux)
    {
        "Operating System: `t`t Linux"
    }

    "Version: `t`t`t" + $vmLocal.ImageReference.Offer
    "Publisher: `t`t`t" + $vmLocal.ImageReference.Publisher
    "SKU: `t`t`t`t" + $vmLocal.ImageReference.Sku
    "Size `t`t`t" + $vmLocal.VMSize
    #"VM Private IP: `t`t`t" + $vmLocal.PrivateIP
    foreach($ipObj in $PublicIPList)
    {
        if($ipObj.VMHostName.Equals($vmLocal.VMName))
        {
            
        }
    }
    "`r`n"
}

if(!($IgnoreDetatchedNics))
{
    "Disconnected NICs*******`r`n"
    foreach($dNic in $DetachedNics)
    {
        "Nic name: `t" + $dNic
    
    }
}
"`r`n"
