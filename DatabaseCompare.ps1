#Set-ExecutionPolicy RemoteSigned


#OriginalDacpac
$OriginalScript = 'C:\Users\Ritwik\Desktop\DatabaseCompare\OriginalScript.sql'

#Source: Place in test file below, list databases by running select * from sys.databases where database_id > 4
$DatabaseSourceList = 'C:\Users\Ritwik\Desktop\DatabaseCompare\DatabaseList.txt'

#Destination: Database Files Generate Scripts
$Filepath='C:\Users\Ritwik\Desktop\DatabaseCompare\scripts' # local directory to save build-scripts to

#Resource: https://www.red-gate.com/simple-talk/sql/database-administration/automated-script-generation-with-powershell-and-smo/

foreach($line in Get-Content $DatabaseSourceList) 
{

    $DataSource='localhost' # server name and instance
    $Database=$line # the database to copy from
    # set "Option Explicit" to catch subtle errors
    set-psdebug -strict
    $ErrorActionPreference = "stop" # you can opt to stagger on, bleeding, if an error occurs
    # Load SMO assembly, and if we're running SQL 2008 DLLs load the SMOExtended and SQLWMIManagement libraries
    $ms='Microsoft.SqlServer'
    $v = [System.Reflection.Assembly]::LoadWithPartialName( "$ms.SMO")
    if ((($v.FullName.Split(','))[1].Split('='))[1].Split('.')[0] -ne '9') {
    [System.Reflection.Assembly]::LoadWithPartialName("$ms.SMOExtended") | out-null
       }
    $My="$ms.Management.Smo" #
    $s = new-object ("$My.Server") $DataSource
    if ($s.Version -eq  $null ){Throw "Can't find the instance $Datasource"}
    $db= $s.Databases[$Database] 
    if ($db.name -ne $Database){Throw "Can't find the database '$Database' in $Datasource"};
    $transfer = new-object ("$My.Transfer") $db
    $CreationScriptOptions = new-object ("$My.ScriptingOptions") 
    $CreationScriptOptions.ExtendedProperties= $true # yes, we want these
    $CreationScriptOptions.DRIAll= $true # and all the constraints 
    $CreationScriptOptions.Indexes= $true # Yup, these would be nice
    $CreationScriptOptions.Triggers= $true # This should be included when scripting a database
    $CreationScriptOptions.ScriptBatchTerminator = $true # this only goes to the file
    $CreationScriptOptions.IncludeHeaders = $false; # of course
    $CreationScriptOptions.ToFileOnly = $true #no need of string output as well
    $CreationScriptOptions.IncludeIfNotExists = $true # not necessary but it means the script can be more versatile
    $CreationScriptOptions.Filename =  "$($FilePath)\$($Database)_Build.sql"; 
    $NewFilename =  "$($FilePath)\$($Database)_Build2.sql"; 

    $transfer = new-object ("$My.Transfer") $s.Databases[$Database]
 
    $transfer.options=$CreationScriptOptions # tell the transfer object of our preferences
    $transfer.ScriptTransfer()
    "Created Database " + $Database

    #Get-Content $CreationScriptOptions.Filename | Where { $_ -notmatch "/" } | Set-Content $NewFilename



    if(Compare-Object -ReferenceObject $(Get-Content $OriginalScript) -DifferenceObject $(Get-Content $NewFilename))
        {$Database + " Files are different 'n"}
    Else 
        {$Database + "Files are the same"}


}



