//
//  DataTypeHandler.m
//  dspci
//
//  Created by Muntashir Al-Islam on 8/20/18.
//

#import <Foundation/Foundation.h>
#import <mach-o/getsect.h>
#import <string.h>
#import "DataTypeHandler.h"
#import "DataTypes.h"
#import "PCI.h"
#import "JSON.h"

#import "Tables.h"

#define kPCIFormat @"%04lX:%04lX"

@implementation DataTypeHandler
- (instancetype) init {
    printJSON = false;
    classes = [NSMutableDictionary dictionary];
    vendors = [NSMutableDictionary dictionary];
    devices = [NSMutableArray array];
    fetchDate = [self loadPCIIDs];
    dataType = DT_LIST_DEFAULT_INT;
    return self;
}

//
// I'm in a hurry now!
//
- (unsigned) dataTypeToInt: (NSString *)dataType {
    if([dataType  isEqual: DT_LIST_DEFAULT]) return DT_TO_INT(DT_LIST_DEFAULT);
    if([dataType  isEqual: DT_LIST_PCI_ID]) return DT_TO_INT(DT_LIST_PCI_ID);
    if([dataType  isEqual: DT_LIST_AUDIO]) return DT_TO_INT(DT_LIST_AUDIO);
    if([dataType  isEqual: DT_LIST_AUDIO_ID]) return DT_TO_INT(DT_LIST_AUDIO_ID);
    if([dataType  isEqual: DT_LIST_AUDIO_CODEC_ID]) return DT_TO_INT(DT_LIST_AUDIO_CODEC_ID);
    if([dataType  isEqual: DT_LIST_AUDIO_CODEC_ID_WITH_REVISION]) return DT_TO_INT(DT_LIST_AUDIO_CODEC_ID_WITH_REVISION);
    if([dataType  isEqual: DT_LIST_GPU]) return DT_TO_INT(DT_LIST_GPU);
    if([dataType  isEqual: DT_LIST_GPU_ID]) return DT_TO_INT(DT_LIST_GPU_ID);
    if([dataType  isEqual: DT_LIST_NETWORK]) return DT_TO_INT(DT_LIST_NETWORK);
    if([dataType  isEqual: DT_LIST_NETWORK_ID]) return DT_TO_INT(DT_LIST_NETWORK_ID);
    if([dataType  isEqual: DT_LIST_CONNECTED]) return DT_TO_INT(DT_LIST_CONNECTED);
    if([dataType  isEqual: DT_LIST_CONNECTED_ID]) return DT_TO_INT(DT_LIST_CONNECTED_ID);
    if([dataType  isEqual: DT_LIST_ALL_ID]) return DT_TO_INT(DT_LIST_ALL_ID);
    return 0;
}

/**
 * This method sets the performs tasks based on the supplied data type
 *
 * @return exit code
 */
- (int) handleDataType: (NSString *)dataType {
    unsigned dataTypeInt = [self dataTypeToInt:dataType];
    self->dataType = dataTypeInt;
//    ddprintf(@"DataType: %@, Int: %u\n", dataType, dataTypeInt);
    switch (dataTypeInt) {
        case DT_LIST_DEFAULT_INT:
        case DT_LIST_PCI_ID_INT:
            [self printPCIList: 0];
            break;
        case DT_LIST_AUDIO_INT:
        case DT_LIST_AUDIO_ID_INT:
        case DT_LIST_AUDIO_CODEC_INT:
        case DT_LIST_AUDIO_CODEC_ID_INT:
        case DT_LIST_AUDIO_CODEC_ID_WITH_REVISION_INT:
            [self printAudioList];
            //printf("%s\n", [[self listAudio] bv_jsonStringWithPrettyPrint:true].UTF8String);
            break;
        case DT_LIST_GPU_INT:
        case DT_LIST_GPU_ID_INT:
            [self printGPUList];
            break;
        case DT_LIST_NETWORK_INT:
        case DT_LIST_NETWORK_ID_INT:
            [self printNetworkList];
            break;
        case DT_LIST_CONNECTED_INT:
        case DT_LIST_CONNECTED_ID_INT:
            [self printConnectedList];
            break;
        default:
            @throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"Invalid data type.\nUse `%@ --listDataTypes` to get a list of possible data types.", DDCliApp]  exitCode:EX_DATAERR];
    }
    return EXIT_SUCCESS;
}

