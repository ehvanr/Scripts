# Written by Evan Reichard (September 2013)
# http://www.evanreichard.com/?p=136

# Add Appropriate PSSnapin
Add-PSSnapin VMware.VimAutomation.Core

# vCenter Server
$vCenterServer = "vCenter"

# Appropriate Arrays / Hashtable
$VeeamMachines = @("veeam1", "veeam2", "veeam3")
$NotProtectedList = @()
$ProtectedList = @()
$ExceptionList = @()
$ExportTable = @{}

# Email Addresses and SMTP Server
# Sorry, had to get rid of the @ in the email address - WordPress didn't like it.
$toEmailAddress = "JDoe(at)example.com"
$fromEmailAddress = "AuditVMBackup(at)example.com"
$smtpServer = "smtp.example.com"

# Exception full file path
$ExceptionFileDir = "C:\scripts\vmexception.txt"
$OutputFileDir = "C:\scripts\VMAudit.csv"

# Creates ExceptionList array that holds all machines specified in the exception file dir
Get-Content $ExceptionFileDir | Foreach-Object {
	$ExceptionList += $_
}

# --------------- Needs Veeam Backup PowerShell Toolkit ---------------

# Cycles through all Veeam Servers in $VeeamMachines
foreach($VeeamServer in $VeeamMachines){

	# Remote PS Command
	$VeeamProtectedList = Invoke-Command -ComputerName $VeeamServer -ScriptBlock{
		Add-PSSnapin VeeamPSSnapIn

		$VeeamProtectedList = @()

		$Jobs = Get-VBRJob
		foreach ($Job in $Jobs){
			$VMS = $Job.GetObjectsInJob()

			foreach ($VM in $VMS){
				$VeeamProtectedList += $VM.Name
			}
		}

		$VeeamProtectedList
	}

	$ProtectedList += $VeeamProtectedList
}

# Sorts the $ProtectedList array for faster comparing between $CompleteList
$ProtectedList = $ProtectedList | Sort-Object

# -------------------------- Needs PowerCLI --------------------------

# Connects to the vCenter server
Connect-VIServer $vCenterServer

# Acquires a list of all the VM's that are currently powered on in vCenter.
$CompleteList = Get-View -ViewType "VirtualMachine" -Property Name -Filter @{"Runtime.PowerState"="PoweredOn"} | Select Name | Sort-Object Name

# Disconnects - We don't need to be connected anymore. 
Disconnect-VIServer -confirm:$false

# Compares $CompleteList with $ProtectedList and $ExceptionList to create the table
foreach($VM in $CompleteList){
	$VM = $VM.Name

	if($ProtectedList -notcontains $VM){
		if($ExceptionList -contains $VM){
			$ExportTable.Add($VM, "EXCEPTION")
		}else{
			$NotProtectedList += $VM
			$ExportTable.Add($VM, "NOT PROTECTED")
		}
	}else{
		$ExportTable.Add($VM, "PROTECTED")
	}
}

# NOTE! If the ProtectedList contains VM's that are not currently powered on, then $NotProtectedList.Count + $ProtectedList.Count will exceed $CompleteList.Count (I had initially thought this was a bug)

# Sorts ExportTable
$ExportTable = $ExportTable.GetEnumerator() | Sort-Object Value, Name

# Converts to it can easily be exported using Export-CSV
$CSVTable = $ExportTable.GetEnumerator() | foreach{
	New-Object PSObject -Property (@{Computer = $_.Name;Status = $_.Value})
}

# Converts so it can easily be converted to HTML
$HTMLTable = $NotProtectedList.GetEnumerator() | foreach{
	New-Object PSObject -Property (@{Computer = $_})
}

# Exports the table to a CSV file
$CSVTable | Export-CSV $OutputFileDir -NoTypeInformation

# Sends an email if there's a VM in the $NotProtectedList variable
if($NotProtectedList.Count -gt 0){
	$emailBody = $HTMLTable | ConvertTo-HTML | Out-String
	$emailBody = $emailBody -replace "<th>\*</th>","<th>Computer</th>"
	$emailBody += "<br/><p>Exception List: \\$vCenterServer\c$\scripts\vmexception.txt</p><p>CSV of the whole audit: \\$vCenterServer\c$\scripts\VMAudit.csv</p>"

	send-mailmessage -to $toEmailAddress -from $fromEmailAddress -subject "Audit VM Backup - VM(s) are not protected!" -body $emailBody -bodyashtml -smtpserver $smtpServer
}