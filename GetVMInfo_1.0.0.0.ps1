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

param(
    [string] $LoginName = "",
    [string] $SecurePasswordLocation = "",
    [bool] $RunPasswordPrompt = $false,
    [bool] $IgnoreDetatchedNics = $false
)

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
                if($nameValCollection[$x].Equals($Name))
                {
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

$VMList = New-Object System.Collections.ArrayList
$DetachedNics = New-Object System.Collections.ArrayList
$PublicIPList = New-Object System.Collections.ArrayList

$nics = Get-AzureRmNetworkInterface

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
        if($config.Name.Length -gt 0)
        {

            foreach($publicIp in $config.PublicIpAddress)
            {
                $temp = ""
                $publicIps = [PSCustomObject]@{
                    NicName = ""
                    IPAddress = New-Object System.Collections.ArrayList
                    Zones = ""
                    
                }

                $publicIps.NicName = Get-AzureIDValue -IDPayload $config.Id -Name "networkInterfaces"
                $publicIps.IPAddress = $config.PublicIpAddress.IpTags
                $publicIps.Zones = $config.PublicIpAddress.Zones

                $PublicIPList.Add($publicIps) | Out-Null

            }
            $VmInfo = [PSCustomObject]@{
                VMName = ""
                PrivateIP = ""
                PrivateIPVersion = ""
                PrivateIPAllocationMethod = ""
                Id = ""
                Subnet = ""
                PublicIPAddresses = ""
                NICName = ""
                IsPrimary = $false
            }
            $VmInfo.VMName = $localVMName
            $VmInfo.IsPrimary = $config.Primary
            
            $VmInfo.Id = $config.Id
            $VmInfo.NICName =   Get-AzureIDValue -IDPayload $nic.IpConfigurationsText -Name "networkInterfaces"
            $VmInfo.PrivateIP = $config.PrivateIpAddress
            $VmInfo.PrivateIPAllocationMethod = $config.PrivateIpAllocationMethod
            if($VmInfo.PrivateIP.Length -le 0 -and $VmInfo.PublicIPAddresses.Length -le 0)
            {
                continue
            }
            $VMList.Add($VmInfo) | Out-Null
        }
    }
}


"`r`n"
"VMs********************`r`n"
foreach($vm in $VmList)
{
    "VM Name: `t" + $vm.VMName
    "NIC Name: `t" + $vm.NICName
    "VM Private IP: `t" + $vm.PrivateIP
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

