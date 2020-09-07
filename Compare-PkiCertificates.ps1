<#  
.SYNOPSIS  
Feed this script the thumbprint of two certificates and it will tell you where they differ.

.DESCRIPTION  
Feed this script the thumbprint of two certificates and it will tell you where they differ.
Note that PowerShell v2 (Server 2008R2 & Windows 7) doesn't report all certificate values and can't be reliably trusted for an accurate comparison.

.NOTES  
    Version				: 1.8
	Date				: 7th September 2020
	Author    			: Greig Sheridan
	
	Revision History 	:
				v1.8: 7th September 2020
					Added the capture/comparison of Enhanced Key Usage.
	
				v1.7: 12th May 2018
					Added an abort line that kills the script when running in the (unsupported) PowerShell ISE. (Screen-width and coloured output don't work)
				
				v1.6: 30th March 2018
					Corrected bug where a SAN would show incorrectly if there was a difference in case between the two certs
					Set the 'warning' highlighting to all attributes where the case differs between certificates
					Added an "-ignorecase" switch, for those who don't care about case-sensitivity
					Fixed bug where Win7/P$v2 didn't like my Write-Progress lines without a "Status" attribute
					
				v1.5: 24th December 2017
					Fixed a bug introduced in 1.4 where the CN was splitting on commas AND spaces, resulting in malformed States especially
					Incorporated my version of Pat's "Get-UpdateInfo". Credit: https://ucunleashed.com/3168
	
				v1.4: 15th June 2017
					Found the v1.3 change to reading certs was causing some values not to show in some environments & errors in others.
						Reverted to the v1.2 approach (but now reading all of cert:\localmachine) pending further investigation.
					Changed the way the "Subject" is parsed, from Split(",") to Split(", ") & stripped spaces from following ".StartsWith" tests
					Added "E=" for those scripts that include an e-mail address
					
				v1.3: 19th February 2017
					Keen follower "Soder" pointed out that certs might live in more places than just "cert:\localmachine\My" and I was doing the 
					 script a disservice by not looking in the other repositories. So now it checks them all. Thanks Soder!
					Fixed an array declaration bug where the "master SAN list" incorrectly represented SANs if the cert had only one SAN
					Added a null test to the Key Usages sort, otherwise a cert with no usages would spray red on the screen
	
				v1.2: 22nd January 2017
					Changed the script comparison engine to take full advantage of your current visible screen width.
					Sorted Key Usages before sending them to the Compare engine in an effort to reduce false positives.
	
				v1.1: 28th April 2016
					Changed the way I read SANs for improved Server 2008 capability
					
				v1.0: 27 March 2015
					Initial release.
					

.LINK  
    https://greiginsydney.com/Compare-PkiCertificates.ps1

.EXAMPLE
	.\Compare-PkiCertificates.ps1
 
	Description
	-----------
    With no input parameters passed to it, the script will prompt you to enter two thumbprints.


.EXAMPLE
	.\Compare-PkiCertificates.ps1 -Thumb1 12345678ABCD -Thumb2 ABCDEFG1234
 
	Description
	-----------
	Compares the two certificates on-screen
	
.EXAMPLE
	.\Compare-PkiCertificates.ps1 "?12 34 56 78 AB CD" "AB CD EF G1 23 45"
 
	Description
	-----------
	Compares the two certificates on-screen.
	Accepts a paste direct from the Certs Console, stripping spaces and the mystery "?" that's always at the start of your copy.

.PARAMETER Thumbprint1
		String. Thumbprint
		
.PARAMETER Thumbprint2
		String. Thumbprint		
		
.PARAMETER SkipUpdateCheck
		Boolean. Skips the automatic check for an Update. Courtesy of Pat: http://www.ucunleashed.com/3168		
		
.PARAMETER IgnoreCase
		Boolean. Suppresses the display of warnings when the case of an attribute differs between certificates
#>

[CmdletBinding(SupportsShouldProcess = $False)]
Param(
	
	[Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $True)]
    [alias("Thumb1")][string]$Thumbprint1,
	
	[Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $True)]
    [alias("Thumb2")][string]$Thumbprint2,
	
	[switch] $SkipUpdateCheck,
	[switch] $IgnoreCase
)

$ScriptVersion = "1.7" 
$Error.Clear()         

#--------------------------------
# START FUNCTIONS ---------------
#--------------------------------

function CompareCertParameters
{
	param (
	[Parameter(Mandatory=$True)][string]$parameterName,
	[Parameter(Mandatory=$False)][string]$Cert1Value = "",
	[Parameter(Mandatory=$False)][string]$Cert2Value = "",
	[Parameter(Mandatory=$False)][bool]$WarnOnly
	)

	#If no highlighting, default to the user's normal colours:
	$OldBackground = $UserBackgroundColour 
	$OldForeground = $USerForegroundColour 
	$NewBackground= $UserBackgroundColour 
	$NewForeground= $USerForegroundColour 
	
	if ($Cert1Value -ne $Cert2Value)
	{
		if ($Cert2Value -ne "")
		{
			if ($WarnOnly) #For some values a difference is expected & OK. Warn rather than Err.
			{
				$NewForeground = $UserColours.WarningForegroundColor  
				$NewBackground = $UserColours.WarningBackgroundColor  
			}
			else
			{
				#Error
				$NewForeground = $UserColours.ErrorForegroundColor    
				$NewBackground = $UserColours.ErrorBackgroundColor 
			}
		}
		else
		{
			#If the value is no longer present in the new cert, apply the highlight to the old cert:
			#Error
			$OldForeground = $UserColours.ErrorForegroundColor    
			$OldBackground = $UserColours.ErrorBackgroundColor 
		}
	}
	else
	{
		#This bit highlights the new value if both are identical but differ in case
		if ((!($Cert1Value -ccontains $Cert2Value)) -and (!$IgnoreCase))
		{
			$NewForeground = $UserColours.WarningForegroundColor  
			$NewBackground = $UserColours.WarningBackgroundColor 
		}
	}
	$Cert1Value =  truncate $Cert1Value ($global:ColumnWidth)
	$Cert2Value =  truncate $Cert2Value ($global:ColumnWidth)
	write-host ($parameterName).PadRight($global:HeaderWidth," ") -noNewLine 
	write-host " " -NoNewLine
	write-host ($Cert1Value).PadRight($global:ColumnWidth,' ') -noNewLine -foregroundcolor $OldForeground -backgroundcolor $OldBackground
	write-host " " -NoNewLine
	write-host ($Cert2Value).PadRight($global:ColumnWidth,' ') -foregroundcolor $NewForeground -backgroundcolor $NewBackground
}

