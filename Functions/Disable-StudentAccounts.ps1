function Disable-StudentAccounts {

    param ($AccountsToDisable, $PADbotDirectory)

    # Create variables to keep track of the results.
    $UsersDisabled = @($null)
    $UnableToDisable = @($null)

    # Try to disable the withdrawn students.
    foreach ($Account in $AccountsToDisable) {
        try {
            $Account | ForEach-Object { $_.MemberOf | Remove-ADGroupMember -Members $_.DistinguishedName -Confirm:$false }
            $Account | Disable-ADAccount
            Move-ADObject -Identity $Account -TargetPath 'OU=Disabled User Accounts,DC=efrafa,DC=net'
            $UsersDisabled += (($Account.Mail, $Account.Surname, $Account.GivenName) -join ', ')
        }
        catch {
            $UnableToDisable += (($Account.Mail, $Account.Surname, $Account.GivenName) -join ', ')
        }
    }
    # Write the results of the function to log files.
    if ($UsersDisabled) {
        $UsersDisabled | Out-File -FilePath "$PADbotDirectory\Accounts_Disabled.txt"
    }
    if ($UnableToDisable) {
        $UnableToDisable | Out-File -FilePath "$PADbotDirectory\Account_Disable_Errors.txt"
    }
}