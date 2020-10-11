# Compare-PkiCertificates.ps1

Compare-PkiCertificates.ps1 compares two PKI Certificates you believe are similar or functionally identical. It displays their values side-by-side on screen and uses colour to quickly highlight where there are any differences between them.

"Compare-PkiCertificates.ps1" takes the thumbprints of two certificates you expect to be similar or identical, and uses your existing PowerShell colour scheme to show you where they differ.

Your environment's Warning colour (yellow in my screen-grab below) shows the bits we expect to be different (the "not before", "not after", "serial number" and "thumbprint" values) whilst your Error colour (red below) shows the "unexpected differences" like  extra or missing SANs, changes to the key size, etc.

<img src="https://user-images.githubusercontent.com/11004787/81053018-cde37380-8f07-11ea-92e1-b7647e1d5c2c.png" alt="" width="600" />

### Features

- Shows two certificates side-by-side so you can quickly see what's unchanged or different between them 

- Uses your existing PowerShell colour scheme to represent the identical, expected and unexpected differences 

- Even though some long values are truncated on screen, they're compared at their full length before being truncated 

- Breaks out all of the SANs to a line each, clearly showing any that are added or removed 

- Code-signed so it'll run in restricted environments. (Thank you Digicert) 

- Automatically adjusts the display to make maximum use of your visible screen width 

### Shortcomings / weaknesses

- Outputs to screen using "write-host" and not to the pipeline 

- PowerShell v2 (Server 2008R2 & Windows 7) doesn't reveal all of the values to me. Rather than prevent the script from running under v2, I pop a warning 

- Needs to be run as Admin to reliably show all information 

### How-To

Feed it the thumbprints of two installed certificates - a paste from the cert's MMC is fine, with spaces and that junk character that's always at the start:

```powershell 
PS C:\> .\Compare-PkiCertificates.ps1 -Thumbprint1 "?e9 6e 65 bc 08 0f 0b 34 94 a4 30 d5 ea 9f 2d 0a 1a fd a5 99" -Thumbprint2 "?22 c8 ee e1 f1 e9 3d 7b 38 5d 4e d9 25 f4 bc 79 00 bf 8a 3b"
```

```powershell 
PS C:\> .\Compare-PkiCertificates.ps1 -Thumbprint1 "e96e65bc080f0b3494a430d5ea9f2d0a1afda59" -Thumbprint2 "22c8eee1f1e93d7b385d4ed925f4bc7900bf8a3b"
```

```powershell 
PS C:\> .\Compare-PkiCertificates.ps1 e96e65bc080f0b3494a430d5ea9f2d0a1afda599 22c8eee1f1e93d7b385d4ed925f4bc7900bf8a3b
```

### Revision History

#### v1.9: 11th October 2020
- Added handling for multiple OU's in the cert. Re-purposed the SAN display for this as new fn 'Display-Complex'
          
#### v1.8: 7th September 2020
- Added the capture/comparison of Enhanced Key Usage

#### v1.7: 12th May 2018

- Added an abort line that kills the script when running in the (unsupported) PowerShell ISE. (Screen-width and coloured output don't work) 

#### v1.6: 30th March 2018

- Corrected bug where a SAN would show incorrectly if there was a difference in case between the two certs 

- Set the 'warning' highlighting to all attributes where the case differs between certificates 

- Added an "-ignorecase" switch, for those who don't care about case-sensitivity 

- Fixed bug where Win7/P$v2 didn't like my Write-Progress lines without a "Status" attribute 

#### v1.5: 24th December 2017

- Fixed a bug introduced in 1.4 where the CN was splitting on commas AND spaces, resulting in malformed States especially 

- Incorporated my version of Pat's "Get-UpdateInfo". Credit: https://ucunleashed.com/3168 

#### v1.4: 15th June 2017

- Found the v1.3 change to reading certs was causing some values not to show in some environments & errors in others. 

- Reverted to the v1.2 approach (but now reading all of cert:\localmachine) pending further investigation. 

- Changed the way the "Subject" is parsed, from Split(",") to Split(", ") & stripped spaces from following ".StartsWith" tests 

- Added "E=" for those scripts that include an e-mail address 

#### v1.3 19th February 2017

- Updated the script so it searches all Cert stores for the thumbprints you nominate, not just "localmachine\My". Thanks Soder! 

#### v1.2 22nd January 2017

- Changed the script comparison engine to take full advantage of your current visible screen width. 

#### v1.1 28th April 2016

- Changed the way I read SANs for improved Server 2008 compatibility. 

#### v1.0 26th March 2016

- This is the initial release. 

<br>

\- G.

<br>

This script was originally published at [https://greiginsydney.com/compare-pkicertificates-ps1/](https://greiginsydney.com/compare-pkicertificates-ps1/).