/**
 * Loads PCI IDs
 *
 * @return Fetch date
 */
- (NSString *) loadPCIIDs {
    unsigned long len;
    char *handle = strdup(getsectdata("__TEXT", "__pci_ids", &len));
    NSNumber *currentClass;
    NSNumber *currentVendor;
    char buffer[LINE_MAX];
    sscanf(strstr(handle, "Version:"), "Version: %[^\n]", buffer);
    long device_id, subclass_id;
    char *buf;
    bool class_parse = false;
    while((buf = strsep(&handle, "\n")) != NULL) {
        if (buf[0] == '#' || strlen(buf) <= 4) continue;
        if (*buf == 'C') class_parse = true;
        if (class_parse) {
            if (*buf == '\t') {
                buf++;
                if (*buf != '\t') {
                    subclass_id = strtol(buf, NULL, 16);
                    buf += 4;
                    while (*buf == ' ' || *buf == '\t') buf++;
                    [[[classes objectForKey:currentClass] subClasses] setObject:@(buf) forKey:@(subclass_id)];
                }
            }
            else if (*buf == 'C') {
                buf += 2;
                currentClass = @(strtol(buf, NULL, 16));
                buf += 4;
                while (*buf == ' ' || *buf == '\t') buf++;
                [classes setObject:[pciClass create:@(buf)] forKey:currentClass];
            }
        }
        else {
            if (*buf == '\t') {
                buf++;
                if (*buf != '\t') {
                    device_id = strtol(buf, NULL, 16);
                    buf += 4;
                    while (*buf == ' ' || *buf == '\t') buf++;
                    [[[vendors objectForKey:currentVendor] devices] setObject:@(buf) forKey:@(device_id)];
                }
            }
            else if (*buf != '\\') {
                currentVendor = @(strtol(buf, NULL, 16));
                buf += 4;
                while (*buf == ' ' || *buf == '\t') buf++;
                [vendors setObject:[pciVendor create:@(buf)] forKey:currentVendor];
            }
        }
    }
    free(handle);
    io_iterator_t itThis;
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOPCIDevice"), &itThis) == KERN_SUCCESS) {
        io_service_t service;
        while((service = IOIteratorNext(itThis))){
            pciDevice *device = [pciDevice create:service classes:classes vendors:vendors];
            if (device.fullID + device.fullSubID > 0) [devices addObject:device];
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    return [NSString stringWithUTF8String:buffer];
}

/**
 * Print PCI IDs in normal or json format
 *
 * @param customDataType Show list based on this data type instead of the main dataType
 */
- (void) printPCIList: (unsigned) customDataType {
    // Determine data type
    unsigned dataType = (customDataType != 0) ? customDataType : self->dataType;
    
    if(!printJSON && dataType == DT_LIST_DEFAULT_INT) ddprintf(@"Using PCI.IDs %@\n", fetchDate);

    NSMutableArray *deviceList = [NSMutableArray array];
    NSDictionary *tmpDevice;
    for (pciDevice *device in [devices sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) { return [obj1 bdf] - [obj2 bdf]; }]){
        tmpDevice = device.lspciDictionary;
        [deviceList addObject:[self getPCIDeviceInfo:dataType device:device]];
    }
    // Print
    if(printJSON) printf("%s\n", [deviceList bv_jsonStringWithPrettyPrint:true].UTF8String);
    else printf("%s\n", [deviceList componentsJoinedByString:@"\n"].UTF8String);
}

- (id) getPCIDeviceInfo: (unsigned) dataType device: (pciDevice *) device {
    switch (dataType) {
        case DT_LIST_DEFAULT_INT:
            return printJSON ? device.lspciDictionary : [NSString stringWithFormat:@"%02lx:%02lx.%01lx %@ [%04lx]: %@ %@ [%04lx:%04lx]%@%@", [[device.bus objectAtIndex:0] integerValue], [[device.bus objectAtIndex:1] integerValue], [[device.bus objectAtIndex:2] integerValue], device.subClassString, device.pciClassCode.integerValue>>8, device.vendorString, device.deviceString, device.shadowVendor.integerValue, device.shadowDevice.integerValue, !device.revision.integerValue?@"":[NSString stringWithFormat:@" (rev %02lx)", device.revision.integerValue], !device.subDevice.integerValue?@"":[NSString stringWithFormat:@" (subsys %04lx:%04lx)", device.subVendor.integerValue, device.subDevice.integerValue]];
        case DT_LIST_PCI_ID_INT:
            return [NSString stringWithFormat:@"%04lx:%04lx", device.shadowVendor.integerValue, device.shadowDevice.integerValue];
    }
    return nil;
}

