$ApiKey = "Here goes your API key" 
$SdpUri = "https://Your Server URL" 

# Pulls info about an existing request
function Get-Ticket
{
<#
.DESCRIPTION
    Pulls ticket info from Service Desk Plus.
.PARAMETER RequestID
    Request ID of the ticket to modify
.EXAMPLE
    Get-Ticket -RequestID 12345
.NOTES
    Author: Andre Wroblewski
	Date: 28-November-2019
#>
[CmdletBinding()]
param
(
[Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)] 
[alias ("id")]
[Int32] $RequestID
)

$input= @"
{
"request":{
"udf_fields":{
"udf_sline_18083": "$RequestFor"
}
} 
}
"@


$header = @{TECHNICIAN_KEY=$ApiKey} 
$params = @{input_data=$input;format='json'}
$Uri = $SdpUri + "/api/v3/requests/" + $RequestID
$result = Invoke-RestMethod -Method Get -Uri $Uri -Headers $header 

$description = (Convert-HtmlToText $result.request.description).Replace("&nbsp;", " ")
clear
write-host "Subject:" $result.request.subject
"----------------------------------------------------------------"
write-host "Technician:" $result.request.technician.name
write-host "Has conversation:" $result.request.has_conversation
write-host "Responded time:" $result.request.responded_time.display_value
write-host "status:" $result.request.status.name
write-host "Has notes:" $result.request.has_notes 
Out-Notepad "Ticket Description: `n $description"
#Display Notes if any
if ($result.request.has_notes -eq "True") {
#
# To DO - test on a ticket with multiple notes
#
	#Lookup Note IDs
	$UriNotesID = $SdpUri + "/api/v3/requests/" + $RequestID + "/notes"
	$resultNotesID = Invoke-RestMethod -Method Get -Uri $UriNotesID -Headers $header
	#Get Notes
	$UriNotes = $SdpUri + "/api/v3/requests/" + $RequestID + "/notes/" + $resultNotesID.notes.id
	$resultNotes = Invoke-RestMethod -Method Get -Uri $UriNotes -Headers $header 
	#Display Note
	$note = Convert-HtmlToText $resultNotes.request_note.description
	write-host "........ Opening Notepad Window"
	out-notepad "Ticket Notes: `n $note"
	}
#Display Resolution if any
if (($result.request.resolution.content).count -ne 0)	{
$UriResolution = $SdpUri + "/api/v3/requests/" + $RequestID + "/resolutions"
$resultResolution = Invoke-RestMethod -Method Get -Uri $UriResolution -Headers $header
	#Display Resolution
	$Resolution = Convert-HtmlToText $resultResolution.resolution.content
	write-host "Resolution ........ Opening Notepad Window."
	Out-Notepad "Resolution: `n $Resolution"
	}
}

#Adds resolution and closes ticket
function Resolve-Ticket {
<#
.DESCRIPTION
    Used to add resolution and close ticket.
.PARAMETER RequestID
    Request ID of the ticket to modify
.PARAMETER Resolution
    Ticket resolution
.PARAMETER Status
    Change status of the ticket to Resolved or Closed. Alternatively leave it open.
.EXAMPLE
    Resolve-Ticket -RequestID 12345 -Resolution "Issue resolved" -Status "Closed"
.NOTES
    Forked from https://github.com/GarySmithPS/SDP-Module
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)] 
	[alias ("id")]
	[Int32] $RequestID,
	[Parameter(Mandatory = $true, Position=1)]
    [string]$Resolution,
    [Parameter(Mandatory = $true, Position=2)]
    [ValidateSet("Open", "Resolved", "Closed")]
    [string]$Status
)

   
    process {
        $inputData = @"
{
    "request": {
        "resolution": {
            "content": "$Resolution"
        },
        "status": {
            "name": "$Status"
        }
    }
}
"@
        $URI = $SdpUri + "/api/v3/requests/$RequestID" + "?TECHNICIAN_KEY=$ApiKey&input_data=$inputdata&format=json"
        Invoke-WebRequest -Method PUT -Uri $URI -UseBasicParsing -Verbose
    }
    
}

