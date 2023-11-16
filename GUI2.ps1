Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

# Function Definitions
function connect-azure {
    # Your existing connect-azure function code
}

function deploy-baseline {
    # Your existing deploy-baseline function code
}

function deploy-vpn {
    # Your existing deploy-vpn function code
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
    $Client = Get-Input 'Input Required' 'Enter Client Name' 
    $location = Get-Input 'Input Required' 'Enter Region (centralus, eastus, westus, etc...) name must be exact' 'centralus'
    # ... (rest of your variables here using Get-Input function)
    $vmName = Get-Input 'Input Required' 'Enter the Name of the VM' 'DC01'
    $vmSize = Get-Input 'Input Required' 'Enter the Size Code of the VM (Ex. Standard_DS1_v2)' 'Standard_DS1_v2'
    $addressprefix = Get-Input 'Input Required' 'Enter the Address Space for the Environment' '10.1.0.0/16'

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