- (void) printAudioList {
    NSArray *audioDevices = [self listAudio];
    NSMutableArray *audioDeviceList = [NSMutableArray array];
    for(NSDictionary *audioDevice in audioDevices){
        [audioDeviceList addObject:[self getAudioDeviceInfo:dataType audioDevice:audioDevice]];
    }
    // Print
    if(printJSON) printf("%s\n", [audioDeviceList bv_jsonStringWithPrettyPrint:true].UTF8String);
    else printf("%s\n", [audioDeviceList componentsJoinedByString:@"\n"].UTF8String);
}

- (id) getAudioDeviceInfo: (unsigned) dataType audioDevice: (NSDictionary *)audioDevice {
    switch(dataType) {
        case DT_LIST_AUDIO_INT:
            return audioDevice;
        case DT_LIST_AUDIO_ID_INT:
            return [audioDevice valueForKey:@"DeviceID"];
        case DT_LIST_AUDIO_CODEC_ID_INT:
            return [audioDevice valueForKey:@"CodecID"];
        case DT_LIST_AUDIO_CODEC_ID_WITH_REVISION_INT:
            return [NSString stringWithFormat:@"%@:%@", [audioDevice valueForKey:@"CodecID"], [audioDevice valueForKey:@"Revision"]];
    }
    return nil;
}

