# DPCIManager
Simple OS X app for viewing PCI hardware info

**NOTE:** I'll only provide support for `dspci` tool, NOT `DPCIManager.app` (I'll update PCI IDs occassionally, however).
  But I'am still keeping it in case someone is interested in contributing.

### Binaries
You can find the [latest binary](https://github.com/MuntashirAkon/DPCIManager/releases/latest)
in the [release](https://github.com/MuntashirAkon/DPCIManager/releases) section.

Old binaries can be found here: https://sourceforge.net/projects/dpcimanager/files

### Usage (for `dspci`)
As of version `1.6`, you can get JSON output using `JSONData` agrument:
```sh
dspci JSONData
```

#### JSON Schema
An output contains an array of objects which have the following attributes. 
For understanding JSON schema easily, I've . (dot) for objects and [] (square brackets) for arrays:

* `BDF`: (String) Bus number, Device number, Function number (Format `B:D.F`)
* `Class`: (Object) Device's class
    - `Class.Name`: (String) Device's class name
    - `Class.Code`: (Hex String) Device's class code
* `Info`: (Object) Device info
    - `Info.Name`: (String) Device's name
    - `Info.Vendor`: (String) Device's vendor
* `ID`: (Object) Device's full ID
    - `ID.VendorID`: (Hex String) Device's vendor ID
    - `ID.DeviceID`: (Hex String) Device's ID
* `SubsysID`: (Object) Device's subsystem ID
    - `SubsysID.VendorID`: (Hex String) Subsystem's vendor ID
    - `SubsysID.DeviceID`: (Hex String) Subsystem's ID
* `Rev`:  (Hex String)  Revision

#### Example Output
```json
[
  {
    "Info" : {
      "Name" : "Xeon E3-1200 v6\/7th Gen Core Processor Host Bridge\/DRAM Registers",
      "Vendor" : "Intel Corporation"
    },
    "ID" : {
      "VendorID" : "8086",
      "DeviceID" : "5904"
    },
    "SubsysID" : {
      "VendorID" : "1028",
      "DeviceID" : "0767"
    },
    "Rev" : "02",
    "BDF" : "00:00.0",
    "Class" : {
      "Code" : "0600",
      "Name" : "Host bridge"
    }
  },
  {
    "Info" : {
      "Name" : "HD Graphics 620",
      "Vendor" : "Intel Corporation"
    },
    "ID" : {
      "VendorID" : "8086",
      "DeviceID" : "5916"
    },
    "SubsysID" : {
      "VendorID" : "106b",
      "DeviceID" : "0767"
    },
    "Rev" : "02",
    "BDF" : "00:02.0",
    "Class" : {
      "Code" : "0300",
      "Name" : "VGA compatible controller"
    }
  }
]
```

### License
- GPLv3 (Original Work by @PHPdev32)
- MIT (My Works)
