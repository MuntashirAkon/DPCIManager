# DPCIManager
Simple OS X app for viewing PCI hardware info

**NOTE:** I'll only provide support for `dspci` tool, NOT `DPCIManager.app` (I'll update PCI IDs occassionally, however).
  But I'am still keeping it in case someone is interested in contributing.

**NOTE 2:** By "_version_", I meant the version of `dspci`, NOT `DPCIManager.app` (which will remain `1.5`)

### Binaries
You can find the [latest binary](https://github.com/MuntashirAkon/DPCIManager/releases/latest)
in the [release](https://github.com/MuntashirAkon/DPCIManager/releases) section.

Old binaries can be found here: https://sourceforge.net/projects/dpcimanager/files

### Usage (for `dspci`)
As of version `1.6`, you can get JSON output using `JSONData` agrument:
```sh
dspci JSONData
```
**Example Output**
```json
[
  {
    "Info" : {
      "Name" : "Intel Corporation",
      "Vendor" : "Xeon E3-1200 v6\/7th Gen Core Processor Host Bridge\/DRAM Registers"
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
      "Name" : "Intel Corporation",
      "Vendor" : "HD Graphics 620"
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
  },
  {
    "Info" : {
      "Name" : "Intel Corporation",
      "Vendor" : "Xeon E3-1200 v5\/E3-1500 v5\/6th Gen Core Processor Thermal Subsystem"
    },
    "ID" : {
      "VendorID" : "8086",
      "DeviceID" : "1903"
    },
    "SubsysID" : {
      "VendorID" : "1028",
      "DeviceID" : "0767"
    },
    "Rev" : "02",
    "BDF" : "00:04.0",
    "Class" : {
      "Code" : "1180",
      "Name" : "Signal processing controller"
    }
  },
  {
    "Info" : {
      "Name" : "Intel Corporation",
      "Vendor" : "Sunrise Point-LP USB 3.0 xHCI Controller"
    },
    "ID" : {
      "VendorID" : "8086",
      "DeviceID" : "9d2f"
    },
    "SubsysID" : {
      "VendorID" : "1028",
      "DeviceID" : "0767"
    },
    "Rev" : "21",
    "BDF" : "00:14.0",
    "Class" : {
      "Code" : "0c03",
      "Name" : "USB controller"
    }
  },
  {
    "Info" : {
      "Name" : "Intel Corporation",
      "Vendor" : "Sunrise Point-LP Thermal subsystem"
    },
    "ID" : {
      "VendorID" : "8086",
      "DeviceID" : "9d31"
    },
    "SubsysID" : {
      "VendorID" : "1028",
      "DeviceID" : "0767"
    },
    "Rev" : "21",
    "BDF" : "00:14.2",
    "Class" : {
      "Code" : "1180",
      "Name" : "Signal processing controller"
    }
  },
  {
    "Info" : {
      "Name" : "Intel Corporation",
      "Vendor" : "Sunrise Point-LP Serial IO I2C Controller #0"
    },
    "ID" : {
      "VendorID" : "8086",
      "DeviceID" : "9d60"
    },
    "SubsysID" : {
      "VendorID" : "1028",
      "DeviceID" : "0767"
    },
    "Rev" : "21",
    "BDF" : "00:15.0",
    "Class" : {
      "Code" : "1180",
      "Name" : "Signal processing controller"
    }
  },
  {
    "Info" : {
      "Name" : "Intel Corporation",
      "Vendor" : "Sunrise Point-LP Serial IO I2C Controller #1"
    },
    "ID" : {
      "VendorID" : "8086",
      "DeviceID" : "9d61"
    },
    "SubsysID" : {
      "VendorID" : "1028",
      "DeviceID" : "0767"
    },
    "Rev" : "21",
    "BDF" : "00:15.1",
    "Class" : {
      "Code" : "1180",
      "Name" : "Signal processing controller"
    }
  },
  {
    "Info" : {
      "Name" : "Intel Corporation",
      "Vendor" : "Sunrise Point-LP CSME HECI #1"
    },
    "ID" : {
      "VendorID" : "8086",
      "DeviceID" : "9d3a"
    },
    "SubsysID" : {
      "VendorID" : "1028",
      "DeviceID" : "0767"
    },
    "Rev" : "21",
    "BDF" : "00:16.0",
    "Class" : {
      "Code" : "0780",
      "Name" : "Communication controller"
    }
  },
  {
    "Info" : {
      "Name" : "Intel Corporation",
      "Vendor" : "Sunrise Point-LP SATA Controller [AHCI mode]"
    },
    "ID" : {
      "VendorID" : "8086",
      "DeviceID" : "9d03"
    },
    "SubsysID" : {
      "VendorID" : "1028",
      "DeviceID" : "0767"
    },
    "Rev" : "21",
    "BDF" : "00:17.0",
    "Class" : {
      "Code" : "0106",
      "Name" : "SATA controller"
    }
  },
  {
    "Info" : {
      "Name" : "Intel Corporation",
      "Vendor" : "Sunrise Point-LP PCI Express Root Port #5"
    },
    "ID" : {
      "VendorID" : "8086",
      "DeviceID" : "9d14"
    },
    "SubsysID" : {
      "VendorID" : "0000",
      "DeviceID" : "0000"
    },
    "Rev" : "f1",
    "BDF" : "00:1c.0",
    "Class" : {
      "Code" : "0604",
      "Name" : "PCI bridge"
    }
  },
  {
    "Info" : {
      "Name" : "Intel Corporation",
      "Vendor" : "Sunrise Point-LP PCI Express Root Port #6"
    },
    "ID" : {
      "VendorID" : "8086",
      "DeviceID" : "9d15"
    },
    "SubsysID" : {
      "VendorID" : "007f",
      "DeviceID" : "0000"
    },
    "Rev" : "f1",
    "BDF" : "00:1c.5",
    "Class" : {
      "Code" : "0604",
      "Name" : "PCI bridge"
    }
  },
  {
    "Info" : {
      "Name" : "Intel Corporation",
      "Vendor" : "Sunrise Point-LP LPC Controller"
    },
    "ID" : {
      "VendorID" : "8086",
      "DeviceID" : "9d58"
    },
    "SubsysID" : {
      "VendorID" : "1028",
      "DeviceID" : "0767"
    },
    "Rev" : "21",
    "BDF" : "00:1f.0",
    "Class" : {
      "Code" : "0601",
      "Name" : "ISA bridge"
    }
  },
  {
    "Info" : {
      "Name" : "Intel Corporation",
      "Vendor" : "Sunrise Point-LP PMC"
    },
    "ID" : {
      "VendorID" : "8086",
      "DeviceID" : "9d21"
    },
    "SubsysID" : {
      "VendorID" : "1028",
      "DeviceID" : "0767"
    },
    "Rev" : "21",
    "BDF" : "00:1f.2",
    "Class" : {
      "Code" : "0580",
      "Name" : "Memory controller"
    }
  },
  {
    "Info" : {
      "Name" : "Intel Corporation",
      "Vendor" : "Sunrise Point-LP HD Audio"
    },
    "ID" : {
      "VendorID" : "8086",
      "DeviceID" : "9d71"
    },
    "SubsysID" : {
      "VendorID" : "1028",
      "DeviceID" : "0767"
    },
    "Rev" : "21",
    "BDF" : "00:1f.3",
    "Class" : {
      "Code" : "0403",
      "Name" : "Audio device"
    }
  },
  {
    "Info" : {
      "Name" : "Intel Corporation",
      "Vendor" : "Sunrise Point-LP SMBus"
    },
    "ID" : {
      "VendorID" : "8086",
      "DeviceID" : "9d23"
    },
    "SubsysID" : {
      "VendorID" : "1028",
      "DeviceID" : "0767"
    },
    "Rev" : "21",
    "BDF" : "00:1f.4",
    "Class" : {
      "Code" : "0c05",
      "Name" : "SMBus"
    }
  },
  {
    "Info" : {
      "Name" : "Intel Corporation",
      "Vendor" : "Wireless 3165"
    },
    "ID" : {
      "VendorID" : "8086",
      "DeviceID" : "3165"
    },
    "SubsysID" : {
      "VendorID" : "8086",
      "DeviceID" : "4410"
    },
    "Rev" : "79",
    "BDF" : "01:00.0",
    "Class" : {
      "Code" : "0280",
      "Name" : "Network controller"
    }
  },
  {
    "Info" : {
      "Name" : "Realtek Semiconductor Co., Ltd.",
      "Vendor" : "RTL810xE PCI Express Fast Ethernet controller"
    },
    "ID" : {
      "VendorID" : "10ec",
      "DeviceID" : "8136"
    },
    "SubsysID" : {
      "VendorID" : "1028",
      "DeviceID" : "0767"
    },
    "Rev" : "07",
    "BDF" : "02:00.0",
    "Class" : {
      "Code" : "0200",
      "Name" : "Ethernet controller"
    }
  }
]
```

### License
- GPLv3 (Original Work by @PHPdev32)
- MIT (My Works)
