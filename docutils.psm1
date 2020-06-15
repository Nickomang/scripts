# Usage: 
# PS C:\> Import-Module ./docutils.psm1 
# PS C:\> New-VSTSWorkItem https://github.com/MicrosoftDocs/azure-docs/issues/46635


function Get-FileInfoOnContent {
<#
.SYNOPSIS
Get file info based on content .
.DESCRIPTION
This command will files in a directory based on a filter and pattern and return the files that have that pattern.
.PARAMETER Filepath
The path to the files that will be queried.
.PARAMETER Pattern
The pattern to be searched for in the files
.PARAMETER Filter
The filter to filter out file types, i.e (*.md)

.EXAMPLE
PS C:\> Get-FileNameOnContent -filepath C:\users\gwallace\azure-content-pr -pattern application-gateway -filter "*.md" 

Filename   : application-gateway-create-gateway-arm-template.md
LineNumber : 6
Matches    : {application-gateway}
Path       : C:\users\gwallace\azure-content-pr\articles\application-gateway\application-gateway-create-gateway-arm-template.md
Pattern    : application-gateway
IgnoreCase : True

Filename   : application-gateway-create-gateway-arm.md
LineNumber : 5
Matches    : {application-gateway}
Path       : C:\users\gwallace\azure-content-pr\articles\application-gateway\application-gateway-create-gateway-arm.md
Pattern    : application-gateway
IgnoreCase : True

.Notes
Last Updated: August 24, 2016
Version     : 0.1


#>

[cmdletbinding()]
param(
[ValidateNotNullorEmpty()]
[Parameter(Mandatory=$True,Position=1)]
[string]$Filepath,
[Parameter(Mandatory=$True,Position=2)]
[ValidateNotNullorEmpty()]
[array]$Pattern,
[string]$Filter
)

$files = Get-ChildItem -Path "$filepath" -Filter $filter -Recurse

foreach ($file in $files | Select-String -pattern $pattern -List) 
{

$obj = new-object psobject
$obj | add-member noteproperty Filename ($file.Filename)
# $obj | add-member noteproperty Line ($file.Line)
$obj | add-member noteproperty LineNumber ($file.LineNumber)
$obj | add-member noteproperty Matches ($file.Matches)
$obj | add-member noteproperty Path ($file.Path)
$obj | add-member noteproperty Pattern ($file.Pattern)
$obj | add-member noteproperty IgnoreCase ($file.IgnoreCase)

write-output $obj

}
}
function Add-BordertoImage
{
[cmdletbinding()]
param(
[ValidateNotNullorEmpty()]
[Parameter(Mandatory=$True,Position=1,ValueFromPipelineByPropertyName,ValueFromPipeline)]
[string[]]$filename)

try
{
$file = Get-ChildItem -Path $filename
}
catch [ObjectNotFound]
{
Write-Output "File does not exist"
}
Add-Type -AssemblyName System.Drawing

$png = [System.Drawing.Image]::FromFile($file)
$brushFg = [System.Drawing.Color]::FromArgb(195,195,195)
$pen = New-Object System.Drawing.Pen($brushFg)
$graphics = [System.Drawing.Graphics]::FromImage($png)
$graphics.DrawRectangle($pen,$graphics.VisibleClipBounds.x,$graphics.VisibleClipBounds.x,($graphics.VisibleClipBounds.Right - 1),($graphics.VisibleClipBounds.Bottom - 1))

$ms = new-object System.IO.MemoryStream
$png.Save($ms,[System.Drawing.Imaging.ImageFormat]::png)

$graphics.Dispose()
$png.Dispose()
$newpng = [System.Drawing.Image]::FromStream($ms)
$newpng.Save($filename);
}

