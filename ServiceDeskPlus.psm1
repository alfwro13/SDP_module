$ApiKey = "Here goes your API key" 
$SdpUri = "https://Your Server URL" 

# Gets information on an existing request
function Get-Request
{
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
if ($result.request.has_notes -eq "True") {
	#Lookup Note IDs
	$UriNotesID = $SdpUri + "/api/v3/requests/" + $RequestID + "/notes"
	$resultNotesID = Invoke-RestMethod -Method Get -Uri $UriNotesID -Headers $header
	#Get Notes
	$UriNotes = $SdpUri + "/api/v3/requests/" + $RequestID + "/notes/" + $resultNotesID.notes.id
	$resultNotes = Invoke-RestMethod -Method Get -Uri $UriNotes -Headers $header 
	}
	

$description = (Convert-HtmlToText $result.request.description).Replace("&nbsp;", " ")
clear
write-host "Subject:" $result.request.subject -BackgroundColor yellow -ForegroundColor Black
"----------------------------------------------------------------"
write-host "Description:"
out-notepad $description
"----------------------------------------------------------------"
write-host "Technician:" $result.request.technician.name
write-host "Has notes:" $result.request.has_notes
write-host "Has conversation:" $result.request.has_conversation
write-host "Responded time:" $result.request.responded_time.display_value
write-host "status:" $result.request.status.name

#Display Notes
$displayNotes = read-host "Display Notes? (Y/N)"
	if ($DisplayNotes -eq "Y") { 
		$note = Convert-HtmlToText $resultNotes.request_note.description
		out-notepad $note
	}
}



#
#
#
# Support functions
#
#
#

function Convert-HtmlToText {
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
