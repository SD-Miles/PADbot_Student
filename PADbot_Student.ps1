<#

See README.md for detailed information.

NAMING CONVENTIONS:
  1. A "Student" is an object imported from the Sapphire CSV.
  2. An "Account" is a user object in Active Directory.

Since the functions combine these object types, they are accordingly named VERB-StudentAccount.

#>



##############    IMPORT MODULES AND FUNCTIONS    ###############

Import-Module -Name ActiveDirectory
Import-Module -Name PSGSuite

$FunctionPath = $PSScriptRoot + "\Functions\"
$FunctionList = Get-ChildItem -Path $FunctionPath -Name

foreach ($Function in $FunctionList) {
    . ($FunctionPath + $Function)
}



##############    DEFINE GLOBAL VARIABLES    ###############

# Set the grade level graduation years. These must be incremented annually.
$GradeK = 2034
$Grade1 = 2033
$Grade2 = 2032
$Grade3 = 2031
$Grade4 = 2030
$Grade5 = 2029
$Grade6 = 2028
$Grade7 = 2027
$Grade8 = 2026
$Grade9 = 2025
$Grade10 = 2024
$Grade11 = 2023
$Grade12 = 2022

$PADbotDirectory = 'C:\Tasks_and_Scripts\PSGSuite\PADbot_Student'
$EnrolledStudents = Import-Csv -Path "$PADbotDirectory\EnrolledStudents.csv"
$EnrolledStudentIDs = $EnrolledStudents | Select-Object -ExpandProperty STUDENT_ID
$ActiveAccounts = Get-ADUser -SearchBase 'OU=Student Accounts,DC=efrafa,DC=net' -Filter * -Properties EmployeeID



##############    CHAPTER 1: DETERMINE AND SANITY-CHECK WITHDRAWN STUDENT ACCOUNTS TO DISABLE    ###############
###### Disable students accounts that exist in Active Directory, but not Sapphire. ######

# Define the OUs in which we'll disable accounts if the students are not enrolled.
# I assume that students in the Feature/Web Block OUs are enrolled.
$ClassOUs = @(
    "Class of $Grade12 - 12",
    "Class of $Grade11 - 11",
    "Class of $Grade10 - 10",
    "Class of $Grade9 - 9",
    "Class of $Grade8 - 8",
    "Class of $Grade7 - 7",
    "Class of $Grade6 - 6",
    "Class of $Grade5 - 5",
    "Class of $Grade4 - 4",
    "Class of $Grade3 - 3",
    "Class of $Grade2 - 2",
    "Class of $Grade1 - 1",
    "Class of $GradeK - K")

$AccountIDsInClassOUs = foreach ($OU in $ClassOUs) {
    Get-ADUser -SearchBase "OU=$OU,OU=Student Accounts,DC=efrafa,DC=net" -Filter * -Properties EmployeeID |
    Select-Object -ExpandProperty EmployeeID
}

# Withdrawn students have ID numbers in the class OUs, but not Sapphire.
# Grab the MemberOf attribute here for use in the Disable-StudentAccount function.
$WithdrawnAccounts = foreach ($ID in $AccountIDsInClassOUs) {
    if ($ID -notin $EnrolledStudentIDs) {
        Get-ADUser -SearchBase 'OU=Student Accounts,DC=efrafa,DC=net' -Filter "EmployeeID -EQ $ID" -Properties Mail,EmployeeID,MemberOf
    }
}