- (NSArray *) listAudio {
    NSMutableArray *temp = [NSMutableArray array];
    io_iterator_t itThis;
    io_service_t service;
    io_service_t parent;
    io_name_t name;
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("VoodooHDADevice"), &itThis) == KERN_SUCCESS) {
        while((service = IOIteratorNext(itThis))) {
            IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent);
            IORegistryEntryGetName(parent, name);
            //if (!strcmp(name, "HDEF")){
            pciDevice *audio = [pciDevice create:parent];
            io_connect_t connect;
            if (IOServiceOpen(service, mach_task_self(), 0, &connect) == KERN_SUCCESS){
                mach_vm_address_t address;
                mach_vm_size_t size;
                if (IOConnectMapMemory64(connect, 0x2000, mach_task_self(), &address, &size, kIOMapAnywhere|kIOMapDefaultCache) == KERN_SUCCESS){
                    __block NSMutableArray *hda = [NSMutableArray array];
                    NSString *dump = [[NSString alloc] initWithBytes:(const void *)address length:size encoding:NSUTF8StringEncoding];
                    [[NSRegularExpression regularExpressionWithPattern:@"Codec ID: 0x([0-9a-f]{8})(?:\n.*){3}Revision: 0x([0-9a-f]{2})\n.*Stepping: 0x([0-9a-f]{2})" options:0 error:nil] enumerateMatchesInString:dump options:0 range:NSMakeRange(0, dump.length) usingBlock:^void(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop){
                        long codecid    = strHexDec([dump substringWithRange:[result rangeAtIndex:1]]),
                             revision   = strHexDec([dump substringWithRange:[result rangeAtIndex:2]]) << 8 | strHexDec([dump substringWithRange:[result rangeAtIndex:3]]);
                        NSString *CodecID = [self insertColonInID:codecid];
                        NSString *CodecName = nil;
                        for(int n = 0; gCodecList[n].name; n++)
                            if (HDA_DEV_MATCH(gCodecList[n].id, codecid) && revision >= gCodecList[n].rev) {
                                CodecName = [NSString stringWithUTF8String:gCodecList[n].name];
                                break;
                            }
                        if (CodecName == nil) CodecName = !codecid ? @"NULL Codec" : @"Unknown Codec";
                        [hda addObject:@{
                                @"DeviceID"     : [NSString stringWithFormat:kPCIFormat, audio.vendor.integerValue, audio.device.integerValue],
                                @"SubdeviceID"  : [NSString stringWithFormat:kPCIFormat, audio.subVendor.integerValue, audio.subDevice.integerValue],
                                @"CodecID"      : CodecID,
                                @"Revision"     : [NSString stringWithFormat:@"%04lX", revision],
                                @"Model"        : CodecName
                            }
                        ];
                    }];
                    [temp addObjectsFromArray:hda];
                    IOConnectUnmapMemory64(connect, 0x2000, mach_task_self(), address);
                }
                IOServiceClose(connect);
            }
            //}
            IOObjectRelease(parent);
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("AppleHDAController"), &itThis) == KERN_SUCCESS){
        while((service = IOIteratorNext(itThis))) {
            IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent);
            IORegistryEntryGetName(parent, name);
            //if (!strcmp(name, "HDEF")){
            io_service_t child;
            pciDevice *audio = [pciDevice create:parent];
            io_iterator_t itChild;
            if (IORegistryEntryGetChildIterator(service, kIOServicePlane, &itChild) == KERN_SUCCESS){
                while ((child = IOIteratorNext(itChild))){
                    long codecid    = [[pciDevice grabNumber:CFSTR("IOHDACodecVendorID") forService:child] longValue] & 0xFFFFFFFF,
                         revision   = [[pciDevice grabNumber:CFSTR("IOHDACodecRevisionID") forService:child] longValue] & 0xFFFF;
                    NSString *CodecID = [self insertColonInID:codecid];
//                    NSLog(@"%@", [pciDevice grabNumber:CFSTR("IOHDACodecVendorID") forService:child].stringValue);
                    NSString *CodecName = nil;
                    for(int n = 0; gCodecList[n].name; n++)
                        if (HDA_DEV_MATCH(gCodecList[n].id, codecid)) {
                            CodecName = [NSString stringWithUTF8String:gCodecList[n].name];
                            break;
                        }
                    if (CodecName == nil) CodecName = !codecid ? @"NULL Codec" : @"Unknown Codec";
                    [temp addObject:@{
                            @"DeviceID"     : [NSString stringWithFormat:kPCIFormat, audio.vendor.integerValue, audio.device.integerValue],
                            @"SubdeviceID"  : [NSString stringWithFormat:kPCIFormat, audio.subVendor.integerValue, audio.subDevice.integerValue],
                            @"CodecID"      : CodecID,
                            @"LayoutID"     : [pciDevice grabNumber:CFSTR("layout-id") forService:parent],
                            @"hda-gfx"      : [self removeNullChar:[pciDevice grabString:CFSTR("hda-gfx") forService:parent]],
                            @"Revision"     : [NSString stringWithFormat:@"%04lX", revision],
                            @"Model"        : CodecName
                        }
                    ];
                    IOObjectRelease(child);
                }
                IOObjectRelease(itChild);
            }
            //}
            IOObjectRelease(parent);
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    NSArray *filter = [temp valueForKey:@"DeviceID"];
    NSString *matchString;
    for(pciDevice *pci in [devices sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) { return [obj1 bdf] - [obj2 bdf]; }]) {
        matchString = [NSString stringWithFormat:kPCIFormat, pci.vendor.integerValue, pci.device.integerValue];
        if (pci.pciClassCode.integerValue == 0x40300 && ![filter containsObject:matchString]) {
            if ((service = IOServiceGetMatchingService(kIOMasterPortDefault, IORegistryEntryIDMatching(pci.entryID)))){
                io_connect_t connect;
                if (IOServiceOpen(service, mach_task_self(), 0, &connect) == KERN_SUCCESS){
                    //FIXME: Map Memory
                    IOServiceClose(connect);
                }
                else [temp addObject:@{
                        @"DeviceID"     : matchString,
                        @"SubdeviceID"  : [NSString stringWithFormat:kPCIFormat, pci.subVendor.integerValue, pci.subDevice.integerValue],
                        @"CodecID"      : @"",
                        @"Revision"     : @"",
                        @"Model"        : @""
                   }
                ];
                IOObjectRelease(service);
            }
        }
    }
    return [temp copy];
}