function truncate
{
	param ([string]$value, [int]$MaxLength)
	
	if ($MaxLength -gt 0) { $MaxLength-- }
	if ($value.Length -gt $MaxLength)
	{
		$value = $value[0..($MaxLength - 3)] -join ""
		$value += "..."
	}
	return $value
}

function DecodeSANs
{
	param (
	[Parameter(Mandatory=$True)][System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert
	) 
	$SANs = @()
	#Server 2008(?) hides the SANs away here:
	try
	{
		$S2008SANs = ($cert.Extensions | Where-Object {$_.Oid.FriendlyName -match "subject alternative name"}).Format(1)
	}
	catch 
	{
		$S2008SANs = ""
	}
	$S2008SANs = [regex]::replace($S2008SANs, "`r`n", "") #Trim CRLFs
	$S2008SANsArray = $S2008SANs -split "DNS Name="
	$SANs += $S2008SANsArray
	$SANs  = $SANs | ? {$_} | select -uniq 	#De-dupe
	return $SANs
}


function Get-UpdateInfo
{
  <#
      .SYNOPSIS
      Queries an online XML source for version information to determine if a new version of the script is available.
	  *** This version customised by Greig Sheridan. @greiginsydney https://greiginsydney.com ***

      .DESCRIPTION
      Queries an online XML source for version information to determine if a new version of the script is available.

      .NOTES
      Version               : 1.2 - See changelog at https://ucunleashed.com/3168 for fixes & changes introduced with each version
      Wish list             : Better error trapping
      Rights Required       : N/A
      Sched Task Required   : No
      Lync/Skype4B Version  : N/A
      Author/Copyright      : © Pat Richard, Office Servers and Services (Skype for Business) MVP - All Rights Reserved
      Email/Blog/Twitter    : pat@innervation.com  https://ucunleashed.com  @patrichard
      Donations             : https://www.paypal.me/PatRichard
      Dedicated Post        : https://ucunleashed.com/3168
      Disclaimer            : You running this script/function means you will not blame the author(s) if this breaks your stuff. This script/function 
                            is provided AS IS without warranty of any kind. Author(s) disclaim all implied warranties including, without limitation, 
                            any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use 
                            or performance of the sample scripts and documentation remains with you. In no event shall author(s) be held liable for 
                            any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss 
                            of business information, or other pecuniary loss) arising out of the use of or inability to use the script or 
                            documentation. Neither this script/function, nor any part of it other than those parts that are explicitly copied from 
                            others, may be republished without author(s) express written permission. Author(s) retain the right to alter this 
                            disclaimer at any time. For the most up to date version of the disclaimer, see https://ucunleashed.com/code-disclaimer.
      Acknowledgements      : Reading XML files 
                            http://stackoverflow.com/questions/18509358/how-to-read-xml-in-powershell
                            http://stackoverflow.com/questions/20433932/determine-xml-node-exists
      Assumptions           : ExecutionPolicy of AllSigned (recommended), RemoteSigned, or Unrestricted (not recommended)
      Limitations           : 
      Known issues          : 

      .EXAMPLE
      Get-UpdateInfo -Title "Compare-PkiCertificates.ps1"

      Description
      -----------
      Runs function to check for updates to script called <Varies>.

      .INPUTS
      None. You cannot pipe objects to this script.
  #>
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
	[string] $title
	)
	try
	{
		[bool] $HasInternetAccess = ([Activator]::CreateInstance([Type]::GetTypeFromCLSID([Guid]'{DCB00C01-570F-4A9B-8D69-199FDBA5723B}')).IsConnectedToInternet)
		if ($HasInternetAccess)
		{
			write-verbose "Performing update check"
			# ------------------ TLS 1.2 fixup from https://github.com/chocolatey/choco/wiki/Installation#installing-with-restricted-tls
			$securityProtocolSettingsOriginal = [System.Net.ServicePointManager]::SecurityProtocol
			try {
			  # Set TLS 1.2 (3072). Use integers because the enumeration values for TLS 1.2 won't exist in .NET 4.0, even though they are 
			  # addressable if .NET 4.5+ is installed (.NET 4.5 is an in-place upgrade).
			  [System.Net.ServicePointManager]::SecurityProtocol = 3072
			} catch {
			  Write-verbose 'Unable to set PowerShell to use TLS 1.2 due to old .NET Framework installed.'
			}
			# ------------------ end TLS 1.2 fixup
			[xml] $xml = (New-Object -TypeName System.Net.WebClient).DownloadString('https://greiginsydney.com/wp-content/version.xml')
			[System.Net.ServicePointManager]::SecurityProtocol = $securityProtocolSettingsOriginal #Reinstate original SecurityProtocol settings
			$article  = select-XML -xml $xml -xpath "//article[@title='$($title)']"
			[string] $Ga = $article.node.version.trim()
			if ($article.node.changeLog)
			{
				[string] $changelog = "This version includes: " + $article.node.changeLog.trim() + "`n`n"
			}
			if ($Ga -gt $ScriptVersion)
			{
				$wshell = New-Object -ComObject Wscript.Shell -ErrorAction Stop
				$updatePrompt = $wshell.Popup("Version $($ga) is available.`n`n$($changelog)Would you like to download it?",0,"New version available",68)
				if ($updatePrompt -eq 6)
				{
					Start-Process -FilePath $article.node.downloadUrl
					Write-Warning "Script is exiting. Please run the new version of the script after you've downloaded it."
					exit
				}
				else
				{
					write-verbose "Upgrade to version $($ga) was declined"
				}
			}
			elseif ($Ga -eq $ScriptVersion)
			{
				write-verbose "Script version $($Scriptversion) is the latest released version"
			}
			else
			{
				write-verbose "Script version $($Scriptversion) is newer than the latest released version $($ga)"
			}
		}
		else
		{
		}
	
	} # end function Get-UpdateInfo
	catch
	{
		write-verbose "Caught error in Get-UpdateInfo"
		if ($Global:Debug)
		{				
			$Global:error | fl * -f #This dumps to screen as white for the time being. I haven't been able to get it to dump in red
		}
	}
}