# Sanity check.
if (($WithdrawnAccounts).count -gt 30) {
    # Send email reporting sanity check failure.
    $WithdrawnAccountSanityList = $WithdrawnAccounts | Select-Object -ExpandProperty Mail
    New-Item -ItemType File -Path "$PADbotDirectory\SANITY_CHECK.txt"
    Set-Content -Path "$PADbotDirectory\SANITY_CHECK.txt" -Value $WithdrawnAccountSanityList
    $Attachments = Get-ChildItem -Path "$PADbotDirectory\*.txt"
    $EmailBody = Get-Content -Path "$PSScriptRoot\Files\MailBody_Disable-SanityCheck"
    Send-MailMessage -From 'PADbot <padbot@efrafa.net>' -To 'Tech Dept <techsupport@efrafa.net>' `
        -Subject 'ERROR - TOO MANY ACCOUNTS TO DISABLE' -Body $EmailBody -SmtpServer 'smtp.efrafa.net' -Attachments $Attachments

    # Archive the log files and clear them from the next run so they are not sent again.
    $Date = (Get-Date).ToString("yyyy-MM-dd")
    $Path = "$PADbotDirectory\Logs"
    foreach ($Attachment in $Attachments) {
        Move-Item -Path $Attachment -Destination "$Path\$Date-$($Attachment.Name)"
    }

    # TERMINATE the script at this point
    exit
}



##############    CHAPTER 2: DETERMINE AND SANITY-CHECK RETURNED STUDENT ACCOUNTS TO RE-ENABLE    ###############

$ActiveAccountIDs = $ActiveAccounts | Select-Object -ExpandProperty EmployeeID
$ExistingDisabledAccountIDs = Get-ADUser -SearchBase 'OU=Disabled User Accounts,DC=efrafa,DC=net' -Filter * -Properties EmployeeID |
    Select-Object -ExpandProperty EmployeeID

# Check to see if accounts of enrolled students exist, but are disabled.
# This could be done in fewer lines of code, but we need the ID numbers in the next chapter.
$WronglyDisabledAccountIDs = foreach ($ID in $EnrolledStudentIDs) {
    if ($ID -in $ExistingDisabledAccountIDs) {
        Write-Output -InputObject $ID
    }
}
$WronglyDisabledStudents = foreach ($Student in $EnrolledStudents) {
    if ($Student.STUDENT_ID -in $WronglyDisabledAccountIDs) {
        Write-Output -InputObject $Student
    }
}

# Sanity check.
if (($WronglyDisabledStudents).count -gt 30) {
    # Send email reporting sanity check failure.
    $WronglyDisabledStudentsSanityList = $WronglyDisabledStudents | Select-Object -ExpandProperty EMAIL_ADDRESS
    New-Item -ItemType File -Path "$PADbotDirectory\SANITY_CHECK.txt"
    Set-Content -Path "$PADbotDirectory\SANITY_CHECK.txt" -Value $WronglyDisabledStudentsSanityList
    $Attachments = Get-ChildItem -Path "$PADbotDirectory\*.txt"
    $EmailBody = Get-Content -Path "$PSScriptRoot\Files\MailBody_Enable-SanityCheck"
    Send-MailMessage -From 'PADbot <padbot@efrafa.net>' -To 'Tech Dept <techsupport@efrafa.net>' `
        -Subject 'ERROR - TOO MANY ACCOUNTS TO RE-ENABLE' -Body $EmailBody -SmtpServer 'smtp.efrafa.net' -Attachments $Attachments

    # Archive the log files and clear them from the next run so they are not sent again.
    $Date = (Get-Date).ToString("yyyy-MM-dd")
    $Path = "$PADbotDirectory\Logs"
    foreach ($Attachment in $Attachments) {
        Move-Item -Path $Attachment -Destination "$Path\$Date-$($Attachment.Name)"
    }

    # TERMINATE the script at this point
    exit
}



##############    CHAPTER 3: DETERMINE AND SANITY-CHECK NEW STUDENT ACCOUNTS TO CREATE    ##############
# Create the list of new accounts to create.
$NewStudentIDs = foreach ($ID in $EnrolledStudentIDs) {
    if ($ID -notin $ActiveAccountIDs -and $ID -notin $WronglyDisabledAccountIDs) {
        Write-Output -InputObject $ID
    }
}

$NewStudents = foreach ($Student in $EnrolledStudents) {
    if ($Student.STUDENT_ID -in $NewStudentIDs) {
        Write-Output -InputObject $Student
    }
}

