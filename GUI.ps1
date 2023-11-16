Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

# Function Definitions
function connect-azure {
    # Your existing function code here
    Read-host "Connect-Azure has run"
}

function deploy-baseline {
    # Your existing function code here
    Read-host "Deploy-baseline has run"
}

function deploy-vpn {
    # Your existing function code here
    Read-host "Deploy-vpn has run"
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
    # Gather Variables
    $Client = Read-host -prompt "Enter Client Name"
    $location = Read-host -prompt "Enter Region (centralus, eastus, westus, etc...) name must be exact"
    # ... (rest of your variables)

    # Call functions
    connect-azure
    if ($checkBoxBaseline.Checked) { deploy-baseline }
    if ($checkBoxVPN.Checked) { deploy-vpn }

    # Finish message
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
