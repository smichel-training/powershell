<#
	.DISCLAIMER
		Original script by Floris van der Ploeg
		https://gallery.technet.microsoft.com/Generate-Azure-VM-image-756a0119
		Change log
			- Removed Azure Authentication (script should be executed within a PW session with active connection to Azure)
			- Moved from AzureRM to Az Module

	.SYNOPSIS
		Exports the VM images currently available in Azure to a CSV file.

	.DESCRIPTION
		The exported output will contain all relevant data to create a VM based on the availabled image. The information includes:
			- Publisher
			- Offer
			- Sku
			- Version

		The generated CSV file is in matrix format conaining information if this image is available in the selected location.

	.EXAMPLE
		Export-AzureVMImages.ps1 -Path ./VMImages.csv

		This command will prompt for the Azure credentials and will export the available VM images from all Azure locations to VMImages.csv, using comma (,) as CSV delimiter.

	.EXAMPLE
		Export-AzureVMImages.ps1 -Path ./VMImages.csv -CSVDelimiter ";"

		This command will prompt for the Azure credentials and will export the available VM images from all Azure locations to VMImages.csv, using semicolon (;) as CSV delimiter.

	.EXAMPLE
		Export-AzureVMImages.ps1 -Path ./VMImagesWE.csv -Location westeurope

		This command will prompt for the Azure credentials and will export the available VM images from location West Europe and saves it to VMImagesWE.csv, using comma (,) as CSV delimiter.

	.PARAMETER Path
		Specifies the path to the CSV output file.

	.PARAMETER Credential
		The credentials to use when connecting to Azure. If this parameter is omitted, the script will prompt for credentials by using the Login-AzureRMAccount cmdlet.

	.PARAMETER Location
		Specifies the Azure DataCenter location(s) to retrieve available VM sizes for. If this parameter is omitted, all locations are retrieved and a matrix output is generated. This can either be the location name (eg. westeurope) or the location display name (eg. "West Europe").

	.PARAMETER CSVDelimiter
		Specifies a delimiter to separate the property values. The default is a comma (,). Enter a character, such as a colon (:). To specify a semicolon (;), enclose it in quotation marks.

	.NOTES
		Title:          Export-AzureVMImages.ps1
		Author:         Floris van der Ploeg
		Created:        2016-11-08
		ChangeLog:
			2016-11-08  Initial version
#>

<#	Parameters #>
[CmdletBinding()]
Param
(
	[Parameter(Mandatory=$true,Position=0)]
	[String]$Path,
	[Parameter(Mandatory=$false,Position=1)]
	[Management.Automation.PSCredential]$Credential,
	[Parameter(Mandatory=$false,Position=2)]
	[String[]]$Location,
	[Parameter(Mandatory=$false,Position=3)]
	[Char]$CSVDelimiter = ","
)

<#	Functions #>
	Function Write-Log
	{
		Param
		(
			[Parameter(Mandatory=$true,Position=0)]
			[string]$Value,
			[Parameter(Mandatory=$false,Position=1)]
			[string]$Color = "White"
		)

		Write-Host ("[{0:yyyy-MM-dd HH:mm:ss}] {1}" -f (Get-Date),$Value) -ForegroundColor $Color
	}

<#	Global parameters #>
	$Global:ScriptPath			= Split-Path $MyInvocation.MyCommand.Path -Parent
	$Global:ScriptName			= Split-Path $MyInvocation.MyCommand.Path -Leaf

<#	Main script #>



# Check if the location parameter is set
Write-Log -Value "Checking Azure DataCenter locations" -Color Yellow

$Location = Read-Host "Enter Azure location"

If ($Location -ne $null -and $Location -ne "")
{
	ForEach ($ParamLocation in $Location)
	{
		$Locations += Get-AzLocation -WarningAction SilentlyContinue | Where-Object {$_.Location -eq $ParamLocation -or $_.DisplayName -eq $ParamLocation}
	}
}
Else
{
	Write-Log -Value "No location entered, exiting script" -Color Yellow
}

If ($Locations.Count -ge 1)
{
	# Create the data table to store the VM sizes
	$VMImageTable = New-Object -TypeName System.Data.DataTable
	$VMImageTable.Columns.Add("Publisher") | Out-Null
	$VMImageTable.Columns.Add("Offer") | Out-Null
	$VMImageTable.Columns.Add("Sku") | Out-Null
	$VMImageTable.Columns.Add("Version") | Out-Null

	# Process each location
	ForEach ($LocationItem in $Locations)
	{
		Write-Log -Value ("Processing location {0}" -f $LocationItem.DisplayName)

		# Add the location as column
		$LocationColumnName = "{0} ({1})" -f $LocationItem.DisplayName,$LocationItem.Location
		$VMImageTable.Columns.Add($LocationColumnName) | Out-Null

		# Get the VM images
		ForEach ($VMPublisher in (Get-AzVMImagePublisher -Location $LocationItem.Location))
		{
			Write-Log -Value ("Processing publisher {0}/{1}" -f $LocationItem.Location,$VMPublisher.PublisherName)

			ForEach ($VMImage in ($VMPublisher | Get-AzVMImageOffer | Get-AzVMImageSku | Get-AzVMImage))
			{
				# Check if the size already has been added to the table
				$Rows = $VMImageTable.Select(("[Publisher] = '{0}' AND [Offer] = '{1}' AND [Sku] = '{2}' AND [Version] = '{3}'" -f $VMImage.PublisherName, $VMImage.Offer, $VMImage.Skus, $VMImage.Version))
				If ($Rows.Count -eq 0)
				{
					# Create a new row
					$Row = $VMImageTable.NewRow()

					# Fill the values of each column
					$Row["Publisher"] = $VMImage.PublisherName
					$Row["Offer"] = $VMImage.Offer
					$Row["Sku"] = $VMImage.Skus
					$Row["Version"] = $VMImage.Version
					$Row[$LocationColumnName] = "X"

					# Add the row to the table
					$VMImageTable.Rows.Add($Row)
				}
				Else
				{
					# Update the existing row
					$Rows[0][$LocationColumnName] = "X"
				}
			}
		}
	}

	# Export the datatable to CSV
	Write-Log -Value ("Exporting data to {0}" -f $Path) -Color Green
	$VMImageTable | Export-Csv -Path $Path -NoTypeInformation -Delimiter $CSVDelimiter
}
Else
{
	# Azure location not found
	Write-Error -Message ("Defined Azure location {0} is not valid" -f $Location)
}