- (void) printGPUList {
    NSArray *GPUs = [self listGraphics];
    NSMutableArray *GPUList = [NSMutableArray array];
    for(NSDictionary *GPU in GPUs){
        [GPUList addObject:[self getGPUInfo:dataType GPU:GPU]];
    }
    // Print
    if(printJSON) printf("%s\n", [GPUList bv_jsonStringWithPrettyPrint:true].UTF8String);
    else printf("%s\n", [GPUList componentsJoinedByString:@"\n"].UTF8String);
}

- (id) getGPUInfo: (unsigned) dataType GPU: (NSDictionary *)GPU {
    switch(dataType) {
        case DT_LIST_GPU_INT:
            return GPU;
        case DT_LIST_GPU_ID_INT:
            return [GPU valueForKey:@"DeviceID"];
    }
    return nil;
}

- (NSArray *) listGraphics {
    NSMutableArray *temp = [NSMutableArray array];
    io_iterator_t itThis;
    io_service_t service;
    io_service_t parent;
    io_name_t name;
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("AtiFbStub"), &itThis) == KERN_SUCCESS) {
        NSMutableDictionary *card;
        int ports = 0;
        unsigned long long old;
        unsigned long long new;
        service = 1;
        while(service) {
            service = IOIteratorNext(itThis);
            if (!card && !service) break;
            IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent);
            IORegistryEntryGetRegistryEntryID(parent, &new);
            if (card && new!=old){
                [card setObject:@(ports) forKey:@"ports"];
                [temp addObject:[card copy]];
                card = nil;
                ports = 0;
            }
            if (!card && service) {
                IORegistryEntryGetRegistryEntryID(parent, &old);
                IORegistryEntryGetName(service, name);
                card = [@{
                          @"DeviceID"       : [NSString stringWithFormat:kPCIFormat, [pciDevice grabNumber:CFSTR("vendor-id") forService:parent].longValue,[pciDevice grabNumber:CFSTR("device-id") forService:parent].longValue],
                          @"SubdeviceID"    : [NSString stringWithFormat:kPCIFormat, [pciDevice grabNumber:CFSTR("subsystem-vendor-id") forService:parent].longValue,[pciDevice grabNumber:CFSTR("subsystem-id") forService:parent].longValue],
                          @"Revision"       : [NSString stringWithFormat:@"%04lX", [pciDevice grabNumber:CFSTR("revision-id") forService:parent].longValue],
                          @"Model"          : [pciDevice grabString:CFSTR("model") forService:parent],
                          // @"Ports"       : <port no>
                          @"ig-platform-id" : @(name),
                          @"hda-gfx"        : [self removeNullChar:[pciDevice grabString:CFSTR("hda-gfx") forService:parent]]
                      } mutableCopy];
            }
            ports++;
            IOObjectRelease(parent);
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IONDRVDevice"), &itThis) == KERN_SUCCESS){
        NSMutableDictionary *card;
        int ports = 0;
        unsigned long long old;
        unsigned long long new;
        service = 1;
        while(service) {
            service = IOIteratorNext(itThis);
            if (!card && !service) break;
            IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent);
            IORegistryEntryGetRegistryEntryID(parent, &new);
            if (card && new != old){
                [card setObject:@(ports) forKey:@"ports"];
                [temp addObject:[card copy]];
                card = nil;
                ports = 0;
            }
            if (!card && service) {
                io_service_t child;
                IORegistryEntryGetChildEntry(service, kIOServicePlane, &child);
                IORegistryEntryGetRegistryEntryID(parent, &old);
                IORegistryEntryGetName(child, name);
                card = [@{
                          @"DeviceID"       : [NSString stringWithFormat:kPCIFormat, [pciDevice grabNumber:CFSTR("vendor-id") forService:parent].longValue,[pciDevice grabNumber:CFSTR("device-id") forService:parent].longValue],
                          @"SubdeviceID"    : [NSString stringWithFormat:kPCIFormat, [pciDevice grabNumber:CFSTR("subsystem-vendor-id") forService:parent].longValue,[pciDevice grabNumber:CFSTR("subsystem-id") forService:parent].longValue],
                          @"Revision"       : [NSString stringWithFormat:@"%04lX", [pciDevice grabNumber:CFSTR("revision-id") forService:parent].longValue],
                          @"Model"          : [pciDevice grabString:CFSTR("model") forService:parent],
                          // @"Ports"       : <port no>
                          @"ig-platform-id" : @(name),
                          @"hda-gfx"        : [self removeNullChar:[pciDevice grabString:CFSTR("hda-gfx") forService:parent]]
                      } mutableCopy];
                IOObjectRelease(child);
            }
            ports++;
            IOObjectRelease(parent);
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("AppleIntelFramebuffer"), &itThis) == KERN_SUCCESS){
        NSMutableDictionary *card;
        int ports = 0;
        unsigned long long old;
        unsigned long long new;
        service = 1;
        while(service) {
            service = IOIteratorNext(itThis);
            if (!card && !service) break;
            IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent);
            IORegistryEntryGetRegistryEntryID(parent, &new);
            if (card && new!=old){
                [card setObject:@(ports) forKey:@"Ports"];
                [temp addObject:[card copy]];
                card = nil;
                ports = 0;
            }
            if (!card && service) {
                io_service_t child;
                IORegistryEntryGetChildEntry(parent, kIOServicePlane, &child);
                IORegistryEntryGetRegistryEntryID(parent, &old);
                NSUInteger framebuffer = [[pciDevice grabNumber:CFSTR("AAPL,ig-platform-id") forService:parent] longValue];
                if (framebuffer) sprintf(name, "0x%08lX", framebuffer);
                else IORegistryEntryGetName(child, name);
                card = [@{
                          @"DeviceID"       : [NSString stringWithFormat:kPCIFormat, [pciDevice grabNumber:CFSTR("vendor-id") forService:parent].longValue,[pciDevice grabNumber:CFSTR("device-id") forService:parent].longValue],
                          @"SubdeviceID"    : [NSString stringWithFormat:kPCIFormat, [pciDevice grabNumber:CFSTR("subsystem-vendor-id") forService:parent].longValue,[pciDevice grabNumber:CFSTR("subsystem-id") forService:parent].longValue],
                          @"Revision"       : [NSString stringWithFormat:@"%04lX", [pciDevice grabNumber:CFSTR("revision-id") forService:parent].longValue],
                          @"Model"          : [pciDevice grabString:CFSTR("model") forService:parent],
                          // @"Ports"       : <port no>
                          @"ig-platform-id" : @(name),
                          @"hda-gfx"        : [self removeNullChar:[pciDevice grabString:CFSTR("hda-gfx") forService:parent]]
                        } mutableCopy];
                IOObjectRelease(child);
            }
            ports++;
            IOObjectRelease(parent);
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    return [temp copy];
}

