# Function Definitions
function connect-azure {
    # Connect to the Client's Azure Environment
    install-module -name az -allowclobber -scope currentuser
    connect-azaccount
    # Login via web browser
}

function deploy-baseline {
    # Build the Resource Group and assign non-user variables.
    
    $resourcegroupname = "$Client-Infrastructure"
    $vmImage = "2022-datacenter-azure-edition"

    New-azresourcegroup -name "$resourcegroupname" -location $location

    # Build the vNet configurations and create vNet object with two subnets (VM Network & Gateway Subnet)
    $vnet = new-azvirtualnetwork -resourcegroupname $resourcegroupname -location $location -name "$Client-vNet" -addressprefix "$addressprefix"
    $vmvnet = new-azvirtualnetworksubnetconfig -name "$Client-VM-Subnet" -addressprefix $vmsubnet
    $gatewayvnet = new-azvirtualnetworksubnetconfig -name "GatewaySubnet" -addressprefix $gatewaysubnet

    $vnet.subnets.add($vmvnet)
    $vnet.subnets.add($gatewayvnet)
    $vnet = set-azvirtualnetwork -virtualnetwork $vnet

    $publicip = new-azpublicipaddress -name "$vmName-Public-IP" -resourcegroupname $resourcegroupname -location $location -sku basic -allocationmethod Dynamic
    $nsgruleRDP = new-aznetworksecurityruleconfig -name "$vmName-RDP-Rule" -protocol Tcp -direction Inbound -priority 1000 -sourceaddressprefix * -sourceportrange * -destinationaddressprefix * -destinationportrange 3389 -access Allow

    # Build out the Backup Infrastructure (Zone-redundant)
    $vaultname = "$Client-Vault-ZRS"
    $vault = new-azrecoveryservicesvault -name $vaultname -resourcegroupname $resourcegroupname -location $location
    set-azrecoveryservicesvaultproperty -vaultid $vault.id

    $vault1 = get-azrecoveryservicesvault -name $vaultname
    set-azrecoveryservicesbackupproperty -vault $vault1 -backupstorageredundancy ZoneRedundant

    get-azrecoveryservicesvault -name $vaultname -resourcegroupname $resourcegroupname | set-azrecoveryservicesvaultcontext

    # Build the VM network interface card and firewall rules
    $subnetid = $vnet.subnets | where-object { $_.Name -eq "$Client-VM-Subnet" }
    $nsg = new-aznetworksecuritygroup -resourcegroupname $resourcegroupname -location $location -name "$vmName-NSG" -securityrules $nsgRuleRDP
    $nic = new-aznetworkinterface -name "$vmName-NIC" -resourcegroupname $resourcegroupname -location $location -subnetid $subnetid.id -publicipaddressid $publicip.id -networksecuritygroupid $nsg.id

    # Build the VM configuration and create the VM itself.
    $vmConfig = new-azvmconfig -vmname $vmName -vmsize $vmSize | set-azvmoperatingsystem -Windows -Computername $vmName -credential $cred | set-azvmsourceimage -publishername "MicrosoftWindowsServer" -offer "WindowsServer" -skus $vmImage -Version "latest" | add-azvmnetworkinterface -id $nic.id

    new-azvm -resourcegroupname $resourcegroupname -location $location -vm $vmConfig

    # Assign the Enhanced backup policy
    $backuppolicies = get-azrecoveryservicesbackupprotectionpolicy
    $enhanced = $backuppolicies | where-object { $_.Name -eq "EnhancedPolicy" }
    $vm = get-azvm -name $vmName -resourcegroupname $resourcegroupname
    enable-azrecoveryservicesbackupprotection -resourcegroupname $resourcegroupname -name $vmName -Policy $enhanced -vaultid $vault.id

}
function deploy-vpn {
    # Build the VPN Gateway for the client based off the Gateway Subnet configuration from previous vNet
    $vnet = get-azvirtualnetwork
    $resourcegroup = $vnet.resourcegroupname
    $vnetaddressspace = $vnet.addressspace
    $gatewaysubnet = $vnet.subnets | where-object { $_.Name -eq "GatewaySubnet" }

    $vngwpip = new-azpublicipaddress -name "$Client-VPN-Public-IP" -resourcegroupname $resourcegroup -location $location -sku basic -allocationmethod dynamic
    $vngwipconfig = new-azvirtualnetworkgatewayipconfig -name vngwipconfig -subnetid $gatewaysubnet.id -publicipaddressid $vngwpip.id

    new-azvirtualnetworkgateway -name "$Client-VPN-Gateway" -resourcegroupname $resourcegroup -location $location -ipconfigurations $vngwipconfig -gatewaytype vpn -vpntype RouteBased -gatewaysku basic
}

 # Gather Variable Details (User Input Required)
$Client = Read-host -prompt "Enter Client Name"
if ([string]::isnullorwhitespace($Client)) {
    $Client = "DefaultClient"
}
$location = Read-host -prompt "Enter Region (centralus, eastus, westus, etc...) (Default: centralus)"
if ([string]::isnullorwhitespace($location)) {
    $location = "centralus"
}
$vmName = Read-host -prompt "Enter VM Name (Default: DC01)"
if ([string]::isnullorwhitespace($vmName)) {
    $vmName = "DC01"
}
$vmSize = Read-host -prompt "Enter the VM Size Code: (Ex. Standard_DS1_v2) (Default: Standard_DS1_v2)"
if ([string]::isnullorwhitespace($vmSize)) {
    $vmSize = "Standard_DS1_v2"
}
$addressprefix = Read-host -prompt "Enter the Address Space for vNet (Default: 10.1.0.0/16) THIS IS NOT THE VM SUBNET, JUST THE USABLE SCOPE"
if ([string]::isnullorwhitespace($addressprefix)) {
    $addressprefix = "10.1.0.0/16"
}
$vmsubnet = Read-host -prompt "Enter the VM subnet (Default: 10.1.1.0/24) This will be the main subnet for all VMs.  Must fall within the main scope.)"
if ([string]::isnullorwhitespace($vmsubnet)) {
    $vmsubnet = "10.1.1.0/24"
}
$gatewaysubnet = Read-host -prompt "Enter the VPN Gateway Subnet (Default 10.1.2.0/24) This will be used for...something.  Must fall within the main scope.)"
if ([string]::isnullorwhitespace($gatewaysubnet)) {
    $gatewaysubnet = "10.1.2.0/24"
}
$baseline1 = Read-host -prompt "Are you Wanting to Baseline an Azure Environment? (VM, vNet, Backup Config) (Default: Y) (Y/N)"
if ([string]::isnullorwhitespace($baseline1)) {
    $baseline1 = "Y"
}
$vpnline1 = Read-host -prompt "Are you wanting to Deploy a VPN Gateway? (Default: Y) (Y/N)"
if ([string]::isnullorwhitespace($vpnline1)) {
    $vpnline1 = "Y"
}
Read-Host "Input the desired VM Local Admin credentials in the pop-up window"
$cred = get-credential

connect-azure

if ($baseline1 -eq 'Y' -or $baseline1 -eq 'y') {
    deploy-baseline
}

if ($vpnline1 -eq 'Y' -or $vpnline1 -eq 'y') {
    deploy-vpn
}

else {
    Read-Host "Thanks!"
}

Read-Host "Deployment Complete.  Press Any Key to Exit"