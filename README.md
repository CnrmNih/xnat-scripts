# XNAT Bulk Importer Scripts

This collection of scripts and functions performs bulk import operations. To use the scripts, run with the following syntax:

```
./xnatimport <XNAT_URL> <XNAT_USER> <FOLDER> <PROJECT> <SUBJECT>
```

Where:

- XNAT_URL is the address of the XNAT server to which you want to send data
- XNAT_USER is the name of the user with which you want to authenticate
- FOLDER is the location of the subject's data
- PROJECT is the project into which you want to import the data
- SUBJECT is the subject with which you want to associate the data

As implied by the parameters above, the **xnatimport** script is currently limited to importing data for a single user. The next revision will support recursively walking a folder and importing data for multiple subjects.

