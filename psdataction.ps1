$sciptName = $MyInvocation.MyCommand.Name
$myLocation = $MyInvocation.MyCommand.Source.Replace("$($sciptName)", "")

cd $myLocation

#Path for installation tool
#Enter name of installation tool below
$extractorFile = "Revit 2023.1.8 10-29-2025.exe"
$deploymentCacheFolder = "C:\ai2io_it\revit\downloads"
$productFolderName = "revit2023"

if(Test-Path -Path "C:\Program Files\Autodesk_Temp\")
{
    $copyResult = Copy-Item "files\$extractorFile" -Destination "C:\Program Files\Autodesk_Temp\$($extractorFile)" -Force

}else
{
    New-Item -Path "C:\Program Files\Autodesk_Temp\" -ItemType Directory -Force
    $copyResult = Copy-Item "files\$extractorFile" -Destination "C:\Program Files\Autodesk_Temp\$($extractorFile)" -Force
}

if(Test-Path -Path "C:\Program Files\Autodesk_Temp\$($extractorFile)")
{
    Start-Process -FilePath "C:\Program Files\Autodesk_Temp\$($extractorFile)" -ArgumentList "-q" -Wait
}

$tempDeploymentDirectory = [System.IO.DirectoryInfo]::new("$($deploymentCacheFolder)\$($productFolderName)")
$successLine = $null
$installFile = $null

do
{

    foreach($file in $tempDeploymentDirectory.GetFiles())
    {

        if($file.Extension -eq ".log")
        {
            $log = Get-Content -Path $file.FullName

            $successLine = $log | Where-Object {$_ -match "The deployment image is created successfully"}

        }

        if($successLine -ne $null)
        {
            #Get the generated install batch file
            if($file.extension -eq ".bat")
            {

                $installFile = Get-Content -Path $file.FullName

            }

        }

        
    }

}Until($successLine -ne $null)

if($successLine -ne $null)
{
    #If deployment image has been created then all files have been extracted
    #Use silent uninstall command from the deployment.bat file
    #Start-Process -FilePath "C:\Program Files\Autodesk Deployment Cache\AutoCad\image\Installer.exe" -ArgumentList '-i uninstall -q --manifest "C:\Program Files\Autodesk Deployment Cache\AutoCad\image\ACD_2022_en-US\setup.xml" --extension_manifest "C:\Program Files\Autodesk Deployment Cache\AutoCad\image\ACD_2022_en-US\setup_ext.xml"' -Wait

    $executable = ""
    $uninstallArgs = ""

    foreach($line in $installFile)
    {
        #We are looking for the silent install line so we can find that using this sub string
        if($line.Contains("-i uninstall -q"))
        {            
            #we need to split the installation line into two parts so that it can be used by the Start-Process command
            $installParts = $line -split " -i "
            #We need to remove the "rem " part of the line
            $executable = $installParts[0].Remove(0, 4)

            #Now we will split the line to get the manifest and extension manifest xml locations
            $xmlLocations = (($line -split "--manifest ")[1] -split "--extension_manifest ")
            $manifestXml = $xmlLocations[0]
            $extension_manifestXml = $xmlLocations[1]
            
            #We can now put it all together in an array for powershell to handle
            $uninstallArgs = @(
            "-i", "uninstall", "-q", "--manifest", $manifestXml, "--extension_manifest", $extension_manifestXml

            )

        }
    }    

    try
    {
        Start-ADTProcess -File $executable -ArgumentList $uninstallArgs -Wait
    }
    catch
    {

        Write-Host $_

    }
}

Remove-Item -Path "C:\Program Files\Autodesk_Temp" -Recurse -Force
Remove-Item -Path $deploymentCacheFolder -Recurse -Force