- (void) printNetworkList {
    NSArray *NetworkInterfaces = [self listNetwork];
    NSMutableArray *NetworkInterfaceList = [NSMutableArray array];
    for(NSDictionary *NetworkInterface in NetworkInterfaces){
        [NetworkInterfaceList addObject:[self getNetworkInfo:dataType NetworkInt:NetworkInterface]];
    }
    // Print
    if(printJSON) printf("%s\n", [NetworkInterfaceList bv_jsonStringWithPrettyPrint:true].UTF8String);
    else printf("%s\n", [NetworkInterfaceList componentsJoinedByString:@"\n"].UTF8String);
}

- (id) getNetworkInfo: (unsigned) dataType NetworkInt: (NSDictionary *)NetworkInt {
    switch(dataType) {
        case DT_LIST_NETWORK_INT:
            return NetworkInt;
        case DT_LIST_NETWORK_ID_INT:
            return [NetworkInt valueForKey:@"DeviceID"];
    }
    return nil;
}

- (NSArray *) listNetwork {
    NSMutableArray *temp = [NSMutableArray array];
    io_iterator_t itThis;
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IONetworkInterface"), &itThis) == KERN_SUCCESS) {
        io_service_t service;
        while((service = IOIteratorNext(itThis))){
            io_service_t parent;
            io_service_t device;
            IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent);
            IORegistryEntryGetParentEntry(parent, kIOServicePlane, &device);
            NSString *DeviceID;
            if (![pciDevice isPCI:device]) {
                // Not a PCI device
                io_service_t device2;
                IORegistryEntryGetParentEntry(device, kIOServicePlane, &device2);
                IOObjectRelease(device);
                device = 0;
                if (![pciDevice isPCI:device2]) IOObjectRelease(device2);
                else device = device2;
                DeviceID = [NSString stringWithFormat:kPCIFormat, [pciDevice grabNumber:CFSTR("idProduct") forService:parent].longValue, [pciDevice grabNumber:CFSTR("idVendor") forService:parent].longValue];
            } else {
                DeviceID = [self insertColonInStrID:[[pciDevice grabString:CFSTR("IOPCIMatch") forService:parent] substringFromIndex:2]];
            }
            NSString *model;
            io_name_t name;
            if (!(model = [pciDevice grabString:CFSTR("IOModel") forService:parent]).length) {
                IORegistryEntryGetName(parent, name);
                model = [NSString stringWithUTF8String:name];
            }
            IOObjectRelease(parent);
            IORegistryEntryGetName(service, name);//FIXME: better PCI detection
            [temp addObject:@{
                      @"Model"  : model,
                      @"BSD"    : @(name),
                      @"BuiltIn": [pciDevice grabNumber:CFSTR("IOBuiltin") forService:service],
                      @"DeviceID" : DeviceID
                }
            ];
            if (device) IOObjectRelease(device);
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    return [temp copy];
}

