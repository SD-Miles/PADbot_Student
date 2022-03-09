function Enable-StudentAccounts {

    param (
        $StudentsToReenable,
        $PADbotDirectory,
        $GradeK,
        $Grade1,
        $Grade2,
        $Grade3,
        $Grade4,
        $Grade5,
        $Grade6,
        $Grade7,
        $Grade8,
        $Grade9,
        $Grade10,
        $Grade11,
        $Grade12
    )

    # Create variables to keep track of the results.
    $AccountsReenabled = @()
    $UnableToReenable = @()

    # Try to reenable all returning student accounts in this giant foreach loop.
    foreach ($Student in $StudentsToReenable) {
        try {
            # Set some AD account attributes
            $OtherAttributes = @{'wWWHomePage'="STUDENT"}

            # Kindergarten variables
            if (($Student.GRADE_LEVEL -like 'K5*') -or ($Student.GRADE_LEVEL -eq 'F5')) {
                $Path = "OU=Class of $GradeK - K,OU=Student Accounts,DC=efrafa,DC=net"
                $Description = "STUDENT - $GradeK"
                $ADGroups = @("$GradeK Students", 'All Students')
            }

            # Grade 1 variables
            if ($Student.GRADE_LEVEL -eq '01') {
                $Path = "OU=Class of $Grade1 - 1,OU=Student Accounts,DC=efrafa,DC=net"
                $Description = "STUDENT - $Grade1"
                $ADGroups = @("$Grade1 Students", 'All Students')
            }

            # Grade 2 variables
            if ($Student.GRADE_LEVEL -eq '02') {
                $Path = "OU=Class of $Grade2 - 2,OU=Student Accounts,DC=efrafa,DC=net"
                $Description = "STUDENT - $Grade2"
                $ADGroups = @("$Grade2 Students", 'All Students')    
            }

            # Grade 3 variables
            if ($Student.GRADE_LEVEL -eq '03') {
                $Path = "OU=Class of $Grade3 - 3,OU=Student Accounts,DC=efrafa,DC=net"
                $Description = "STUDENT - $Grade3"
                $ADGroups = @("$Grade3 Students", 'All Students')    
            }

            # Grade 4 variables
            if ($Student.GRADE_LEVEL -eq '04') {
                $Path = "OU=Class of $Grade4 - 4,OU=Student Accounts,DC=efrafa,DC=net"
                $Description = "STUDENT - $Grade4"
                $ADGroups = @("$Grade4 Students", 'All Students')    
            }

            # Grade 5 variables
            if ($Student.GRADE_LEVEL -eq '05') {
                $Path = "OU=Class of $Grade5 - 5,OU=Student Accounts,DC=efrafa,DC=net"
                $Description = "STUDENT - $Grade5"
                $ADGroups = @("$Grade5 Students", 'All Students')    
            }

            # Grade 6 variables
            if ($Student.GRADE_LEVEL -eq '06') {
                $Path = "OU=Class of $Grade6 - 6,OU=Student Accounts,DC=efrafa,DC=net"
                $Description = "STUDENT - $Grade6"
                $ADGroups = @("$Grade6 Students", 'All Students')    
            }

            # Grade 7 variables
            if ($Student.GRADE_LEVEL -eq '07') {
                $Path = "OU=Class of $Grade7 - 7,OU=Student Accounts,DC=efrafa,DC=net"
                $Description = "STUDENT - $Grade7"
                $ADGroups = @("$Grade7 Students", 'All Students')    
            }

            # Grade 8 variables
            if ($Student.GRADE_LEVEL -eq '08') {
                $Path = "OU=Class of $Grade8 - 8,OU=Student Accounts,DC=efrafa,DC=net"
                $Description = "STUDENT - $Grade8"
                $ADGroups = @("$Grade8 Students", 'All Students')    
            }

            # Grade 9 variables
            if ($Student.GRADE_LEVEL -eq '09') {
                $Path = "OU=Class of $Grade9 - 9,OU=Student Accounts,DC=efrafa,DC=net"
                $Description = "STUDENT - $Grade9"
                $ADGroups = @("$Grade9 Students", 'All Students', 'NPS - ESD-Personal Wifi - User')    
            }

            # Grade 10 variables
            if ($Student.GRADE_LEVEL -eq '10') {
                $Path = "OU=Class of $Grade10 - 10,OU=Student Accounts,DC=efrafa,DC=net"
                $Description = "STUDENT - $Grade10"
                $ADGroups = @("$Grade10 Students", 'All Students', 'NPS - ESD-Personal Wifi - User')    
            }

            # Grade 11 variables
            if ($Student.GRADE_LEVEL -eq '11') {
                $Path = "OU=Class of $Grade11 - 11,OU=Student Accounts,DC=efrafa,DC=net"
                $Description = "STUDENT - $Grade11"
                $ADGroups = @("$Grade11 Students", 'All Students', 'NPS - ESD-Personal Wifi - User')    
            }

            # Grade 12 variables
            if ($Student.GRADE_LEVEL -eq '12') {
                $Path = "OU=Class of $Grade12 - 12,OU=Student Accounts,DC=efrafa,DC=net"
                $Description = "STUDENT - $Grade12"
                $ADGroups = @("$Grade12 Students", 'All Students', 'NPS - ESD-Personal Wifi - User')    
            }

            # Reenable all returning student accounts and add them to their respective groups
            $AccountToReEnable = Get-ADUser -SearchBase 'OU=Disabled User Accounts,DC=efrafa,DC=net' `
                -Filter "EmployeeID -EQ '$($Student.STUDENT_ID)'" -Properties Mail

            Set-ADUser -Enabled $True -Identity $AccountToReEnable -Description $Description -Replace $OtherAttributes
            
            foreach ($Group in $ADGroups) {
                Add-ADGroupMember -Identity $Group -Members $AccountToReEnable
            }

            Move-ADObject -Identity $AccountToReEnable -TargetPath $Path

            # Increment the positive result tracking variable for each account created
            $AccountsReenabled += (($AccountToReEnable.Mail, $AccountToReEnable.Surname, $AccountToReEnable.GivenName) -join ', ')
        } # Close try loop

        catch {
            # Increment the negative result tracking variable for each failure
            $UnableToReenable += (($Student.EMAIL_ADDRESS, $Student.LAST_NAME, $Student.FIRST_NAME) -join ', ')
        }
    } # Close foreach loop

    # Write the results of the function to log files.
    if ($AccountsReenabled) {
        $AccountsReenabled | Out-File -FilePath "$PADbotDirectory\Accounts_Reenabled.txt"
    }
    if ($UnableToReenable) {
        $UnableToReenable | Out-File -FilePath "$PADbotDirectory\Account_Reenable_Errors.txt"
    }
} # Close function