#--------------------------------
# END  FUNCTIONS ---------------
#--------------------------------


#--------------------------------
# THE FUN STARTS HERE -----------
#--------------------------------

## #Requires -RunAsAdministrator #Can't use this here - it wasn't added until v4.
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
 {    
  Echo "This script needs to be run As Admin"
  Break
 }
# Why force Admin? Strangely, the keysize isn't reported if you run as an ordinary user.

if ($skipupdatecheck)
{
	write-verbose "Skipping update check"
}
else
{
	write-progress -id 1 -Activity "Performing update check" -Status "Running Get-UpdateInfo" -PercentComplete (50)
	Get-UpdateInfo -title "Compare-PkiCertificates.ps1"
	write-progress -id 1 -Activity "Back from performing update check" -Status "Running Get-UpdateInfo" -Completed
}

If ($PsVersionTable.PsVersion.Major -lt 3)
{
	write-warning "This version of PowerShell is not able to read some certificate values."
	write-warning "Its output cannot be guaranteed to be complete."
}
 
$UserColours = (Get-Host).PrivateData
$USerForegroundColour = (get-host).ui.rawui.ForegroundColor
$UserBackgroundColour = (get-host).ui.rawui.BackgroundColor
$UserScreenWidth = [int](get-host).UI.rawui.Windowsize.Width
if ($UserScreenWidth -eq 0)
{
	echo "Powershell ISE detected. It doesn't report the screen width & mishandles/errs when writing to the screen in colour"
	echo "Please re-run from a normal PS window, elevated"
	break
}
$global:HeaderWidth = ([Math]::Truncate($UserScreenWidth * 0.2) -2) #Subtracting 2 allows for the space that P$ automatically
$global:ColumnWidth = ([Math]::Truncate($UserScreenWidth * 0.4) -2) # puts between the columns when using the PadLeft/Right commands

$Thumbprint1 = [regex]::replace($Thumbprint1, "[^A-Fa-f0-9]", "") #Trim spaces and the leading "?" that comes if you paste
$Thumbprint2 = [regex]::replace($Thumbprint2, "[^A-Fa-f0-9]", "") # direct from the cert's console

$Certs = gci "cert:\localmachine" -recurse

$Cert1 = $Certs | ? {$_.Thumbprint -match $Thumbprint1} | Select-Object -first 1
$Cert2 = $Certs | ? {$_.Thumbprint -match $Thumbprint2} | Select-Object -first 1