#Adds note to a ticket
Function Add-NoteToTicket
{
<#
.DESCRIPTION
    Adds note to existing ticket.
.PARAMETER RequestID
    Request ID of the ticket to modify
.PARAMETER Note
    Text of the note that you want to add
.EXAMPLE
    Add-NoteToTicket -RequestID 12345 -Note "This is a note"
.NOTES
    Author: Andre Wroblewski
	Date: 28-November-2019
#>
[CmdletBinding()]
param (
	[Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)] 
	[alias ("id")]
	[Int32] $RequestID,
	[Parameter(Mandatory = $true, Position=1)]
    [string] $Note
)

   
$inputData = @"
{
"request_note": {
"description": "$Note",
"show_to_requester": false,
"notify_technician": false,
"mark_first_response": false,
"add_to_linked_requests": false
}
}
"@

$header = @{TECHNICIAN_KEY=$ApiKey} 
$params = @{input_data=$inputData;format='json'}
$Uri = $SdpUri + "/api/v3/requests/$RequestID" + "/notes"

Invoke-RestMethod -Method POST -Uri $Uri -Headers $header -Body $params -ContentType "application/x-www-form-urlencoded" -verbose

}

#
#
#
# Support functions
#
#
#

function Convert-HtmlToText {
<#
.DESCRIPTION
    Converts html output to plain text.
.PARAMETER html
    HTML output
.EXAMPLE
    Convert-HtmlToText $html_output
.NOTES
    Author http://winstonfassett.com/blog/2010/09/21/html-to-text-conversion-in-powershell/
#>


 param([System.String] $html)

 # remove line breaks, replace with spaces
 $html = $html -replace "(`r|`n|`t)", " "
 # write-verbose "removed line breaks: `n`n$html`n"

 # remove invisible content
 @('head', 'style', 'script', 'object', 'embed', 'applet', 'noframes', 'noscript', 'noembed') | % {
  $html = $html -replace "<$_[^>]*?>.*?</$_>", ""
 }
 # write-verbose "removed invisible blocks: `n`n$html`n"

 # Condense extra whitespace
 $html = $html -replace "( )+", " "
 # write-verbose "condensed whitespace: `n`n$html`n"

 # Add line breaks
 @('div','p','blockquote','h[1-9]') | % { $html = $html -replace "</?$_[^>]*?>.*?</$_>", ("`n" + '$0' )} 
 # Add line breaks for self-closing tags
 @('div','p','blockquote','h[1-9]','br') | % { $html = $html -replace "<$_[^>]*?/>", ('$0' + "`n")} 
 # write-verbose "added line breaks: `n`n$html`n"

 #strip tags 
 $html = $html -replace "<[^>]*?>", ""
 # write-verbose "removed tags: `n`n$html`n"
  
 # replace common entities
 @( 
  @("&amp;bull;", " * "),
  @("&amp;lsaquo;", "<"),
  @("&amp;rsaquo;", ">"),
  @("&amp;(rsquo|lsquo);", "'"),
  @("&amp;(quot|ldquo|rdquo);", '"'),
  @("&amp;trade;", "(tm)"),
  @("&amp;frasl;", "/"),
  @("&amp;(quot|#34|#034|#x22);", '"'),
  @('&amp;(amp|#38|#038|#x26);', "&amp;"),
  @("&amp;(lt|#60|#060|#x3c);", "<"),
  @("&amp;(gt|#62|#062|#x3e);", ">"),
  @('&amp;(copy|#169);', "(c)"),
  @("&amp;(reg|#174);", "(r)"),
  @("&amp;nbsp;", " "),
  @("&amp;(.{2,6});", "")
 ) | % { $html = $html -replace $_[0], $_[1] }
 # write-verbose "replaced entities: `n`n$html`n"

 return $html

}



Function Out-Notepad {
 [CmdletBinding()]
    Param
      (  
        [Parameter(Mandatory=$true,
        ValueFromPipeline=$true,
        Position=0)]
        $StrText
       )
  
$fso=new-object -com scripting.filesystemobject
$filename=$fso.GetTempName()
$tempfile=Join-Path $env:temp $filename

$strText | Out-File $tempfile
notepad $tempfile
#tidy up
sleep 3
if (Test-Path $tempfile) {del $tempfile}
}
