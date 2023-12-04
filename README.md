# Ps-Init

> **Note**: This script is intended for testing purposes and may not be the best solution for production environments. It might contain bugs and is likely not maintained regularly. Use it at your own risk.

PS-init is a PowerShell script designed to streamline the setup of PowerShell projects and scripts. It creates base files (scaffolding) essential for any PowerShell project, making it easier to get started with script development. The script is specifically tailored for PowerShell 7.

## Features

- **Scaffolding**: Automatically generates foundational files for PowerShell projects/scripts.
- **Module Management**: Provides functionality to manage PowerShell modules in a dedicated file.
- **Variable Separation**: Allows for the management of variables in a separate file, which is excluded from Git synchronization.

## Prerequisites

PowerShell 7 or higher.

## Installation
You can install ps-init directly from the PowerShell Gallery:

``` PowerShell
install-script ps-init
```

## Usage
To initialize a new PowerShell project, simply run **ps-init** in your project directory:

``` PowerShell
ps-init
```

For reprocessing an existing project with overwriting capabilities, use the -forceReprocess parameter:

``` PowerShell
ps-init -forceReprocess:$true
```

## File structure

The following table shows the files created ant is purpose
| File/Folder name | Description  |
|---|---|
| app\main.ps1 | Write your code here! |
| modules | Auto-generated folder containing all dependency-installed modules. Do not touch!  |
| dependencies.psd1 | Edit this file to add dependencies on powershell modules |
| local.settings.json | This file is created on first setup. Used to declaration variables. Put stuff you dont want to push to git here. The values can be accessed in your script from the **$var** object |
| setup.ps1 | main script for processing depencendies and other stuff for your project. Do not touch |

## Contributing
Contributions to ps-init are welcome! Feel free to submit pull requests or report issues to enhance the script's functionality and efficiency.

## License
This script is released under the MIT License. For more details, see the LICENSE file in this repository.

The MIT License is a permissive license that is short and to the point. It lets people do anything they want with your code as long as they provide attribution back to you and don’t hold you liable.

Copyright (c) 2023 Malnes