# Sanity check.
if (($NewStudents).count -gt 30) {
    # Send email reporting sanity check failure.
    $NewStudentsSanityList = $NewStudents | Select-Object -ExpandProperty EMAIL_ADDRESS
    New-Item -ItemType File -Path "$PADbotDirectory\SANITY_CHECK.txt"
    Set-Content -Path "$PADbotDirectory\SANITY_CHECK.txt" -Value $NewStudentsSanityList
    $Attachments = Get-ChildItem -Path "$PADbotDirectory\*.txt"
    $EmailBody = Get-Content -Path "$PSScriptRoot\Files\MailBody_Add-SanityCheck"
    Send-MailMessage -From 'PADbot <padbot@efrafa.net>' -To 'Tech Dept <techsupport@efrafa.net>' `
        -Subject 'ERROR - TOO MANY ACCOUNTS TO CREATE' -Body $EmailBody -SmtpServer 'smtp.efrafa.net' -Attachments $Attachments

    # Archive the log files and clear them from the next run so they are not sent again.
    $Date = (Get-Date).ToString("yyyy-MM-dd")
    $Path = "$PADbotDirectory\Logs"
    foreach ($Attachment in $Attachments) {
        Move-Item -Path $Attachment -Destination "$Path\$Date-$($Attachment.Name)"
    }

    # TERMINATE the script at this point
    exit
}



##############    CHAPTER 4: CALL FUNCTIONS TO DISABLE, ENABLE, AND ADD STUDENT ACCOUNTS    ###############

# Call function to disable accounts.
if ($WithdrawnAccounts) {
    Disable-StudentAccounts -AccountsToDisable $WithdrawnAccounts -PADbotDirectory $PADbotDirectory
}

# Call function to reenable accounts.
if ($WronglyDisabledStudents) {
    Enable-StudentAccounts -StudentsToReenable $WronglyDisabledStudents -PADbotDirectory $PADbotDirectory -GradeK $GradeK -Grade1 $Grade1 `
    -Grade2 $Grade2 -Grade3 $Grade3 -Grade4 $Grade4 -Grade5 $Grade5 -Grade6 $Grade6 -Grade7 $Grade7 -Grade8 $Grade8 `
    -Grade9 $Grade9 -Grade10 $Grade10 -Grade11 $Grade11 -Grade12 $Grade12
}

# Call function to create accounts.
if ($NewStudents) {
    Add-StudentAccounts -StudentsToAdd $NewStudents -PADbotDirectory $PADbotDirectory -GradeK $GradeK -Grade1 $Grade1 `
        -Grade2 $Grade2 -Grade3 $Grade3 -Grade4 $Grade4 -Grade5 $Grade5 -Grade6 $Grade6 -Grade7 $Grade7 -Grade8 $Grade8 `
        -Grade9 $Grade9 -Grade10 $Grade10 -Grade11 $Grade11 -Grade12 $Grade12
}



##############    CHAPTER 5: EXECUTE GOOGLE CLOUD DIRECTORY SYNC    ###############

# The GCDS scheduled task must be run as the GCDS user.
# The password has been previously encrypted in a file which is decryptable only by the PSGSuite user.
if ($WithdrawnAccounts -or $WronglyDisabledStudents -or $NewStudents) {
    $GCDSPassword = Get-Content -Path "$PADbotDirectory\GCDS_Pwd" | ConvertTo-SecureString
    $GCDSCredential = New-Object -TypeName System.Management.Automation.PSCredential ('gcds@efrafa.net', $GCDSPassword)
    $GCDSSession = New-PSSession -Credential $GCDSCredential
    Invoke-Command -Session $GCDSSession -Script { Start-ScheduledTask -TaskPath \Efrafa\ -TaskName 'Google Cloud Directory Sync' }

    # Without a manual sleep, PowerShell will NOT wait for the scheduled task to finish before proceeding.
    Start-Sleep -Seconds 720
}



##############    CHAPTER 6: SET NEW STUDENT PASSWORDS    ###############

if ($NewStudents) {
    # Create a variable to catch password reset errors.
    $UnableToSetPassword = @()

    # Create an array variable to feed to PSGSuite later, when we update the password spreadsheet.
    $NewAccountsAndPasswords = @()

    # Add .NET System.Web assembly, which will be used to generate a random password.
    Add-Type -AssemblyName 'System.Web'

    foreach ($Student in $NewStudents) {
        try {
            # Generate random password.
            $MinLength = 8
            $MaxLength = 12
            $Length = Get-Random -Minimum $MinLength -Maximum $MaxLength
            $NonAlphaChars = 2
            $Password = [System.Web.Security.Membership]::GeneratePassword($Length, $NonAlphaChars)
            $SecurePassword = ConvertTo-SecureString -AsPlainText $Password -Force
            
            # Set AD account password.
            $EmployeeID = $Student.STUDENT_ID
            $Account = Get-ADUser -SearchBase 'OU=Student Accounts,DC=efrafa,DC=net' `
                -Filter "EmployeeID -EQ $EmployeeID" -Properties Mail,Description

            Set-ADAccountPassword -Server ldap.efrafa.net -Identity $Account -NewPassword $SecurePassword -Reset

            # Create an object to feed into the array of account and passwords to add to the spreadsheet later.
            $AccountAndPassword = [PSCustomObject]@{
                Description = $Account.Description
                GivenName = $Account.GivenName
                Surname = $Account.Surname
                Mail = $Account.Mail
                Password = $Password
            }
            $NewAccountsAndPasswords += $AccountAndPassword
        }
        catch {
            $UnableToSetPassword += (($Student.EMAIL_ADDRESS, $Student.LAST_NAME, $Student.FIRST_NAME) -join ', ')
        }
    }
    # Write the errors to a log file, if any.
    if ($UnableToSetPassword) {
        $UnableToSetPassword | Out-File -FilePath "$PADbotDirectory\Set_Password_Errors.txt"
    }
    # Update the new student password spreadsheet
    $PasswordSpreadsheetID = 'y2C5bYRUqZMREHc9kEaUPyr&&G$H3#bCCUb&kF6Pk^9s'
    Add-GSSheetValues -User psgsuite -SpreadsheetId $PasswordSpreadsheetID -Array $NewAccountsAndPasswords -Range 'A:Z' -Append
}