- (void) printConnectedList {
    NSArray *ConnectedDevices = [self listConnected];
    NSMutableArray *ConnectedDeviceList = [NSMutableArray array];
    for(NSDictionary *ConnectedDevice in ConnectedDevices){
        [ConnectedDeviceList addObject:[self getConnectedInfo:dataType Connected:ConnectedDevice]];
    }
    // Print
    if(printJSON) printf("%s\n", [ConnectedDeviceList bv_jsonStringWithPrettyPrint:true].UTF8String);
    else printf("%s\n", [ConnectedDeviceList componentsJoinedByString:@"\n"].UTF8String);
}

- (id) getConnectedInfo: (unsigned) dataType Connected: (NSDictionary *)Connected {
    switch(dataType) {
        case DT_LIST_CONNECTED_INT:
            return Connected;
        case DT_LIST_CONNECTED_ID_INT:
            return [Connected valueForKey:@"DeviceID"];
    }
    return nil;
}

- (NSArray *) listConnected {
    NSMutableArray *temp = [NSMutableArray array];
    io_iterator_t itThis;
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOUSBDevice"), &itThis) == KERN_SUCCESS) {
        io_service_t service;
        while((service = IOIteratorNext(itThis))){
            NSString *DeviceID;
            DeviceID = [NSString stringWithFormat:kPCIFormat, [pciDevice grabNumber:CFSTR("idProduct") forService:service].longValue, [pciDevice grabNumber:CFSTR("idVendor") forService:service].longValue];
            io_name_t name;
            IORegistryEntryGetName(service, name);
            [temp addObject:@{
                              @"ProductName"  : [pciDevice grabString:CFSTR("USB Product Name") forService:service],
                              @"VendorName"  : [pciDevice grabString:CFSTR("USB Vendor Name") forService:service],
                              @"Name"    : @(name),
                              @"BuiltIn": [pciDevice grabNumber:CFSTR("Built-In") forService:service],
                              @"DeviceID" : DeviceID,
                              @"PortNumber": [pciDevice grabNumber:CFSTR("PortNum") forService:service],
                              }
            ];
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    return [temp copy];
}


/**
 * Insert colon in device id to format it like this: `VendorID:DeviceID`
 *
 * @param int_id The given integer
 8 @return A string containing the desired format
 */
- (NSString *) insertColonInID: (long) int_id {
    NSMutableString *ID = [NSMutableString stringWithFormat:@"%08lX", int_id];
    [ID insertString:@":" atIndex:4];
    return [ID copy];
}

- (NSString *) insertColonInStrID: (NSString *) str_id {
    NSMutableString *ID = [NSMutableString stringWithString:str_id];
    [ID insertString:@":" atIndex:4];
    return [ID copy];
}

/**
 * Some "Data" fields have NULL character at the end, so have to remove it
 *
 * @param str The given string containing NULL character
 * @return A string without the NULL character
 */
- (NSString *) removeNullChar: (NSString *) str {
    return [str substringToIndex:[str length]-1];
}

@end
