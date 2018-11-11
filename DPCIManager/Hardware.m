//
//  Hardware.m
//  DPCIManager
//
//  Created by PHPdev32 on 3/29/13.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "Hardware.h"
#import "PCI.h"
#import "Task.h"
#import "Tables.h"
#import <IOKit/kext/KextManager.h>
#import <sys/sysctl.h>
#define kPCIFormat @"0x%04lX%04lX"
#define kOSBundleStarted @"OSBundleStarted"

@implementation AppDelegate (HardwareAdditions)

//TODO: add chimera/chameleon validator?
+(void)acpitables:(NSString *)only{//TODO: proc_kmsgbuf
    io_service_t expert;
    if ((expert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleACPIPlatformExpert")))){
        NSOpenPanel *open = DirectoryChooser();
        [open setTitle:@"Save ACPI Tables"];
        if ([open runModal] == NSFileHandlingPanelOKButton) {//TODO: detect injection?
            NSDictionary *tables = (__bridge_transfer NSDictionary *)IORegistryEntryCreateCFProperty(expert, CFSTR("ACPI Tables"), kCFAllocatorDefault, 0);
            if (!only)
                [[NSPropertyListSerialization dataWithPropertyList:@{@"Hostname":NSHost.currentHost.localizedName, @"Tables":tables} format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil] writeToFile:[NSString stringWithFormat:@"%@/%@.acpi", open.URL.path, NSHost.currentHost.localizedName] atomically:true];
            else
                [NSFileManager.defaultManager createFileAtPath:[NSString stringWithFormat:@"%@/%@.aml", open.URL.path, only] contents:[tables objectForKey:only] attributes:0];
        }
        IOObjectRelease(expert);
    }
}
+(NSURL *)findKext:(NSString *)bundle {
    return (__bridge_transfer NSURL *)KextManagerCreateURLForBundleIdentifier(kCFAllocatorDefault, (__bridge CFStringRef)bundle);
}
+(NSString *)bdmesg{
    io_service_t expert;
    NSString *bdmesg;
    if ((expert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice")))){
        bdmesg = [pciDevice grabString:CFSTR("boot-log") forService:expert];
        IOObjectRelease(expert);
    }
    if (!bdmesg.length && (expert = IORegistryEntryFromPath(kIOMasterPortDefault, "IODeviceTree:/efi/platform"))) {
        bdmesg = [pciDevice grabString:CFSTR("boot-log") forService:expert];
        IOObjectRelease(expert);
    }
    if (!bdmesg.length) bdmesg = @"Install a bootloader (Chimera, Clover, Chameleon) to enable boot-log";
    return bdmesg;
}
+(NSDictionary *)readHardware {
    NSArray *graphics = @[@{@"model":@"Unknown", @"framebuffer":@"Unknown", @"ports":@0}];
    NSArray *network = @[@{@"model":@"Unknown", @"bsd":@"nil", @"builtin":@(NO)}];
    NSArray *audio = @[@{@"device":@"0x00000000", @"subdevice":@"0x00000000", @"codecid":@"0x00000000", @"revision":@"0x0000", @"model":@"Unknown"}];
    NSArray *storage = @[@{@"model":@"Unknown", @"block":@"0", @"inter":@"Unknown", @"loc":@"Unknown"}];
    @try {graphics = [self listGraphics];} @catch (NSException *ex) {}
    @try {network = [self listNetwork];} @catch (NSException *ex) {}
    @try {audio = [self listAudio];} @catch (NSException *ex) {}
    @try {storage = [self listStorage];} @catch (NSException *ex) {}
    return @{@"graphics":graphics, @"audio":audio, @"network":network, @"storage":storage};
}

#pragma mark PCI IDs
+(NSArray *)listGraphics{
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
                card = [@{@"device":[pciDevice create:parent], @"model":[pciDevice grabString:CFSTR("model") forService:parent], @"framebuffer":@(name)} mutableCopy];
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
            if (card && new!=old){
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
                card = [@{@"device":[pciDevice create:parent], @"model":[pciDevice grabString:CFSTR("model") forService:parent], @"framebuffer":@(name)} mutableCopy];
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
                [card setObject:@(ports) forKey:@"ports"];
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
                card = [@{@"device":[pciDevice create:parent], @"model":[pciDevice grabString:CFSTR("model") forService:parent], @"framebuffer":@(name)} mutableCopy];
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
+(NSArray *)listNetwork{
    NSMutableArray *temp = [NSMutableArray array];
    io_iterator_t itThis;
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IONetworkInterface"), &itThis) == KERN_SUCCESS) {
        io_service_t service;
        while((service = IOIteratorNext(itThis))){
            io_service_t parent;
            io_service_t device;
            IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent);
            IORegistryEntryGetParentEntry(parent, kIOServicePlane, &device);
            if (![pciDevice isPCI:device]) {
                io_service_t device2;
                IORegistryEntryGetParentEntry(device, kIOServicePlane, &device2);
                IOObjectRelease(device);
                device = 0;
                if (![pciDevice isPCI:device2]) IOObjectRelease(device2);
                else device = device2;
            }
            NSString *model;
            io_name_t name;
            if (!(model = [pciDevice grabString:CFSTR("IOModel") forService:parent]).length) {
                IORegistryEntryGetName(parent, name);
                model = [NSString stringWithUTF8String:name];
            }
            IOObjectRelease(parent);
            IORegistryEntryGetName(service, name);//FIXME: better PCI detection
            [temp addObject:@{@"model":model, @"bsd":@(name), @"builtin":[pciDevice grabNumber:CFSTR("IOBuiltin") forService:service], @"device":device?[pciDevice create:device]:[NSNull null]}];
            if (device) IOObjectRelease(device);
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    return [temp copy];
}
+(NSArray *)listAudio{
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
                        long codecid = strHexDec([dump substringWithRange:[result rangeAtIndex:1]]), revision = strHexDec([dump substringWithRange:[result rangeAtIndex:2]]) << 8 | strHexDec([dump substringWithRange:[result rangeAtIndex:3]]);
                        char *codecname = NULL;
                        for(int n = 0; gCodecList[n].name; n++)
                            if (HDA_DEV_MATCH(gCodecList[n].id, codecid) && revision >= gCodecList[n].rev) { codecname = gCodecList[n].name; break; }
                        if (codecname == NULL) codecname = !codecid ? "NULL Codec" : "Unknown Codec";
                        [hda addObject:@{@"device":[NSString stringWithFormat:kPCIFormat, audio.vendor.integerValue, audio.device.integerValue], @"subdevice":[NSString stringWithFormat:kPCIFormat, audio.subVendor.integerValue, audio.subDevice.integerValue], @"codecid":[NSString stringWithFormat:@"0x%08lX", codecid], @"revision":[NSString stringWithFormat:@"0x%04lX", revision], @"model":[NSString stringWithUTF8String:codecname]}];
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
                    long codecid = [[pciDevice grabNumber:CFSTR("IOHDACodecVendorID") forService:child] longValue] & 0xFFFFFFFF, revision = [[pciDevice grabNumber:CFSTR("IOHDACodecRevisionID") forService:child] longValue] & 0xFFFF;
                    char *codecname = NULL;
                    for(int n = 0; gCodecList[n].name; n++)
                        if (HDA_DEV_MATCH(gCodecList[n].id, codecid)) { codecname = gCodecList[n].name; break; }
                    if (codecname == NULL) codecname = !codecid ? "NULL Codec" : "Unknown Codec";
                    [temp addObject:@{@"device":[NSString stringWithFormat:kPCIFormat, audio.vendor.integerValue, audio.device.integerValue], @"subdevice":[NSString stringWithFormat:kPCIFormat, audio.subVendor.integerValue, audio.subDevice.integerValue], @"codecid":[NSString stringWithFormat:@"0x%08lX", codecid], @"revision":[NSString stringWithFormat:@"0x%04lX", revision], @"model":[NSString stringWithUTF8String:codecname]}];
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
    NSArray *filter = [temp valueForKey:@"device"];
    NSString *matchString;
    for(pciDevice *pci in [(AppDelegate *)[NSApp delegate] pcis]) {
        matchString = [NSString stringWithFormat:kPCIFormat, pci.vendor.integerValue, pci.device.integerValue];
        if (pci.pciClassCode.integerValue == 0x40300 && ![filter containsObject:matchString]) {
            if ((service = IOServiceGetMatchingService(kIOMasterPortDefault, IORegistryEntryIDMatching(pci.entryID)))){
                io_connect_t connect;
                if (IOServiceOpen(service, mach_task_self(), 0, &connect) == KERN_SUCCESS){
                    //FIXME: Map Memory
                    IOServiceClose(connect);
                }
                else [temp addObject:@{@"device":matchString, @"subdevice":[NSString stringWithFormat:kPCIFormat, pci.subVendor.integerValue, pci.subDevice.integerValue], @"codecid":@"", @"revision":@"", @"model":@""}];
                IOObjectRelease(service);
            }
        }
    }
    return [temp copy];
}
+(NSArray *)listStorage{
    NSMutableArray *temp = [NSMutableArray array];
    io_iterator_t itThis;
    io_service_t service;
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOAHCIBlockStorageDevice"), &itThis) == KERN_SUCCESS) {
        while((service = IOIteratorNext(itThis))){
            NSDictionary *protocol = (__bridge_transfer NSDictionary *)IORegistryEntryCreateCFProperty(service, CFSTR("Protocol Characteristics"), kCFAllocatorDefault, 0), *device = (__bridge_transfer NSDictionary *)IORegistryEntryCreateCFProperty(service,CFSTR("Device Characteristics"), kCFAllocatorDefault, 0);
            [temp addObject:@{@"model":[device objectForKey:@"Product Name"]?:@"", @"block":[device objectForKey:@"Physical Block Size"]?:@0, @"inter":[protocol objectForKey:@"Physical Interconnect"]?:@"", @"loc":[protocol objectForKey:@"Physical Interconnect Location"]?:@""}];
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOSCSIHierarchicalLogicalUnit"), &itThis) == KERN_SUCCESS) {
        io_service_t child, child1, child2, child3;
        while((service = IOIteratorNext(itThis))){
            NSDictionary *protocol = (__bridge_transfer NSDictionary *)IORegistryEntryCreateCFProperty(service, CFSTR("Protocol Characteristics"), kCFAllocatorDefault, 0);
            NSString *vendor = [pciDevice grabString:CFSTR("Vendor Identification") forService:service], *device = [pciDevice grabString:CFSTR("Product Identification") forService:service];
            IORegistryEntryGetChildEntry(service, kIOServicePlane, &child);
            IOObjectRelease(service);
            IORegistryEntryGetChildEntry(child, kIOServicePlane, &child1);
            IOObjectRelease(child);
            IORegistryEntryGetChildEntry(child1, kIOServicePlane, &child2);
            IOObjectRelease(child1);
            IORegistryEntryGetChildEntry(child2, kIOServicePlane, &child3);
            IOObjectRelease(child2);
            [temp addObject:@{@"model":[NSString stringWithFormat:@"%@ %@", vendor, device], @"block":[pciDevice grabNumber:CFSTR("Preferred Block Size") forService:child3], @"inter":[protocol objectForKey:@"Physical Interconnect"]?:@"", @"loc":[protocol objectForKey:@"Physical Interconnect Location"]?:@""}];
            IOObjectRelease(child3);
        }
        IOObjectRelease(itThis);
    }
    return [temp copy];
}

static NSRegularExpression *macregex;
static NSRegularExpression *optest;

+(void)initialize {
    macregex = [NSRegularExpression regularExpressionWithPattern:@"[A-F0-9]{2}:[A-F0-9]{2}:[A-F0-9]{2}:[A-F0-9]{2}:[A-F0-9]{2}:[A-F0-9]{2}" options:0 error:nil];
    optest = [NSRegularExpression regularExpressionWithPattern:@"UNTESTED for operations: ([A-Z ]+)\\n" options:0 error:nil];
}

#pragma mark Logging
-(void)logReport:(NSData *)data{
    if (!self.flashout) self.flashout = [NSMutableData data];
    [self.flashout appendData:data];
    [self logTask:data];
}

@end
