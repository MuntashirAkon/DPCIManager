//
//  AppDelegate.m
//  DPCIManager
//
//  Created by PHPdev32 on 9/12/12.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "AppDelegate.h"
#define kDirectHWIdentifier @"com.coresystems.driver.DirectHW"
#define kOSBundleStarted @"OSBundleStarted"

@implementation AppDelegate
@synthesize panel;
@synthesize pop;
@synthesize file;
@synthesize patch;
@synthesize pciFormat;
@synthesize pcis;
@synthesize status;
@synthesize watcher;
@synthesize log;
@synthesize match;
@synthesize matches;

#pragma mark Class Methods
+(void)modalErrorWithDict:(NSDictionary *)err{//TODO: add chimera/chameleon validator?
    if (err != nil)
        [[NSAlert alertWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:[[err objectForKey:NSAppleScriptErrorNumber] integerValue] userInfo:@{NSLocalizedDescriptionKey:[err objectForKey:NSAppleScriptErrorMessage], NSLocalizedRecoverySuggestionErrorKey:[err objectForKey:NSAppleScriptErrorBriefMessage]}]] runModal];
}
+(void)modalError:(NSError *)err{
    if (err != nil)
        [[NSAlert alertWithError:err] runModal];
}
+(void)acpitables:(CFStringRef)only{
    io_service_t expert;
    if((expert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleACPIPlatformExpert")))){
        NSOpenPanel *open = [NSOpenPanel openPanel];
        [open setCanChooseDirectories:true];
        [open setCanChooseFiles:false];
        [open setPrompt:@"Choose a destination folder"];
        [open setCanCreateDirectories:true];
        if([open runModal] == NSFileHandlingPanelOKButton) {
            CFDictionaryRef tables = (CFDictionaryRef)IORegistryEntryCreateCFProperty(expert, CFSTR("ACPI Tables"), kCFAllocatorDefault, 0);
            CFDataRef table;
            if(only==nil){
                CFIndex count = CFDictionaryGetCount(tables);
                CFStringRef *keys = NSZoneCalloc(nil, count, sizeof(id));
                NSInteger i = 0;
                CFDictionaryGetKeysAndValues(tables, (const void **)keys, NULL);
                while(i<count) {
                    table = (CFDataRef)CFDictionaryGetValue(tables, keys[i]);
                    [[NSFileManager defaultManager] createFileAtPath:[NSString stringWithFormat:@"%@/%@.aml", [[[open URLs] objectAtIndex:0] path], keys[i++]] contents:(__bridge NSData *)table attributes:0];
                }
                NSZoneFree(nil, keys);
            }
            else {
                table = (CFDataRef)CFDictionaryGetValue(tables, only);
                [[NSFileManager defaultManager] createFileAtPath:[NSString stringWithFormat:@"%@/%@.aml", [[[open URLs] objectAtIndex:0] path], only] contents:(__bridge NSData *)table attributes:0];
            }
            CFRelease(tables);
        }
        IOObjectRelease(expert);
    }
}
+(bool)checkDirect{
    CFDictionaryRef dict = KextManagerCopyLoadedKextInfo((__bridge CFArrayRef)@[kDirectHWIdentifier], (__bridge CFArrayRef)@[kOSBundleStarted]);
    bool check = [[[(__bridge NSDictionary *)dict objectForKey:kDirectHWIdentifier] objectForKey:kOSBundleStarted] boolValue];
    CFRelease(dict);
    if (check) return true;
    [AScript loadKext:[[NSBundle mainBundle] pathForResource:@"DirectHW" ofType:@"kext"]];
    dict = KextManagerCopyLoadedKextInfo((__bridge CFArrayRef)@[kDirectHWIdentifier], (__bridge CFArrayRef)@[kOSBundleStarted]);
    check = [[[(__bridge NSDictionary *)dict objectForKey:kDirectHWIdentifier] objectForKey:kOSBundleStarted] boolValue];
    CFRelease(dict);
    return check;
}

#pragma mark ApplicationDelegate
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification{
    // Insert code here to initialize your application
    file = [[NSBundle mainBundle] pathForResource:@"pci" ofType:@"ids"];
    pciFormat = @"0x%04lX%04lX";
    [self willChangeValueForKey:@"patch"];
    patch = @"0x01000000";
    [self didChangeValueForKey:@"patch"];
    watcher = [NSTask create:@"/usr/bin/tail" args:@[@"-n", @"0", @"-f", @"/var/log/system.log"] callback:@selector(readLog:) listener:self];
    log = [NSMutableArray array];
    [self willChangeValueForKey:@"pcis"];
    pcis = [pciDevice readIDs];
    [self didChangeValueForKey:@"pcis"];
    [self willChangeValueForKey:@"status"];
    status = [self listDevices];
    [self didChangeValueForKey:@"status"];
    [watcher launch];
}
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender{
    return true;
}
-(void)applicationWillTerminate:(NSNotification *)notification{
    [watcher close];
}

#pragma mark PCI IDs
-(NSDictionary *)listDevices{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    io_iterator_t itThis;
    io_service_t service;
    io_service_t parent;
    io_name_t name;
    #pragma mark Graphics
    NSMutableArray *temp = [NSMutableArray array];
    if(IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("AtiFbStub"), &itThis) == KERN_SUCCESS) {
        NSMutableDictionary *card;
        int ports = 0;
        unsigned long long old;
        unsigned long long new;
        service = 1;
        while(service != 0) {
            service = IOIteratorNext(itThis);
            if(card==nil && service==0) break;
            IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent);
            IORegistryEntryGetRegistryEntryID(parent, &new);
            if(card!=nil && new!=old){
                [card setObject:@(ports) forKey:@"ports"];
                [temp addObject:[NSDictionary dictionaryWithDictionary:card]];
                card = nil;
                ports = 0;
            }
            if(card==nil && service!=0) {
                IORegistryEntryGetRegistryEntryID(parent, &old);
                CFDataRef model = IORegistryEntryCreateCFProperty(parent, CFSTR("model"), kCFAllocatorDefault, 0);
                IORegistryEntryGetName(service, name);
                card = [NSMutableDictionary dictionaryWithDictionary:@{@"model":(CFGetTypeID(model)==CFDataGetTypeID())?@((const char *)CFDataGetBytePtr(model)):(__bridge NSString*)(CFStringRef)model, @"framebuffer":@(name)}];
                CFRelease(model);
            }
            ports++;
            IOObjectRelease(parent);
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    if(IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IONDRVDevice"), &itThis) == KERN_SUCCESS){
        NSMutableDictionary *card;
        int ports = 0;
        unsigned long long old;
        unsigned long long new;
        service = 1;
        while(service != 0) {
            service = IOIteratorNext(itThis);
            if(card==nil && service==0) break;
            IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent);
            IORegistryEntryGetRegistryEntryID(parent, &new);
            if(card!=nil && new!=old){
                [card setObject:@(ports) forKey:@"ports"];
                [temp addObject:[NSDictionary dictionaryWithDictionary:card]];
                card = nil;
                ports = 0;
            }
            if(card==nil && service!=0) {
                io_service_t child;
                IORegistryEntryGetChildEntry(service, kIOServicePlane, &child);
                IORegistryEntryGetRegistryEntryID(parent, &old);
                CFDataRef model = (CFDataRef)IORegistryEntryCreateCFProperty(parent, CFSTR("model"), kCFAllocatorDefault, 0);
                IORegistryEntryGetName(child, name);
                card = [NSMutableDictionary dictionaryWithDictionary:@{@"model":(CFGetTypeID(model)==CFDataGetTypeID())?@((const char *)CFDataGetBytePtr(model)):(__bridge NSString*)(CFStringRef)model, @"framebuffer":@(name)}];
                CFRelease(model);
                IOObjectRelease(child);
            }
            ports++;
            IOObjectRelease(parent);
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    if(IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("AppleIntelFramebuffer"), &itThis) == KERN_SUCCESS){
        NSMutableDictionary *card;
        int ports = 0;
        unsigned long long old;
        unsigned long long new;
        service = 1;
        while(service != 0) {
            service = IOIteratorNext(itThis);
            if(card==nil && service==0) break;
            IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent);
            IORegistryEntryGetRegistryEntryID(parent, &new);
            if(card!=nil && new!=old){
                [card setObject:@(ports) forKey:@"ports"];
                [temp addObject:[NSDictionary dictionaryWithDictionary:card]];
                card = nil;
                ports = 0;
            }
            if(card==nil && service!=0) {
                io_service_t child;
                IORegistryEntryGetChildEntry(parent, kIOServicePlane, &child);
                IORegistryEntryGetRegistryEntryID(parent, &old);
                CFDataRef model = (CFDataRef)IORegistryEntryCreateCFProperty(parent, CFSTR("model"), kCFAllocatorDefault, 0);
                IORegistryEntryGetName(child, name);
                card = [NSMutableDictionary dictionaryWithDictionary:@{@"model":(CFGetTypeID(model)==CFDataGetTypeID())?@((const char *)CFDataGetBytePtr(model)):(__bridge NSString*)(CFStringRef)model, @"framebuffer":@(name)}];
                CFRelease(model);
                IOObjectRelease(child);
            }
            ports++;
            IOObjectRelease(parent);
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    [dict setObject:[NSArray arrayWithArray:temp] forKey:@"graphics"];
    #pragma mark Network
    temp = [NSMutableArray array];
    if(IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOEthernetInterface"), &itThis) == KERN_SUCCESS) {
        CFStringRef model;
        CFBooleanRef builtin;
        while((service = IOIteratorNext(itThis))){
            IORegistryEntryGetName(service, name);
            IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent);
            model = (CFStringRef)IORegistryEntryCreateCFProperty(parent, CFSTR("IOModel"), kCFAllocatorDefault, 0);
            if (model == nil) {
                IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent);
                IORegistryEntryGetName(parent, name);
                model = (__bridge CFStringRef)(@(name));
            }
            builtin = (CFBooleanRef)IORegistryEntryCreateCFProperty(service, CFSTR("IOBuiltin"), kCFAllocatorDefault, 0);
            [temp addObject:@{@"model":(__bridge NSString *)model,@"bsd":@(name),@"builtin":(__bridge NSNumber*)builtin}];
            CFRelease(model);
            CFRelease(builtin);
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    [dict setObject:[NSArray arrayWithArray:temp] forKey:@"network"];
    #pragma mark Audio
    temp = [NSMutableArray array];
    if(IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("VoodooHDADevice"), &itThis)==KERN_SUCCESS) {
        while((service = IOIteratorNext(itThis))) {
            IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent);
            IORegistryEntryGetName(parent, name);
            //if(strcmp(name, "HDEF")==0){
            pciDevice *audio = [pciDevice create:parent];
            io_connect_t connect;
            if(IOServiceOpen(service, mach_task_self(), 0, &connect)==KERN_SUCCESS){
                mach_vm_address_t address;
                mach_vm_size_t size;
                if(IOConnectMapMemory64(connect, 0x2000, mach_task_self(), &address, &size, kIOMapAnywhere|kIOMapDefaultCache)==KERN_SUCCESS){
                    __block NSMutableArray *hda = [NSMutableArray array];
                    NSString *dump = [[NSString alloc] initWithBytes:(const void *)address length:size encoding:NSUTF8StringEncoding];
                    [[NSRegularExpression regularExpressionWithPattern:@"Codec ID: 0x([0-9a-f]{8})" options:0 error:nil] enumerateMatchesInString:dump options:0 range:NSMakeRange(0, [dump length]) usingBlock:^void(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop){
                        long codecid = strtol([[dump substringWithRange:[result rangeAtIndex:1]] UTF8String], NULL, 16);
                        char *codecname = NULL;
                        for(int n = 0; gCodecList[n].name; n++)
                            if(HDA_DEV_MATCH(gCodecList[n].id, codecid)) { codecname = gCodecList[n].name; break; }
                        if(codecname==NULL) codecname = (codecid==0) ? "NULL Codec" : "Unknown Codec";
                        [hda addObject:@{@"device":[NSString stringWithFormat:pciFormat, [audio.vendor integerValue], [audio.device integerValue]], @"subdevice":[NSString stringWithFormat:pciFormat, [audio.subVendor integerValue], [audio.subDevice integerValue]], @"codecid":[NSString stringWithFormat:@"0x%08lX", codecid], @"model":[NSString stringWithUTF8String:codecname]}];
                    }];
                    temp = hda;
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
    if(IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("AppleHDAController"), &itThis)==KERN_SUCCESS){
        while((service = IOIteratorNext(itThis))) {
            IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent);
            IORegistryEntryGetName(parent, name);
            //if(strcmp(name, "HDEF")==0){
            io_service_t child;
            pciDevice *audio = [pciDevice create:parent];
            io_iterator_t itChild;
            if (IORegistryEntryGetChildIterator(service, kIOServicePlane, &itChild) == KERN_SUCCESS){
                while ((child = IOIteratorNext(itChild))){
                    long codecid;
                    char *codecname = NULL;
                    CFNumberRef codec = (CFNumberRef)IORegistryEntryCreateCFProperty(child, CFSTR("IOHDACodecVendorID"), kCFAllocatorDefault, 0);
                    CFNumberGetValue(codec, kCFNumberLongType, &codecid);
                    codecid &= 0x00000000FFFFFFFF;
                    CFRelease(codec);
                    for(int n = 0; gCodecList[n].name; n++)
                        if(HDA_DEV_MATCH(gCodecList[n].id, codecid)) { codecname = gCodecList[n].name; break; }
                    if(codecname==NULL) codecname = (codecid==0) ? "NULL Codec" : "Unknown Codec";
                    [temp addObject:@{@"device":[NSString stringWithFormat:pciFormat, [audio.vendor integerValue], [audio.device integerValue]], @"subdevice":[NSString stringWithFormat:pciFormat, [audio.subVendor integerValue], [audio.subDevice integerValue]], @"codecid":[NSString stringWithFormat:@"0x%08lX", codecid], @"model":[NSString stringWithUTF8String:codecname]}];
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
    for(pciDevice *pci in pcis) {
        matchString = [NSString stringWithFormat:pciFormat, [pci.vendor integerValue], [pci.device integerValue]];
        if ([pci.pciClassCode integerValue] == 0x40300 && ![filter containsObject:matchString]) {
            if((service = IOServiceGetMatchingService(kIOMasterPortDefault, CFDictionaryCreateCopy(kCFAllocatorDefault,(__bridge CFDictionaryRef)[pciDevice match:pci])))){
                io_connect_t connect;
                if(IOServiceOpen(service, mach_task_self(), 0, &connect)==KERN_SUCCESS){
                    //FIXME: Map Memory
                    IOServiceClose(connect);
                }
                else [temp addObject:@{@"device":matchString, @"subdevice":[NSString stringWithFormat:pciFormat, [pci.subVendor integerValue], [pci.subDevice integerValue]], @"codecid":@"", @"model":@""}];
                IOObjectRelease(service);
            }
        }
    }
    [dict setObject:[NSArray arrayWithArray:temp] forKey:@"audio"];
    #pragma mark Storage
    temp = [NSMutableArray array];
    if(IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOAHCIBlockStorageDevice"), &itThis) == KERN_SUCCESS) {
        CFDictionaryRef device;
        CFDictionaryRef protocol;
        while((service = IOIteratorNext(itThis))){
            device = (CFDictionaryRef)IORegistryEntryCreateCFProperty(service, CFSTR("Device Characteristics"), kCFAllocatorDefault, 0);
            protocol = (CFDictionaryRef)IORegistryEntryCreateCFProperty(service, CFSTR("Protocol Characteristics"), kCFAllocatorDefault, 0);
            [temp addObject:@{@"model":(__bridge NSString*)(CFStringRef)CFDictionaryGetValue(device, CFSTR("Product Name")), @"block":(__bridge NSNumber*)(CFNumberRef)CFDictionaryGetValue(device, CFSTR("Physical Block Size")), @"inter":(__bridge NSString*)(CFStringRef)CFDictionaryGetValue(protocol, CFSTR("Physical Interconnect")), @"loc":(__bridge NSString*)(CFStringRef)CFDictionaryGetValue(protocol, CFSTR("Physical Interconnect Location"))}];
            CFRelease(device);
            CFRelease(protocol);
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    if(IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOSCSIHierarchicalLogicalUnit"), &itThis) == KERN_SUCCESS) {
        CFDictionaryRef protocol;
        CFStringRef dev;
        CFStringRef ven;
        io_service_t child,child1,child2,child3;
        CFNumberRef block;
        while((service = IOIteratorNext(itThis))){
            protocol = (CFDictionaryRef)IORegistryEntryCreateCFProperty(service, CFSTR("Protocol Characteristics"), kCFAllocatorDefault, 0);
            ven = (CFStringRef)IORegistryEntryCreateCFProperty(service, CFSTR("Vendor Identification"), kCFAllocatorDefault, 0);
            dev = (CFStringRef)IORegistryEntryCreateCFProperty(service, CFSTR("Product Identification"), kCFAllocatorDefault, 0);
            IORegistryEntryGetChildEntry(service, kIOServicePlane, &child);
            IOObjectRelease(service);
            IORegistryEntryGetChildEntry(child, kIOServicePlane, &child1);
            IOObjectRelease(child);
            IORegistryEntryGetChildEntry(child1, kIOServicePlane, &child2);
            IOObjectRelease(child1);
            IORegistryEntryGetChildEntry(child2, kIOServicePlane, &child3);
            IOObjectRelease(child2);
            block = (CFNumberRef)IORegistryEntryCreateCFProperty(child3, CFSTR("Preferred Block Size"), kCFAllocatorDefault, 0);
            IOObjectRelease(child3);
            [temp addObject:@{@"model":[NSString stringWithFormat:@"%@ %@", (__bridge NSString*)ven, (__bridge NSString*)dev], @"block":(__bridge NSNumber*)block, @"inter":(__bridge NSString*)(CFStringRef)CFDictionaryGetValue(protocol, CFSTR("Physical Interconnect")), @"loc":(__bridge NSString*)(CFStringRef)CFDictionaryGetValue(protocol, CFSTR("Physical Interconnect Location"))}];
            CFRelease(block);
            CFRelease(dev);
            CFRelease(ven);
            CFRelease(protocol);
        }
        IOObjectRelease(itThis);
    }
    [dict setObject:[NSArray arrayWithArray:temp] forKey:@"storage"];
    return [NSDictionary dictionaryWithDictionary:dict];
}

#pragma mark NSToolbarDelegate
-(BOOL)validateToolbarItem:(NSToolbarItem *)theItem{
    return [theItem isEnabled];
}

#pragma mark GUI
-(IBAction)updateIDs:(id)sender{
    [sender setEnabled:false];
    if ([URLTask conditionalGet:[NSURL URLWithString:@"http://pci-ids.ucw.cz/pci.ids"] toFile:file]) {
        [sender setLabel:@"Found"];
        [NSTask launchedTaskWithLaunchPath:[[NSBundle mainBundle] executablePath] arguments:@[]];
        [NSApp terminate:self];
    }
    else
        [sender setLabel:@"None"];
}
-(IBAction)updateSeed:(id)sender{
    [sender setEnabled:false];
    if ([URLTask conditionalGet:[NSURL URLWithString:@"http://dpcimanager.sourceforge.net/seed.plist"] toFile:[[NSBundle mainBundle] pathForResource:@"seed" ofType:@"plist"]]) {
        [sender setLabel:@"Found"];
        [NSTask launchedTaskWithLaunchPath:[[NSBundle mainBundle] executablePath] arguments:@[]];
        [NSApp terminate:self];
    }
    else
        [sender setLabel:@"None"];
}
-(IBAction)submit:(id)sender{
    [sender setEnabled:false];
    NSMutableArray *pciids = [NSMutableArray array];
    for(pciDevice *dev in pcis)
        [pciids addObject:[NSString stringWithFormat:@"id[]=%04lX,%04lX,%04lX,%04lX,%06lX", dev.vendor.integerValue, dev.device.integerValue, dev.subVendor.integerValue, dev.subDevice.integerValue, dev.pciClassCode.integerValue]];
    NSString *postData = [pciids componentsJoinedByString:@"&"];
    NSMutableURLRequest *DPCIReceiver = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://dpcimanager.sourceforge.net/receiver"]];
    [DPCIReceiver setHTTPMethod:@"POST"];
    [DPCIReceiver addValue: @"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [DPCIReceiver setValue:[NSString stringWithFormat: @"%lu",[postData length]] forHTTPHeaderField:@"Content-Length"];
    [DPCIReceiver setHTTPBody: [postData dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:true]];
    [NSURLConnection sendAsynchronousRequest:DPCIReceiver queue:[NSOperationQueue currentQueue] completionHandler:^void(NSURLResponse *response, NSData *data, NSError *error){
        if (error == nil)
            [sender setLabel:([(NSHTTPURLResponse *)response statusCode]==200)?@"Success":@"Failed"];
        else
            [AppDelegate modalError:error];
    }];
}
-(IBAction)dumpTables:(id)sender{
    [AppDelegate acpitables:nil];
}
-(IBAction)dumpDsdt:(id)sender{
    [AppDelegate acpitables:CFSTR("DSDT")];
}
-(IBAction)fetchKext:(id)sender{
    io_service_t service;
    CFURLRef url = nil;
    pciDevice *dev = [pcis objectAtIndex:[(NSTableView *)sender selectedRow]];
    if((service = IOServiceGetMatchingService(kIOMasterPortDefault, CFDictionaryCreateCopy(kCFAllocatorDefault,(__bridge CFDictionaryRef)[pciDevice match:dev])))) {
        io_service_t child;
        if ([dev.pciClassCode integerValue] == 0x30000) {
            io_iterator_t itThis;
            if(IORegistryEntryGetChildIterator(service, kIOServicePlane, &itThis) == KERN_SUCCESS) {
                io_name_t name;
                char ending[9];
                while ((child = IOIteratorNext(itThis))) {
                    IORegistryEntryGetName(child, name);
                    strlcpy(ending, name+MAX(0, strlen(name)-8), MIN(strlen(name), 9));
                    if (strcmp(ending, "NVKernel") == 0 || strcmp(ending, "ntroller") == 0) {
                        CFStringRef bundle = (CFStringRef)IORegistryEntryCreateCFProperty(child, CFSTR("CFBundleIdentifier"), kCFAllocatorDefault, 0);
                        if (bundle != nil) {
                            url = KextManagerCreateURLForBundleIdentifier(kCFAllocatorDefault, bundle);
                            CFRelease(bundle);
                        }
                        IOObjectRelease(child);
                        break;
                    }
                    IOObjectRelease(child);
                }
                IOObjectRelease(itThis);
            }
        }
        else if (IORegistryEntryGetChildEntry(service, kIOServicePlane, &child) == KERN_SUCCESS){
            CFStringRef bundle = (CFStringRef)IORegistryEntryCreateCFProperty(child, CFSTR("CFBundleIdentifier"), kCFAllocatorDefault, 0);
            if(bundle != nil) {
                url = KextManagerCreateURLForBundleIdentifier(kCFAllocatorDefault, bundle);
                CFRelease(bundle);
            }
            IOObjectRelease(child);
        }
        if (url != nil) {
            [[NSWorkspace sharedWorkspace] selectFile:[(__bridge NSURL*)url path] inFileViewerRootedAtPath:[(__bridge NSURL*)url path]];
            CFRelease(url);
        }
        else {
            if (match == nil) match = [Match create];
            matches = [match match:dev];
            if ([matches count] > 0) {
                [self willChangeValueForKey:@"matches"];
                [pop showRelativeToRect:[sender rectOfRow:[sender selectedRow]] ofView:sender preferredEdge:NSMinXEdge];
                [self didChangeValueForKey:@"matches"];
                [[[[[[[[[pop contentViewController] view] subviews] objectAtIndex:0] subviews] objectAtIndex:0] subviews] objectAtIndex:0] expandItem:nil expandChildren:true];
            }
            else NSBeep();
        }
        IOObjectRelease(service);
    }
}
-(IBAction)patchNode:(id)sender{
    [self willChangeValueForKey:@"patch"];
    if ([sender tag] == 0)
        patch = [patch stringByReplacingCharactersInRange:NSMakeRange([sender tag]+2, 2) withString:[NSString stringWithFormat:@"%02lX", [[sender selectedItem] tag]]];
    else
        patch = [patch stringByReplacingCharactersInRange:NSMakeRange([sender tag]+3, 1) withString:[NSString stringWithFormat:@"%lX", [[sender selectedItem] tag]]];
    [self didChangeValueForKey:@"patch"];
}
-(IBAction)msrDumper:(id)sender{
    [sender setEnabled:false];
    [panel makeKeyAndOrderFront:sender];
    [AScript loadKext:[[NSBundle mainBundle] pathForResource:@"MSRDumper" ofType:@"kext"]];
    [sender setEnabled:true];
}
-(IBAction)repair:(id)sender{
    [sender setEnabled:false];
    [panel makeKeyAndOrderFront:sender];//FIXME: more efficient process
    [AScript adminExec:[NSString stringWithFormat:@"function log() { /usr/bin/syslog -s -k Sender 'Repair Permissions' -k Level 5 -k Message \\\"$1\\\"; };/bin/chmod -RN %@;log 'Finished chmod N';/usr/bin/find %@ -type d -print0 | /usr/bin/xargs -0 /bin/chmod 0755;log 'Finished chmod D';/usr/bin/find %@ -type f -print0 | /usr/bin/xargs -0 /bin/chmod 0644;log 'Finished chmod F';/usr/sbin/chown -R 0:0 %@;log 'Finished chown';/usr/bin/xattr -cr %@;log 'Finished xattr';log 'Finished repair'", kSLE, kSLE, kSLE, kSLE, kSLE]];
    [sender setEnabled:true];
}
-(IBAction)rebuild:(id)sender{
    [sender setEnabled:false];
    [panel makeKeyAndOrderFront:sender];
    [AScript adminExec:[NSString stringWithFormat:@"/usr/bin/touch %@", kSLE]];
    [sender setEnabled:true];
}
-(IBAction)install:(id)sender{
    NSOpenPanel *open = [NSOpenPanel openPanel];
    [open setAllowedFileTypes:@[@"kext"]];
    if ([open runModal] == NSFileHandlingPanelCancelButton) return;
    [sender setEnabled:false];
    [panel makeKeyAndOrderFront:sender];
    [AScript adminExec:[NSString stringWithFormat:@"/bin/cp -RX '%@' %@;/usr/bin/touch %@", [[[[open URLs] objectAtIndex:0] path] stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"], kSLE, kSLE]];
    [sender setEnabled:true];
}
-(IBAction)fetchCMOS:(id)sender{
    NSRange range = NSMakeRange(0, 128);
    unsigned char buff[range.length];
    io_service_t service;
    if ((service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleRTC")))) {
        io_connect_t connect;
        if(IOServiceOpen(service, mach_task_self(), 0x0101FACE, &connect)==KERN_SUCCESS){
            if(IOConnectCallMethod(connect, 0, (uint64_t *)&range.location, 1, NULL, 0, NULL, NULL, buff, &range.length) == KERN_SUCCESS){
                [NSData dataWithBytes:buff length:range.length];
            }
            IOServiceClose(connect);
        }
        IOObjectRelease(service);
    }
}
-(IBAction)readROM:(id)sender{
    if (![AppDelegate checkDirect]) return;
    NSSavePanel *save = [NSSavePanel savePanel];
    [save setAllowedFileTypes:@[@"rom"]];
    if([save runModal] == NSFileHandlingPanelOKButton) {
        [panel makeKeyAndOrderFront:sender];
        NSTask *task = [NSTask create:[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"flashrom"] args:@[@"-r", [[save URL] path], @"-p", @"internal"] callback:@selector(logTask:) listener:self];
        [task launchAndWait];
    }
}
-(IBAction)writeROM:(id)sender{
    if (![AppDelegate checkDirect]) return;
    NSOpenPanel *open = [NSOpenPanel openPanel];
    [open setAllowedFileTypes:@[@"rom"]];
    if([open runModal] == NSFileHandlingPanelOKButton) {
        [panel makeKeyAndOrderFront:sender];
        NSTask *task = [NSTask create:[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"flashrom"] args:@[@"-w", [[[open URLs] objectAtIndex:0] path], @"-p", @"internal"] callback:@selector(logTask:) listener:self];
        [task launchAndWait];
    }
}
-(IBAction)testROM:(id)sender{
    if (![AppDelegate checkDirect]) return;
        [panel makeKeyAndOrderFront:sender];
        NSTask *task = [NSTask create:[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"flashrom"] args:@[@"-p", @"internal"] callback:@selector(logTask:) listener:self];
        [task launchAndWait];
}

#pragma mark Logging
-(void)readLog:(NSData *)data{
    [self willChangeValueForKey:@"log"];
    for (NSString *line in [[NSString stringWithUTF8String:[data bytes]] componentsSeparatedByString:@"\n"]) {
        if ([line rangeOfString:@"MSRDumper"].location != NSNotFound || [line rangeOfString:@"kextd"].location != NSNotFound || [line rangeOfString:@"kextcache"].location != NSNotFound || [line rangeOfString:@"DirectHW"].location != NSNotFound || [line rangeOfString:@"Repair Permissions"].location != NSNotFound)
            [log insertObject:@{@"timestamp":[NSDate date],@"entry":[line substringFromIndex:[line rangeOfString:@" " options:0 range:NSMakeRange(16, [line length]-16)].location+1]} atIndex:0];
    }
    [self didChangeValueForKey:@"log"];
}
-(void)logTask:(NSData *)data{
    [self willChangeValueForKey:@"log"];
    for (NSString *line in [[NSString stringWithUTF8String:[data bytes]] componentsSeparatedByString:@"\n"]) {
        if ([line length] > 0)
        [log insertObject:@{@"timestamp":[NSDate date],@"entry":line} atIndex:0];
    }
    [self didChangeValueForKey:@"log"];
}
/*-(void)readPlist:(NSData *)data{
 NSDictionary *entry = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:nil];
 [self willChangeValueForKey:@"log"];
 [log insertObject:@{@"timestamp":[NSDate date],@"entry":([entry objectForKey:@"PercentComplete"] == nil)?[entry objectForKey:@"Status"]:[NSString stringWithFormat:@"Repair %@%% complete",[entry objectForKey:@"PercentComplete"]]} atIndex:0];
 if ([[entry objectForKey:@"End"] boolValue] == true) {
 [log insertObject:@{@"timestamp":[NSDate date],@"entry":@"Finished"} atIndex:0];
 [repair close];
 repair = nil;
 }
 [self didChangeValueForKey:@"log"];
 }*/
@end