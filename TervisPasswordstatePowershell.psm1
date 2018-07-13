﻿function Invoke-PasswordstateProvision {
    param (
        $EnvironmentName
    )
    $ApplicationName = "Passwordstate"
    Invoke-ApplicationProvision -ApplicationName $ApplicationName -EnvironmentName $EnvironmentName
    $Nodes = Get-TervisApplicationNode -ApplicationName $ApplicationName -EnvironmentName $EnvironmentName
    $Nodes | Update-TervisSNMPConfiguration
    Get-ADGroup Privilege_InfrastructurePasswordstateAdministrator | Add-ADGroupMember -Members Scheduledtasks
    $Nodes | Install-PasswordstateServicerestartScheduledTask
}

function Install-PasswordstateServicerestartScheduledTask {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]$ComputerName
    )
    begin {
        $ScheduledTaskCredential = New-Object System.Management.Automation.PSCredential (Get-PasswordstateCredential -PasswordID 259)
        $Execute = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
        $ScheduledTaskName = "PasswordstateServiceRestart"
    }
    process {
        $Argument = "-NoProfile -Command Invoke-Command -ComputerName $Computername -ScriptBlock {Restart-Service -Name 'Passwordstate Service' -Force}"
        $CimSession = New-CimSession -ComputerName $ComputerName
        If (Get-ScheduledTask -TaskName $ScheduledTaskName -CimSession $CimSession -ErrorAction SilentlyContinue) {
            Uninstall-TervisScheduledTask -TaskName $ScheduledTaskName -ComputerName Scheduledtasks -Force
        }
        Install-TervisScheduledTask -Credential $ScheduledTaskCredential -TaskName $ScheduledTaskName -Execute $Execute -Argument $Argument -RepetitionIntervalName Every12HoursEveryDay -ComputerName Scheduledtasks

#        If (-NOT (Get-ScheduledTask -TaskName PushExplorerFavorites -CimSession $CimSession -ErrorAction SilentlyContinue)) {
#            Install-TervisScheduledTask -Credential $ScheduledTaskCredential -TaskName PushExplorerFavorites -Execute $Execute -Argument $Argument -RepetitionIntervalName EverWorkdayDuringTheDayEvery15Minutes -ComputerName $ComputerName
#        }
    }
}

function Get-TervisPasswordStateApplicationPasswordTitle {
    param (
        [Parameter(Mandatory)][ValidateSet("LocalAdministrator")]$Type,
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]$ApplicationName,
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]$EnvironmentName       
    )
    process {
        "$ApplicationName Application Node Local Administrator $EnvironmentName"
    }
}

function New-TervisPasswordStateApplicationPassword {
    param (
        [Parameter(Mandatory)][ValidateSet("LocalAdministrator")]$Type,
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]$ApplicationName,
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]$EnvironmentName
    )
    process {
        if ($Type -eq "LocalAdministrator") {
            $PasswordTitle = Get-TervisPasswordStateApplicationPasswordTitle @PSBoundParameters
            $Password = Find-PasswordstatePassword -Title $PasswordTitle -ErrorAction SilentlyContinue
            if (-not $Password) {
                $PasswordList = Find-PasswordstateList -PasswordList "Windows Server Applications Administrator"
                New-PasswordstatePassword -GeneratePassword $true -PasswordListID $PasswordList.PasswordListID -Title $PasswordTitle -UserName ".\administrator"
            } else {
                $Password
            }
        }
    }
}

function Get-TervisPasswordStateApplicationPassword {
    param (
        [Parameter(Mandatory)][ValidateSet("LocalAdministrator")]$Type,
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]$ApplicationName,
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]$EnvironmentName,
        [Switch]$AsCredential
    )
    process {
        if ($Type -eq "LocalAdministrator") {
            $PSBoundParameters.Remove("AsCredential") | Out-Null
            $PasswordTitle = Get-TervisPasswordStateApplicationPasswordTitle @PSBoundParameters
            Find-PasswordstatePassword -Title $PasswordTitle -ErrorAction SilentlyContinue -AsCredential:$AsCredential
        }    
    }
}