function New-VSTSWorkItem {
    param(
      [Parameter(Mandatory=$true)]
      [uri]$issueurl,
    
      [ValidateSet('TechnicalContent\Azure\Compute\Containers and Serverless\Containers\Service Fabric')]
      [string]$areapath='TechnicalContent\Azure\Compute\Containers and Serverless\Containers\Service Fabric',
    
    #[string]$iterationpath="TechnicalContent\CY$(get-date -format yyyy)\$(get-date -format MM)_$((get-date).Year)",
    [string]$iterationpath="TechnicalContent\Future",

      [ValidateSet('Nick Oman')]
      [string]$assignee='Nick Oman'
    )
    
    #if (!(Test-Path Env:\GITHUB_OAUTH_TOKEN)) {
    #  Write-Error "Error: missing Env:\GITHUB_OAUTH_TOKEN"
    #  exit
    #}
    
    # load the required dll
    $dllpath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer"
    Add-Type -path "$dllpath\Microsoft.TeamFoundation.WorkItemTracking.Client.dll"
    Add-Type -path "$dllpath\Microsoft.TeamFoundation.Client.dll"
    [string]$vsourl = "https://mseng.visualstudio.com"
    
    $issue = GetIssue -issueurl $issueurl
    if ($issue) {
    Write-Output "Found issue $($issue.Title)"
      $description = "Issue: <a href='{0}'>{1}</a><BR>" -f $issue.url,$issue.name
      $description += "Created: {0}<BR>" -f $issue.created_at
      $description += "Labels: {0}<BR>" -f ($issue.labels -join ',')
      $description += "Description:<BR>{0}<BR>" -f ($issue.body -replace '\n','<BR>')
      $description += "Comments:<BR>{0}" -f ($issue.comments -replace '\n','<BR>')
      

  
      $uri = New-Object System.Uri -ArgumentList $vsourl
      $credentialProvider = New-Object Microsoft.TeamFoundation.Client.UICredentialsProvider
      $vsts = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($uri)
      $vsts.Authenticate()

      $WIStore=$vsts.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])
      $project=$WIStore.Projects["TechnicalContent"]
        Write-Verbose "Checking if item exists in Azure DevOps already"
         $parent = $WIStore.Query("Select [System.Id] From WorkItems Where [System.WorkItemType] = 'User Story' and [Title] = 'Azure Service Fabric - Content feedback ($(get-date -format yy)$(get-date -format MM))'")
        $item = $WIStore.Query("Select [System.Id] From WorkItems Where [System.WorkItemType] = 'Task' and [Title] = '$($issue.title)'")
        if($item)
        {
        Write-Output "Workitem $($item.Id) already exists, updating workitem"
        $item.Description = $description
$item.save()
      $item | select Id,AreaPath,IterationPath,@{n='AssignedTo';e={$_.Fields['Assigned To'].Value}},Title,Description
        }
      $labels = @("product-issue","product-question","doc-bug","doc-enhancement","doc-idea","product-feedback")
      foreach($label in $issue.labels)
      {
      if($label -in $labels)
      {
      $tags = $label
      }
      }
      #Create Task
      $type=$project.WorkItemTypes["Task"]
      $item = new-object Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItem $type
      $item.Title = $issue.title
      $item.AreaPath = $areapath
      $item.IterationPath = $iterationpath

      $item.Tags = $tags
      $item.Description = $description
      $item.Fields['Assigned To'].Value = $assignee
      $item.WorkItemLinks.Add
      $hierarchicalLink = $wiStore.WorkItemLinkTypes["System.LinkTypes.Hierarchy"];

      $workitemlink = new-object Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemLink $hierarchicalLink.ReverseEnd, $($parent.id)
      $item.WorkItemLinks.Add($workitemlink)

      $item.save()
      $item | select Id,AreaPath,IterationPath,@{n='AssignedTo';e={$_.Fields['Assigned To'].Value}},Title,Description
    } else {
      Write-Error "Error: unable to retrieve issue."
    }
    }

    function Copy-VSTSWorkItem {
    param(
      [Parameter(Mandatory=$true)]
      [int]$id,
      [uri]$sourcevsourl = "https://msazure.visualstudio.com",
      [uri]$destvsourl = "https://mseng.visualstudio.com",
      [ValidateSet('TechnicalContent\Carmon Mills Org', 'TechnicalContent\Carmon Mills Org\Management', 'TechnicalContent\AzMgmtMon-SC-PS-AzLangs\Management\Automation')]
      [string]$areapath='TechnicalContent\Carmon Mills Org\Management\Automation',
    
    [string]$iterationpath="TechnicalContent\CY$(get-date -format yyyy)\$(get-date -format MM)_$((get-date).Year)",
    
      [ValidateSet('Sean Wheeler','Bobby Reed','David Coulter','George Wallace')]
      [string]$assignee='George Wallace'
    )
    
    # load the required dll
    $dllpath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer"
    Add-Type -path "$dllpath\Microsoft.TeamFoundation.WorkItemTracking.Client.dll"
    Add-Type -path "$dllpath\Microsoft.TeamFoundation.Client.dll"
    $sourcevsourl = "https://msazure.visualstudio.com"
        $destvsourl = "https://mseng.visualstudio.com"

             $sourcevsts = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($sourcevsourl)
      $sourceWIStore=$sourcevsts.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])
      $witocopy = $sourceWIStore.GetWorkItem($id)

      $description = $witocopy.Description
    
      $destvsts = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($destvsourl)
      $destWIStore=$destvsts.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])
      $project=$destWIStore.Projects["TechnicalContent"]
    
       $type=$project.WorkItemTypes["Task"]
      $item = new-object Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItem $type
      $item.Title = $witocopy.Title
      $item.AreaPath = $areapath
      $item.IterationPath = $iterationpath

      $item.Tags = $witocopy.Tags
      $item.Description = $witocopy.Description
      $item.Fields['Assigned To'].Value = $assignee
      $item.save()
      $item | select Id,AreaPath,IterationPath,@{n='AssignedTo';e={$_.Fields['Assigned To'].Value}},Title,Description

    }
    
function GetIssue {
    param(
      [Parameter(ParameterSetName='bynamenum',Mandatory=$true)]
      [string]$repo,
      [Parameter(ParameterSetName='bynamenum',Mandatory=$true)]
      [int]$num,
  
      [Parameter(ParameterSetName='byurl',Mandatory=$true)]
      [uri]$issueurl
    )
    $hdr = @{
      Accept = 'application/vnd.github.v3+json'
      Authorization = "token a9d4c3950c7b478cf35aacf7404f018fa2b85520"
    }
    if ($issueurl -ne '') {
      $repo = ($issueurl.Segments[1..2] -join '').trim('/')
      $issuename = $issueurl.Segments[1..4] -join ''
      $num = $issueurl.Segments[-1]
    }

    $apiurl = "https://api.github.com/repos/$repo/issues/$num"
    $issue = (Invoke-RestMethod $apiurl -Headers $hdr)
    $apiurl = "https://api.github.com/repos/$repo/issues/$num/comments"
    $comments = (Invoke-RestMethod $apiurl -Headers $hdr) | select -ExpandProperty body
    $retval = New-Object -TypeName psobject -Property ([ordered]@{
        number = $issue.number
        name = $issuename
        url=$issue.html_url
        created_at=$issue.created_at
        assignee=$issue.assignee.login
        title='[GitHub #{0}] {1}' -f $issue.number,$issue.title
        labels=$issue.labels.name
        body=$issue.body
        comments=$comments -join "`n"
    })
    $retval
  }
  
  

Export-ModuleMember -Function "Get-FileInfoOnContent","Add-BordertoImage","New-VSTSWorkItem", "Copy-VSTSWorkItem"