if (($Cert1 -ne $null) -and ($Cert2 -ne $null))
{
	#Read all the properties of BOTH certs & then de-dupe. This will trap any that are present on one but not the other:
	$properties  = ($Cert1 | Get-Member -MemberType Property | Select-Object  -ExpandProperty Name)
	$properties += ($Cert2 | Get-Member -MemberType Property | Select-Object  -ExpandProperty Name)
	$properties  = $properties  | select -uniq	
	
	write-host ""
	write-host  "Attribute".PadRight($HeaderWidth, " ")"Certificate 1".PadRight($ColumnWidth, " ")"Certificate 2".PadRight($ColumnWidth, " ")
	write-host  ("---------").PadRight($HeaderWidth, " ")("-------------").PadRight($ColumnWidth, " ")("-------------").PadRight($ColumnWidth, " ")
	foreach ($property in $properties)
	{
		switch ($property)
		{
			{($_ -eq "Thumbprint") -or ($_ -eq "PrivateKey")}
			{
				#Skip Thumbprint - we'll manually write it as the last parameter. Private Key we do manually under "HasPrivateKey"
				Continue
			} 
			{($_ -eq "notbefore") -or ($_ -eq "notafter") -or ($_ -eq "SerialNumber")}
			{
				CompareCertParameters $property $Cert1."$($property)" $Cert2."$($property)" 1 #Force changes to show as yellow - they're expected
			}
			"issuer"
			{
				CompareCertParameters $property $Cert1."$($property)" $Cert2."$($property)"
			}
			"FriendlyName"
			{
				$Cert1FriendlyName = "<None>"
				$Cert2FriendlyName = "<None>"
				if ($Cert1.FriendlyName -ne "") { $Cert1FriendlyName = $Cert1.FriendlyName }
				if ($Cert2.FriendlyName -ne "") { $Cert2FriendlyName = $Cert2.FriendlyName }
				CompareCertParameters "Friendly Name" $Cert1FriendlyName $Cert2FriendlyName
			}
			"HasPrivateKey"
			{
				CompareCertParameters $property $Cert1."$($property)" $Cert2."$($property)"
				CompareCertParameters "Key Size" $Cert1.PrivateKey.KeySize $Cert2.PrivateKey.KeySize 
			}
			"subject"
			{
				CompareCertParameters "Subject" $Cert1."$($property)" $Cert2."$($property)"
				$Cert1Subject = ($Cert1.Subject).Split(",")
				$Cert1SubjectItem = @{}
				foreach ($Cert1SubjectValue in $Cert1Subject)
				{
					$Cert1SubjectValue = $Cert1SubjectValue.Trim()
					if ($Cert1SubjectValue.StartsWith("CN=")) { $Cert1SubjectItem.Add("Common Name", 	$Cert1SubjectValue.Substring(3)) }
					if ($Cert1SubjectValue.StartsWith("C="))  { $Cert1SubjectItem.Add("Country", 		$Cert1SubjectValue.Substring(2)) }
					if ($Cert1SubjectValue.StartsWith("S="))  { $Cert1SubjectItem.Add("State",   		$Cert1SubjectValue.Substring(2)) }
					if ($Cert1SubjectValue.StartsWith("L="))  { $Cert1SubjectItem.Add("City",    		$Cert1SubjectValue.Substring(2)) }
					if ($Cert1SubjectValue.StartsWith("O="))  { $Cert1SubjectItem.Add("Organisation", 	$Cert1SubjectValue.Substring(2)) }
					if ($Cert1SubjectValue.StartsWith("OU=")) { $Cert1SubjectItem.Add("OU",      		$Cert1SubjectValue.Substring(3)) }
					if ($Cert1SubjectValue.StartsWith("E="))  { $Cert1SubjectItem.Add("E-mail",      	$Cert1SubjectValue.Substring(2)) }
				}
				
				$Cert2Subject = ($Cert2.Subject).Split(",")						
				$Cert2SubjectItem = @{}
				foreach ($Cert2SubjectValue in $Cert2Subject)
				{
					$Cert2SubjectValue = $Cert2SubjectValue.Trim()
					if ($Cert2SubjectValue.StartsWith("CN=")) { $Cert2SubjectItem.Add("Common Name", 	$Cert2SubjectValue.Substring(3)) }
					if ($Cert2SubjectValue.StartsWith("C="))  { $Cert2SubjectItem.Add("Country", 		$Cert2SubjectValue.Substring(2)) }
					if ($Cert2SubjectValue.StartsWith("S="))  { $Cert2SubjectItem.Add("State", 			$Cert2SubjectValue.Substring(2)) }
					if ($Cert2SubjectValue.StartsWith("L="))  { $Cert2SubjectItem.Add("City", 			$Cert2SubjectValue.Substring(2)) }
					if ($Cert2SubjectValue.StartsWith("O="))  { $Cert2SubjectItem.Add("Organisation", 	$Cert2SubjectValue.Substring(2)) }
					if ($Cert2SubjectValue.StartsWith("OU=")) { $Cert2SubjectItem.Add("OU", 			$Cert2SubjectValue.Substring(3)) }
					if ($Cert2SubjectValue.StartsWith("E="))  { $Cert2SubjectItem.Add("E-mail",      	$Cert2SubjectValue.Substring(2)) }
				}
				CompareCertParameters "Common Name" 	$Cert1SubjectItem.Get_Item("Common Name") 		$Cert2SubjectItem.Get_Item("Common Name")
				CompareCertParameters "Country" 		$Cert1SubjectItem.Get_Item("Country") 			$Cert2SubjectItem.Get_Item("Country")
				CompareCertParameters "State" 			$Cert1SubjectItem.Get_Item("State") 			$Cert2SubjectItem.Get_Item("State")
				CompareCertParameters "City" 			$Cert1SubjectItem.Get_Item("City") 				$Cert2SubjectItem.Get_Item("City")
				CompareCertParameters "Organisation" 	$Cert1SubjectItem.Get_Item("Organisation") 		$Cert2SubjectItem.Get_Item("Organisation")
				CompareCertParameters "OU" 				$Cert1SubjectItem.Get_Item("OU") 				$Cert2SubjectItem.Get_Item("OU")
				CompareCertParameters "E-mail"			$Cert1SubjectItem.Get_Item("E-mail") 			$Cert2SubjectItem.Get_Item("E-mail")
			}
			"SignatureAlgorithm"
			{
				CompareCertParameters "Sig Algorithm" ($Cert1."$($property)").FriendlyName ($Cert2."$($property)").FriendlyName 
			}
			{($_ -eq "SubjectName") -or ($_ -eq "IssuerName")}
			{
				CompareCertParameters $property ($Cert1."$($property)").Name ($Cert2."$($property)").Name
			}
			"Extensions"
			{
				# Retrieve the usages -> to String -> Strip spaces -> to Array -> Sort -> Back to CSV string !
				$Cert1UsagesSorted = ""
				$Cert2UsagesSorted = ""
				if ($Cert1.extensions.KeyUsages -ne $null)
				{
					$Cert1UsagesSorted = ((($Cert1.extensions.KeyUsages).ToString() -replace " ","").Split(",") | sort) -join ", "
				}
				if ($Cert2.extensions.KeyUsages -ne $null)
				{
					$Cert2UsagesSorted = ((($Cert2.extensions.KeyUsages).ToString() -replace " ","").Split(",") | sort) -join ", "
				}
				CompareCertParameters "Key Usages" $Cert1UsagesSorted $Cert2UsagesSorted
				
				#Enhanced Key Usage:
				$Cert1EKU = @()
				$Cert1EKUSorted = ""
				$Cert2EKU = @()
				$Cert2EKUSorted = ""
				if ($Cert1.extensions.EnhancedKeyUsages -ne $null)
				{
					foreach($certEku in $Cert1.extensions.EnhancedKeyUsages)
					{
						$Cert1EKU += (($CertEKU.FriendlyName).ToString())
					}
					$Cert1EKUSorted = ($Cert1EKU | sort) -join ", "
					
				}
				if ($Cert2.extensions.EnhancedKeyUsages -ne $null)
				{
					foreach($certEku in $Cert2.extensions.EnhancedKeyUsages)
					{
						$Cert2EKU += (($CertEKU.FriendlyName).ToString())
					}
					$Cert2EKUSorted = ($Cert2EKU | sort) -join ", "
				}
				CompareCertParameters "Enhanced Key Usage" $Cert1EKUSorted $Cert2EKUSorted
			}
			default 
			{	
			}
		}
	}
	#Create a master SAN list (like we did with Properties above) & de-dupe:
	$AllSANs = @()
	$Cert1SANs = DecodeSANs $Cert1
	$AllSANs += $Cert1SANs
	$Cert2SANs = DecodeSANs $Cert2
	$AllSANs += $Cert2SANs
	$AllSANs = $AllSANs  | select -uniq	
	foreach ($SAN in $AllSANs)
	{
		if (($Cert1SANs -contains $SAN) -and ($Cert2SANs -contains $SAN))
		{
			# OK, so we have the same value - but what about the case?
			if (($Cert1SANs -ccontains $SAN) -and ($Cert2SANs -ccontains $SAN))
			{
				#Nope, both are identical - OK to display as-is
				CompareCertParameters "SAN" $SAN $SAN 
			}
			else
			{
				#The case of this SAN differs between the 2 certs. Now we need to carefully display the actual value from each cert
				#We know without question that this SAN appears in BOTH certs, so in the two steps below we:
				# 1) wait until this CASE instance of it is in Cert1, then
				# 2) Loop through all the SANs in Cert2 until we find the one that matches.
				# This makes sure we show them against the correct cert in their correct case, and that the SAN only shows once (as it's in the master SAN list twice due to the list's case-sensitivity)
				if ($Cert1SANs -ccontains $SAN)
				{
					#Now cycle through all the certs on Cert2 until we find the matching one, then send the right ones to the display function
					foreach ($OtherCaseSAN in $Cert2SANs)
					{
						if ($OtherCaseSAN -contains $SAN)
						{
							CompareCertParameters "SAN" $SAN $OtherCaseSAN 
						}
					}
				}
			}
		}
		elseif (($Cert1SANs -contains $SAN) -and ($Cert2SANs -notcontains $SAN))
		{
			CompareCertParameters "SAN" $SAN "" 
		}
		else
		{
			CompareCertParameters "SAN" "" $SAN 
		}
	}
	#Write the Thumbprint last:
	CompareCertParameters "Thumbprint" $Cert1.Thumbprint $Cert2.Thumbprint 1 #Force changes to show as yellow - they're expected

	write-host # A blank line at the end
}
else
{
	if ($cert1 -eq $null) { write-warning "The certificate with thumbprint ""$Thumbprint1"" could not be found" }
	if ($cert2 -eq $null) { write-warning "The certificate with thumbprint ""$Thumbprint2"" could not be found" }
}

