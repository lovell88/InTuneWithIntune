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
    $copyResult = Copy-Item "files\$($extractorFile)" -Destination "C:\Program Files\Autodesk_Temp\$($extractorFile)" -Force

}else
{
    New-Item -Path "C:\Program Files\Autodesk_Temp\" -ItemType Directory -Force
    $copyResult = Copy-Item "files\$($extractorFile)" -Destination "C:\Program Files\Autodesk_Temp\$($extractorFile)" -Force
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
    #Use silent installation command from the deployment.bat file 
    #If the package deployment fails check this section to make sure the batch file exists and the both parts of the command line are present.
    #if there are issues manually change part1 and part2 to the values from the install command like the line below
    #Start-Process -FilePath "C:\Temp\Autodesk_Deployments\Vehicle_Tracking\image\Installer.exe" -ArgumentList '-i deploy --offline_mode -q -o "C:\Temp\Autodesk_Deployments\Vehicle_Tracking\image\Collection.xml" --installer_version "1.41.0.249"'
    
    $part1 = ""
    $part2 = ""
    $installArgs = ""

    foreach($line in $installFile)
    {
        #We are looking for the silent install line so we can find that using this sub string
        if($line.Contains("-i deploy --offline_mode -q"))
        {            
            #we need to split the installation line into two parts so that it can be used by the Start-Process command
            $installParts = $line -split " -i "
            #We need to remove the "rem " part of the line
            $part1 = $installParts[0].Remove(0, 4)
            #We need to add back in the "-i" switch for the command line
            $part2 = "-i $($installParts[1])"

            $xmlPath = '"' + $part2.split('"')[1] + '"'
            $installerVersion = '"' + $part2.split('"')[3] + '"'

            $installArgs = @(
            "-i", "deploy", "--offline_mode", "-q", "-o", $xmlPath, "--installer_version", $installerVersion

            )

        }
    }    

    try
    {
        Start-ADTProcess -File $part1 -ArgumentList $installArgs -Wait
    }
    catch
    {

        Write-Host $_

    }

}

Remove-Item -Path "C:\Program Files\Autodesk_Temp" -Recurse -Force
Remove-Item -Path $deploymentCacheFolder -Recurse -Force
