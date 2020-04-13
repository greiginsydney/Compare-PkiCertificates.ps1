# Compare-PkiCertificates.ps1

Compare-PkiCertificates.ps1 compares two PKI Certificates you believe are similar or functionally identical. It displays their values side-by-side on screen and uses colour to quickly highlight where there are any differences between them.

<p>&nbsp;</p>
<p>"Compare-PkiCertificates.ps1" takes the thumbprints of two certificates you expect to be similar or identical, and uses your existing PowerShell colour scheme to show you where they differ.</p>
<p>&nbsp;</p>
<p>Your environment's Warning colour (yellow in my screen-grab below) shows the bits we expect to be different (the "not before", "not after", "serial number" and "thumbprint" values) whilst your Error colour (red below) shows the "unexpected differences" like  extra or missing SANs, changes to the key size, etc.</p>
<p>&nbsp;</p>
<p><img id="150171" src="/site/view/file/150171/1/Compare-PkiCertificates.png" alt="" width="578" height="405" /></p>
<h4>Features</h4>
<ul>
<li>Shows two certificates side-by-side so you can quickly see what's unchanged or different between them </li>
<li>Uses your existing PowerShell colour scheme to represent the identical, expected and unexpected differences </li>
<li>Even though some long values are truncated on screen, they're compared at their full length before being truncated </li>
<li>Breaks out all of the SANs to a line each, clearly showing any that are added or removed </li>
<li>Code-signed so it'll run in restricted environments. (Thank you Digicert) </li>
<li>Automatically adjusts the display to make maximum use of your visible screen width </li>
</ul>
<h4>Shortcomings / weaknesses</h4>
<ul>
<li>Outputs to screen using "write-host" and not to the pipeline </li>
<li>PowerShell v2 (Server 2008R2 &amp; Windows 7) doesn't reveal all of the values to me. Rather than prevent the script from running under v2, I pop a warning </li>
<li>Needs to be run as Admin to reliably show all information </li>
</ul>
<h3>How-To</h3>
<p>Feed it the thumbprints of two installed certificates - a paste from the cert's MMC is fine, with spaces and that junk character that's always at the start:</p>
<pre>PS C:\&gt; .\Compare-PkiCertificates.ps1 -Thumbprint1 "?e9 6e 65 bc 08 0f 0b 34 94 a4 30 d5 ea 9f 2d 0a 1a fd a5 99" -Thumbprint2 "?22 c8 ee e1 f1 e9 3d 7b 38 5d 4e d9 25 f4 bc 79 00 bf 8a 3b"</pre>
<pre>PS C:\&gt; .\Compare-PkiCertificates.ps1 -Thumbprint1 "e96e65bc080f0b3494a430d5ea9f2d0a1afda59" -Thumbprint2 "22c8eee1f1e93d7b385d4ed925f4bc7900bf8a3b"</pre>
<pre>PS C:\&gt; .\Compare-PkiCertificates.ps1 e96e65bc080f0b3494a430d5ea9f2d0a1afda599 22c8eee1f1e93d7b385d4ed925f4bc7900bf8a3b</pre>
<h3>Revision History</h3>
<p>v1.7: 12th May 2018</p>
<ul>
<li>Added an abort line that kills the script when running in the (unsupported) PowerShell ISE. (Screen-width and coloured output don't work) </li>
</ul>
<p>v1.6: 30th March 2018</p>
<ul>
<li>Corrected bug where a SAN would show incorrectly if there was a difference in case between the two certs </li>
<li>Set the 'warning' highlighting to all attributes where the case differs between certificates </li>
<li>Added an "-ignorecase" switch, for those who don't care about case-sensitivity </li>
<li>Fixed bug where Win7/P$v2 didn't like my Write-Progress lines without a "Status" attribute </li>
</ul>
<p>v1.5: 24th December 2017</p>
<ul>
<li>Fixed a bug introduced in 1.4 where the CN was splitting on commas AND spaces, resulting in malformed States especially </li>
<li>Incorporated my version of Pat's "Get-UpdateInfo". Credit: https://ucunleashed.com/3168 </li>
</ul>
<p>v1.4: 15th June 2017</p>
<ul>
<li>Found the v1.3 change to reading certs was causing some values not to show in some environments &amp; errors in others. </li>
<li>Reverted to the v1.2 approach (but now reading all of cert:\localmachine) pending further investigation. </li>
<li>Changed the way the &ldquo;Subject&rdquo; is parsed, from Split(&ldquo;,&rdquo;) to Split(&ldquo;, &ldquo;) &amp; stripped spaces from following &ldquo;.StartsWith&rdquo; tests </li>
<li>Added &ldquo;E=&rdquo; for those scripts that include an e-mail address </li>
</ul>
<p>v1.3 19th February 2017</p>
<ul>
<li>Updated the script so it searches all Cert stores for the thumbprints you nominate, not just &ldquo;localmachine\My&rdquo;. Thanks Soder! </li>
</ul>
<p>v1.2 22nd January 2017</p>
<ul>
<li>Changed the script comparison engine to take full advantage of your current visible screen width. </li>
</ul>
<p>v1.1 28th April 2016</p>
<ul>
<li>Changed the way I read SANs for improved Server 2008 compatibility. </li>
</ul>
<p>v1.0 26th March 2016</p>
<ul>
<li>This is the initial release. </li>
</ul>
<p>&nbsp;</p>
<p>- G.</p>