#References:
# http://social.technet.microsoft.com/wiki/contents/articles/1447.display-subject-alternative-names-of-a-certificate-with-powershell.aspx
# https://www.leeholmes.com/blog/2007/01/09/filtering-on-the-certificate-provider/

#Code signing certificate kindly provided by Digicert:
# SIG # Begin signature block
# MIIceAYJKoZIhvcNAQcCoIIcaTCCHGUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUqsOYBEwEJ3lglF+vlLZnk0/Y
# /0SgghenMIIFMDCCBBigAwIBAgIQA1GDBusaADXxu0naTkLwYTANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMB4XDTIwMDQxNzAwMDAwMFoXDTIxMDcw
# MTEyMDAwMFowbTELMAkGA1UEBhMCQVUxGDAWBgNVBAgTD05ldyBTb3V0aCBXYWxl
# czESMBAGA1UEBxMJUGV0ZXJzaGFtMRcwFQYDVQQKEw5HcmVpZyBTaGVyaWRhbjEX
# MBUGA1UEAxMOR3JlaWcgU2hlcmlkYW4wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
# ggEKAoIBAQC0PMhHbI+fkQcYFNzZHgVAuyE3BErOYAVBsCjZgWFMhqvhEq08El/W
# PNdtlcOaTPMdyEibyJY8ZZTOepPVjtHGFPI08z5F6BkAmyJ7eFpR9EyCd6JRJZ9R
# ibq3e2mfqnv2wB0rOmRjnIX6XW6dMdfs/iFaSK4pJAqejme5Lcboea4ZJDCoWOK7
# bUWkoqlY+CazC/Cb48ZguPzacF5qHoDjmpeVS4/mRB4frPj56OvKns4Nf7gOZpQS
# 956BgagHr92iy3GkExAdr9ys5cDsTA49GwSabwpwDcgobJ+cYeBc1tGElWHVOx0F
# 24wBBfcDG8KL78bpqOzXhlsyDkOXKM21AgMBAAGjggHFMIIBwTAfBgNVHSMEGDAW
# gBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAdBgNVHQ4EFgQUzBwyYxT+LFH+GuVtHo2S
# mSHS/N0wDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMHcGA1Ud
# HwRwMG4wNaAzoDGGL2h0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3Vy
# ZWQtY3MtZzEuY3JsMDWgM6Axhi9odHRwOi8vY3JsNC5kaWdpY2VydC5jb20vc2hh
# Mi1hc3N1cmVkLWNzLWcxLmNybDBMBgNVHSAERTBDMDcGCWCGSAGG/WwDATAqMCgG
# CCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BTMAgGBmeBDAEE
# ATCBhAYIKwYBBQUHAQEEeDB2MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wTgYIKwYBBQUHMAKGQmh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydFNIQTJBc3N1cmVkSURDb2RlU2lnbmluZ0NBLmNydDAMBgNVHRMB
# Af8EAjAAMA0GCSqGSIb3DQEBCwUAA4IBAQCtV/Nu/2vgu+rHGFI6gssYWfYLEwXO
# eJqOYcYYjb7dk5sRTninaUpKt4WPuFo9OroNOrw6bhvPKdzYArXLCGbnvi40LaJI
# AOr9+V/+rmVrHXcYxQiWLwKI5NKnzxB2sJzM0vpSzlj1+fa5kCnpKY6qeuv7QUCZ
# 1+tHunxKW2oF+mBD1MV2S4+Qgl4pT9q2ygh9DO5TPxC91lbuT5p1/flI/3dHBJd+
# KZ9vYGdsJO5vS4MscsCYTrRXvgvj0wl+Nwumowu4O0ROqLRdxCZ+1X6a5zNdrk4w
# Dbdznv3E3s3My8Axuaea4WHulgAvPosFrB44e/VHDraIcNCx/GBKNYs8MIIFMDCC
# BBigAwIBAgIQBAkYG1/Vu2Z1U0O1b5VQCDANBgkqhkiG9w0BAQsFADBlMQswCQYD
# VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGln
# aWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0Ew
# HhcNMTMxMDIyMTIwMDAwWhcNMjgxMDIyMTIwMDAwWjByMQswCQYDVQQGEwJVUzEV
# MBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29t
# MTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgQ29kZSBTaWduaW5n
# IENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA+NOzHH8OEa9ndwfT
# CzFJGc/Q+0WZsTrbRPV/5aid2zLXcep2nQUut4/6kkPApfmJ1DcZ17aq8JyGpdgl
# rA55KDp+6dFn08b7KSfH03sjlOSRI5aQd4L5oYQjZhJUM1B0sSgmuyRpwsJS8hRn
# iolF1C2ho+mILCCVrhxKhwjfDPXiTWAYvqrEsq5wMWYzcT6scKKrzn/pfMuSoeU7
# MRzP6vIK5Fe7SrXpdOYr/mzLfnQ5Ng2Q7+S1TqSp6moKq4TzrGdOtcT3jNEgJSPr
# CGQ+UpbB8g8S9MWOD8Gi6CxR93O8vYWxYoNzQYIH5DiLanMg0A9kczyen6Yzqf0Z
# 3yWT0QIDAQABo4IBzTCCAckwEgYDVR0TAQH/BAgwBgEB/wIBADAOBgNVHQ8BAf8E
# BAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwMweQYIKwYBBQUHAQEEbTBrMCQGCCsG
# AQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0
# dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RD
# QS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaGNGh0dHA6Ly9jcmwz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwTwYDVR0g
# BEgwRjA4BgpghkgBhv1sAAIEMCowKAYIKwYBBQUHAgEWHGh0dHBzOi8vd3d3LmRp
# Z2ljZXJ0LmNvbS9DUFMwCgYIYIZIAYb9bAMwHQYDVR0OBBYEFFrEuXsqCqOl6nED
# wGD5LfZldQ5YMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA0GCSqG
# SIb3DQEBCwUAA4IBAQA+7A1aJLPzItEVyCx8JSl2qB1dHC06GsTvMGHXfgtg/cM9
# D8Svi/3vKt8gVTew4fbRknUPUbRupY5a4l4kgU4QpO4/cY5jDhNLrddfRHnzNhQG
# ivecRk5c/5CxGwcOkRX7uq+1UcKNJK4kxscnKqEpKBo6cSgCPC6Ro8AlEeKcFEeh
# emhor5unXCBc2XGxDI+7qPjFEmifz0DLQESlE/DmZAwlCEIysjaKJAL+L3J+HNdJ
# RZboWR3p+nRka7LrZkPas7CM1ekN3fYBIM6ZMWM9CBoYs4GbT8aTEAb8B4H6i9r5
# gkn3Ym6hU/oSlBiFLpKR6mhsRDKyZqHnGKSaZFHvMIIGajCCBVKgAwIBAgIQAwGa
# Ajr/WLFr1tXq5hfwZjANBgkqhkiG9w0BAQUFADBiMQswCQYDVQQGEwJVUzEVMBMG
# A1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEw
# HwYDVQQDExhEaWdpQ2VydCBBc3N1cmVkIElEIENBLTEwHhcNMTQxMDIyMDAwMDAw
# WhcNMjQxMDIyMDAwMDAwWjBHMQswCQYDVQQGEwJVUzERMA8GA1UEChMIRGlnaUNl
# cnQxJTAjBgNVBAMTHERpZ2lDZXJ0IFRpbWVzdGFtcCBSZXNwb25kZXIwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCjZF38fLPggjXg4PbGKuZJdTvMbuBT
# qZ8fZFnmfGt/a4ydVfiS457VWmNbAklQ2YPOb2bu3cuF6V+l+dSHdIhEOxnJ5fWR
# n8YUOawk6qhLLJGJzF4o9GS2ULf1ErNzlgpno75hn67z/RJ4dQ6mWxT9RSOOhkRV
# fRiGBYxVh3lIRvfKDo2n3k5f4qi2LVkCYYhhchhoubh87ubnNC8xd4EwH7s2AY3v
# J+P3mvBMMWSN4+v6GYeofs/sjAw2W3rBerh4x8kGLkYQyI3oBGDbvHN0+k7Y/qpA
# 8bLOcEaD6dpAoVk62RUJV5lWMJPzyWHM0AjMa+xiQpGsAsDvpPCJEY93AgMBAAGj
# ggM1MIIDMTAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8E
# DDAKBggrBgEFBQcDCDCCAb8GA1UdIASCAbYwggGyMIIBoQYJYIZIAYb9bAcBMIIB
# kjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzCCAWQG
# CCsGAQUFBwICMIIBVh6CAVIAQQBuAHkAIAB1AHMAZQAgAG8AZgAgAHQAaABpAHMA
# IABDAGUAcgB0AGkAZgBpAGMAYQB0AGUAIABjAG8AbgBzAHQAaQB0AHUAdABlAHMA
# IABhAGMAYwBlAHAAdABhAG4AYwBlACAAbwBmACAAdABoAGUAIABEAGkAZwBpAEMA
# ZQByAHQAIABDAFAALwBDAFAAUwAgAGEAbgBkACAAdABoAGUAIABSAGUAbAB5AGkA
# bgBnACAAUABhAHIAdAB5ACAAQQBnAHIAZQBlAG0AZQBuAHQAIAB3AGgAaQBjAGgA
# IABsAGkAbQBpAHQAIABsAGkAYQBiAGkAbABpAHQAeQAgAGEAbgBkACAAYQByAGUA
# IABpAG4AYwBvAHIAcABvAHIAYQB0AGUAZAAgAGgAZQByAGUAaQBuACAAYgB5ACAA
# cgBlAGYAZQByAGUAbgBjAGUALjALBglghkgBhv1sAxUwHwYDVR0jBBgwFoAUFQAS
# KxOYspkH7R7for5XDStnAs0wHQYDVR0OBBYEFGFaTSS2STKdSip5GoNL9B6Jwcp9
# MH0GA1UdHwR2MHQwOKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydEFzc3VyZWRJRENBLTEuY3JsMDigNqA0hjJodHRwOi8vY3JsNC5kaWdpY2Vy
# dC5jb20vRGlnaUNlcnRBc3N1cmVkSURDQS0xLmNybDB3BggrBgEFBQcBAQRrMGkw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcw
# AoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Q0EtMS5jcnQwDQYJKoZIhvcNAQEFBQADggEBAJ0lfhszTbImgVybhs4jIA+Ah+WI
# //+x1GosMe06FxlxF82pG7xaFjkAneNshORaQPveBgGMN/qbsZ0kfv4gpFetW7ea
# sGAm6mlXIV00Lx9xsIOUGQVrNZAQoHuXx/Y/5+IRQaa9YtnwJz04HShvOlIJ8Oxw
# YtNiS7Dgc6aSwNOOMdgv420XEwbu5AO2FKvzj0OncZ0h3RTKFV2SQdr5D4HRmXQN
# JsQOfxu19aDxxncGKBXp2JPlVRbwuwqrHNtcSCdmyKOLChzlldquxC5ZoGHd2vNt
# omHpigtt7BIYvfdVVEADkitrwlHCCkivsNRu4PQUCjob4489yq9qjXvc2EQwggbN
# MIIFtaADAgECAhAG/fkDlgOt6gAK6z8nu7obMA0GCSqGSIb3DQEBBQUAMGUxCzAJ
# BgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5k
# aWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBD
# QTAeFw0wNjExMTAwMDAwMDBaFw0yMTExMTAwMDAwMDBaMGIxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xITAfBgNVBAMTGERpZ2lDZXJ0IEFzc3VyZWQgSUQgQ0EtMTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAOiCLZn5ysJClaWAc0Bw0p5WVFypxNJBBo/J
# M/xNRZFcgZ/tLJz4FlnfnrUkFcKYubR3SdyJxArar8tea+2tsHEx6886QAxGTZPs
# i3o2CAOrDDT+GEmC/sfHMUiAfB6iD5IOUMnGh+s2P9gww/+m9/uizW9zI/6sVgWQ
# 8DIhFonGcIj5BZd9o8dD3QLoOz3tsUGj7T++25VIxO4es/K8DCuZ0MZdEkKB4YNu
# gnM/JksUkK5ZZgrEjb7SzgaurYRvSISbT0C58Uzyr5j79s5AXVz2qPEvr+yJIvJr
# GGWxwXOt1/HYzx4KdFxCuGh+t9V3CidWfA9ipD8yFGCV/QcEogkCAwEAAaOCA3ow
# ggN2MA4GA1UdDwEB/wQEAwIBhjA7BgNVHSUENDAyBggrBgEFBQcDAQYIKwYBBQUH
# AwIGCCsGAQUFBwMDBggrBgEFBQcDBAYIKwYBBQUHAwgwggHSBgNVHSAEggHJMIIB
# xTCCAbQGCmCGSAGG/WwAAQQwggGkMDoGCCsGAQUFBwIBFi5odHRwOi8vd3d3LmRp
# Z2ljZXJ0LmNvbS9zc2wtY3BzLXJlcG9zaXRvcnkuaHRtMIIBZAYIKwYBBQUHAgIw
# ggFWHoIBUgBBAG4AeQAgAHUAcwBlACAAbwBmACAAdABoAGkAcwAgAEMAZQByAHQA
# aQBmAGkAYwBhAHQAZQAgAGMAbwBuAHMAdABpAHQAdQB0AGUAcwAgAGEAYwBjAGUA
# cAB0AGEAbgBjAGUAIABvAGYAIAB0AGgAZQAgAEQAaQBnAGkAQwBlAHIAdAAgAEMA
# UAAvAEMAUABTACAAYQBuAGQAIAB0AGgAZQAgAFIAZQBsAHkAaQBuAGcAIABQAGEA
# cgB0AHkAIABBAGcAcgBlAGUAbQBlAG4AdAAgAHcAaABpAGMAaAAgAGwAaQBtAGkA
# dAAgAGwAaQBhAGIAaQBsAGkAdAB5ACAAYQBuAGQAIABhAHIAZQAgAGkAbgBjAG8A
# cgBwAG8AcgBhAHQAZQBkACAAaABlAHIAZQBpAG4AIABiAHkAIAByAGUAZgBlAHIA
# ZQBuAGMAZQAuMAsGCWCGSAGG/WwDFTASBgNVHRMBAf8ECDAGAQH/AgEAMHkGCCsG
# AQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29t
# MEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNl
# cnRBc3N1cmVkSURSb290Q0EuY3J0MIGBBgNVHR8EejB4MDqgOKA2hjRodHRwOi8v
# Y3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMDqg
# OKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURS
# b290Q0EuY3JsMB0GA1UdDgQWBBQVABIrE5iymQftHt+ivlcNK2cCzTAfBgNVHSME
# GDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG9w0BAQUFAAOCAQEARlA+
# ybcoJKc4HbZbKa9Sz1LpMUerVlx71Q0LQbPv7HUfdDjyslxhopyVw1Dkgrkj0bo6
# hnKtOHisdV0XFzRyR4WUVtHruzaEd8wkpfMEGVWp5+Pnq2LN+4stkMLA0rWUvV5P
# sQXSDj0aqRRbpoYxYqioM+SbOafE9c4deHaUJXPkKqvPnHZL7V/CSxbkS3BMAIke
# /MV5vEwSV/5f4R68Al2o/vsHOE8Nxl2RuQ9nRc3Wg+3nkg2NsWmMT/tZ4CMP0qqu
# AHzunEIOz5HXJ7cW7g/DvXwKoO4sCFWFIrjrGBpN/CohrUkxg0eVd3HcsRtLSxwQ
# nHcUwZ1PL1qVCCkQJjGCBDswggQ3AgEBMIGGMHIxCzAJBgNVBAYTAlVTMRUwEwYD
# VQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAv
# BgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EC
# EANRgwbrGgA18btJ2k5C8GEwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAI
# oAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIB
# CzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFMZqWttDcqdpp4DH5fDo
# WWb3srSbMA0GCSqGSIb3DQEBAQUABIIBAIkVMNcx6SECiA4YIi3JlbGKtrWBGNlw
# ZPgvZqrx/+xPgRCRKryKcyQ+LCBGzyEqPbbWQFCoM/Sq3wPDfrUgJc8rJzVL3NcK
# dfpgJhSypTOn4pA92/6+TgIkyisdPbfOUHopmdA9N7eVA4qLVHhvJHUrCTSuyyy+
# 4f84GjE2ivYAJBK61aEnxVXG4Tf2IM3Nsu4LS1RuNIaYx6ic/e+pPDi0EI9vtmEv
# VTXmB9q+pePtK0L/XEKC40ANTZNLNIRM8gBnk/mfIou6jQYXBpRAmbzNs7Wc3ynt
# XX+vr62FdDl/sTsjXni2BfDkInKkcbvt3QNZrYOQ5Yu7+GovKU7xURWhggIPMIIC
# CwYJKoZIhvcNAQkGMYIB/DCCAfgCAQEwdjBiMQswCQYDVQQGEwJVUzEVMBMGA1UE
# ChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYD
# VQQDExhEaWdpQ2VydCBBc3N1cmVkIElEIENBLTECEAMBmgI6/1ixa9bV6uYX8GYw
# CQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcN
# AQkFMQ8XDTIwMDkwNzA5NDA0N1owIwYJKoZIhvcNAQkEMRYEFJRm1HskdwawxVCu
# VJ5aZe30w79ZMA0GCSqGSIb3DQEBAQUABIIBADNbtAcXwpnSuj8bEIKiFrgOzvNJ
# FFTJtkSHCvCGmeDuiCM2mqsmEEczsOBrSncy9CpsKKueLqsQPr5CrNKlyO1EpJNl
# vtZR2ZopvsDrzhC7xaUZMLb2MSdJXD19ARBQ+PS2+YPltllXroA0oSfPuR71z8KB
# WlTU+j+RDpsMLnqVeM+KsL07VvfD0heM9OF3fTlEAOBiBG6AWfqUO6YgF309zfb4
# jRSYe72xPNJglr04w++MGXE6zvs0Xpdka/whSa9oOwP8kY4xf730X0phXjqoO434
# 6W8IAD+L93ZOJ7F0rr/cfFcCeBrCuUA7eAYivmNP6ztZBjb5dC839tChK7U=
# SIG # End signature block
