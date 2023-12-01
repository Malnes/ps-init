# Ps-Init

This repo contains the base files for a new PowerShell project. Only projects that is intended to be executed manually or automated to run on a client/server should use this template. Deployment scenarios like azure funcitons or runbooks should not user this template

## Files

| File/Folder name | Description  |
|---|---|
| app | The root folder of your PowerSell files  |
| app\main.ps1 | Write your code here! |
| modules | Auto-generated folder containing all dependency-installed modules. Do not touch!  |
| dependencies.psd1 | Edit this file to add dependencies on powershell modules |
| local.settings.json | Declaration of enviroment variables. Put stuff you dont want to push to git here. The values can be accessed in your script from the **$var** object |
| setup.ps1 | main script for processing depencendies and other stuff for your project. Do not touch |


## How to get started

1. First download the files
```
git clone https://github.com/username/repository.git
```