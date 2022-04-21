PADbot_Student
==============

This is not production code!
----------------------------

PADbot_Student is a script to automate the creation of student accounts in Active Directory and synchronize them to Google Workspace for Education. The code you see here has been posted for demonstration only, and has been modified from the code I use in production to **remove all potential security/privacy issues** and cut some tangential operations. The Active Directory domain and several other specific values are all fake and/or randomly generated.

While you cannot reuse this code in your environment as-is, you are welcome to use it as a basis for similiar scripts in other organizations—especially K-12 school districts.

Objectives (or "Table of Contents")
-----------------------------------

The root script is divided into the following "chapters":
- Import modules and functions
- Define global variables
- Chapter 1: Determine and sanity-check withdrawn student accounts to disable
- Chapter 2: Determine and sanity-check returned student accounts to re-enable
- Chapter 3: Determine and sanity-check new student accounts to add
- Chapter 4: Call functions to disable, enable, and add student accounts
- Chapter 5: Execute Google Cloud Directory Sync
- Chapter 6: Set new student passwords
- Chapter 7: Email log files to technology department staff

Folder Structure
----------------

PADbot contains a root script, functions, and files, all of which should be tracked in a source control system. In production, this bundle should be nested inside a manually-defined containing directory, because PADbot will create and archive log files in the course of execution and we do not want these included in the source control. It should look like this:

```
$PADbotDirectory/
  - EnrolledStudents.csv
  - GCDS_Pwd
  Logs/
  padbot_student/
      - PADbot_Student.ps1
      - README.md
    Functions/
      - Add-StudentAccounts.ps1
      - Disable-StudentAccounts.ps1
      - Enable-StudentAccounts.ps1
    Files/
      - MailBody_Add-SanityCheck
      - MailBody_Disable-SanityCheck
      - MailBody_Enable-SanityCheck
      - MailBody_NoChanges
      - MailBody_Normal
```

$PADbotDirectory is defined as a global variable in the root script and fed into the functions as necessary.

Enrolled Students CSV
---------------------

In my environment, EnrolledStudents.csv is dropped into $PADbotDirectory via SFTP every evening by a student information system. We have filters in place in the SIS to export only actively enrolled students in the current school year. PADbot requires a CSV with the following columns to function:

    SCHOOL_YEAR, SCHOOL_ID, GRADE_LEVEL, STUDENT_ID, LAST_NAME, FIRST_NAME, EMAIL_ADDRESS, STATUS_FLG

PADbot uses the STUDENT_ID property to make its comparison between the list of enrolled students in Sapphire and accounts in Active Directory. To function correctly, it is imperative that each student’s STUDENT_ID match the value of their Active Directory account’s EmployeeID attribute. By using this immutable piece of identifying data, PADbot avoids reconfiguring accounts that students have been using successfully, even if they have non-standard email addresses (like doejohn2@efrafa.net, for example) or other unique attributes.

Requirements
------------

In addition to EnrolledStudents.csv, the script imports two modules which must be available on the host system: ActiveDirectory, and PSGSuite (which is used to update the student password Google Sheet in Chapter 6.)

Also, Chapter 5 requires an existing Google Cloud Directory Sync configuration, which is outside the scope of the demonstration code. GCDS allows you to synchronize Active Directory with Google Directory in accordance with the paramters you define. I prefer to use a scheduled task to execute the synchronization, and then invoke the task from within PADbot. This abstraction layer gives us the flexibility to trigger the directory synchronization manually when we can't afford to wait for PADbot. The scheduled task should be run under a different account (gcds@efrafa.net in this case), and the password for this account should encrypted in the file GCDS_Pwd. Make this file decryptable only by the user account under which PADbot runs.

Finally, Chapter 7 assumes the existence of an SMTP server at smtp.efrafa.net.
