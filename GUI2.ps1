Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

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

# Function to create input dialog
function Get-Input($title, $prompt) {
    $formInput = New-Object System.Windows.Forms.Form
    $formInput.StartPosition = 'CenterScreen'
    $formInput.Size = New-Object System.Drawing.Size(300,150)
    $formInput.Text = $title

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,10)
    $label.Size = New-Object System.Drawing.Size(280,20)
    $label.Text = $prompt
    $formInput.Controls.Add($label)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(10,40)
    $textBox.Size = New-Object System.Drawing.Size(260,20)
    $formInput.Controls.Add($textBox)

    $buttonOK = New-Object System.Windows.Forms.Button
    $buttonOK.Location = New-Object System.Drawing.Point(75,70)
    $buttonOK.Size = New-Object System.Drawing.Size(75,23)
    $buttonOK.Text = 'OK'
    $buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $formInput.Controls.Add($buttonOK)

    $formInput.AcceptButton = $buttonOK

    $result = $formInput.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        if ([string]::IsNullOrWhiteSpace($textBox.Text)) {
            return $defaultValue  # Return default value if input is empty
        } else {
            return $textBox.Text
        }
    } else {
        return $defaultValue  # Return default value if dialog is closed or canceled
    }
}

# Main GUI Window
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Azure Deployment Tool'
$form.Size = New-Object System.Drawing.Size(300,200)
$form.StartPosition = 'CenterScreen'

# Checkbox for Baseline
$checkBoxBaseline = New-Object System.Windows.Forms.CheckBox
$checkBoxBaseline.Location = New-Object System.Drawing.Point(10,10)
$checkBoxBaseline.Size = New-Object System.Drawing.Size(280,20)
$checkBoxBaseline.Text = 'Baseline'
$form.Controls.Add($checkBoxBaseline)

# Checkbox for Basic VPN Gateway
$checkBoxVPN = New-Object System.Windows.Forms.CheckBox
$checkBoxVPN.Location = New-Object System.Drawing.Point(10,40)
$checkBoxVPN.Size = New-Object System.Drawing.Size(280,20)
$checkBoxVPN.Text = 'Basic VPN Gateway'
$form.Controls.Add($checkBoxVPN)

# Start Button
$startButton = New-Object System.Windows.Forms.Button
$startButton.Location = New-Object System.Drawing.Point(10,70)
$startButton.Size = New-Object System.Drawing.Size(75,23)
$startButton.Text = 'Start'
$startButton.Add_Click({
    # Gather Variables using GUI prompts
    $Client = Get-Input 'Client Name (Required)' 'Enter Client Name' 
    $location = Get-Input 'Azure Region' 'Enter Region (Default: centralus)' 'centralus'
    # ... (rest of your variables here using Get-Input function)
    $vmName = Get-Input 'VM Name' 'VM Name (Default: DC01)'
    $vmSize = Get-Input 'VM Size Code' 'VM Size (Default: Standard_DS1_v2)' 'Standard_DS1_v2'
    $addressprefix = Get-Input 'Address Space' '(Default: 10.1.0.0/16)' '10.1.0.0/16'
    $vmsubnet = Get-Input 'VM vNet Subnet' 'VM Subnet (Default: 10.1.1.0/24)' '10.1.1.0/24'
    $gatewaysubnet = Get-Input 'Gateway Subnet' 'GW Subnet (Default: 10.1.2.0/24)' '10.1.2.0/24'
    $cred = Get-Input 'VM Administrator Account' 'Leave blank... another window will pop up' '$null'
    $cred = get-credential

    # Run connect-azure
    connect-azure

    # Check if Baseline checkbox is checked and run deploy-baseline
    if ($checkBoxBaseline.Checked) {
        deploy-baseline
    }

    # Check if Basic VPN Gateway checkbox is checked and run deploy-vpn
    if ($checkBoxVPN.Checked) {
        deploy-vpn
    }

    # Show completed message
    [System.Windows.Forms.MessageBox]::Show("Finished")
})
$form.Controls.Add($startButton)

# Cancel Button
$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(100,70)
$cancelButton.Size = New-Object System.Drawing.Size(75,23)
$cancelButton.Text = 'Cancel'
$cancelButton.Add_Click({ $form.Close() })
$form.Controls.Add($cancelButton)

# Show GUI
$form.ShowDialog()