##############    CHAPTER 7: EMAIL LOG FILES TO TECH DEPARTMENT STAFF    ###############

$Attachments = Get-ChildItem -Path "$PADbotDirectory\*.txt"

if ($Attachments) {
    $EmailBody = Get-Content -Path "$PSScriptRoot\Files\MailBody_Normal"
    $ErrorFiles = Get-ChildItem -Path "$PADbotDirectory\*Errors*"

    if ($ErrorFiles) {
        $EmailSubject = 'Automated changes to student accounts - CHECK ERRORS'
    }
    else {
        $EmailSubject = 'Automated changes to student accounts - CLEAN EXECUTION'
    }

    Send-MailMessage -From 'PADbot <padbot@efrafa.net>' -To 'Help Desk <techsupport@efrafa.net>' `
        -Subject $EmailSubject -Body $EmailBody -SmtpServer 'smtp.efrafa.net' -Attachments $Attachments

    # Archive the log files and clear them from the next run so they are not sent again
    $Date = (Get-Date).ToString("yyyy-MM-dd")
    $Path = "$PADbotDirectory\Logs"
    foreach ($Attachment in $Attachments) {
        Move-Item -Path $Attachment -Destination "$Path\$Date-$($Attachment.Name)"
    }
}
else {
    $EmailSubject = 'Automated changes to student accounts - NOTHING TO DO'
    $EmailBody = Get-Content -Path "$PSScriptRoot\Files\MailBody_NoChanges"
    Send-MailMessage -From 'PADbot <padbot@efrafa.net>' -To 'Help Desk <techsupport@efrafa.net>' `
        -Subject $EmailSubject -Body $EmailBody -SmtpServer 'smtp.efrafa.net'
}
