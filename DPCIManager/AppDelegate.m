//
//  AppDelegate.m
//  DPCIManager
//
//  Created by PHPdev32 on 9/12/12.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "AppDelegate.h"

@implementation AppDelegate
@synthesize submitButton;
@synthesize file;
@synthesize pciFormat;
@synthesize pcis;
@synthesize status;
@synthesize vendors;
@synthesize classes;

#pragma mark ApplicationDelegate
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification{
    // Insert code here to initialize your application
    file = [[NSBundle mainBundle] pathForResource:@"pci" ofType:@"ids"];
    pciFormat = @"0x%04lX%04lX";
    pcis = [NSMutableArray array];
    status = [NSMutableDictionary dictionary];
    classes = [NSMutableDictionary dictionary];
    vendors = [NSMutableDictionary dictionary];
    [self readIDs];
    [self listDevices];
    self.pcis = pcis;
    self.status = status;
}
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender{
    return true;
}

#pragma mark PCI IDs
-(void)readIDs{
    FILE *handle = fopen([file fileSystemRepresentation],"rb");
    NSNumber *currentClass;
    NSNumber *currentVendor;
    char buffer[256];
	long device_id, subclass_id;
	char *buf;
	bool class_parse = false;
	while(fgets(buffer, 256, handle)) {
        if (buffer[0]=='#') continue;
		if (strlen(buffer) <= 4) continue;
        buffer[strlen(buffer)-1]='\0';
        buf = buffer;
        if (*buf == 'C') class_parse = true;
        if (class_parse) {
            if (*buf == 0x09) {
                buf++;
                if (*buf != 0x09) {
                    subclass_id = strtol(buf, NULL, 16);
                    buf += 4;
                    while (*buf == ' ' || *buf == 0x09) buf++;
                    [[[classes objectForKey:currentClass] subClasses] setObject:@(buf) forKey:@(subclass_id)];
                }
            }
            else if (*buf == 'C') {
                buf += 2;
                currentClass = @(strtol(buf, NULL, 16));
                buf += 4;
                while (*buf == ' ' || *buf == 0x09) buf++;
                [classes setObject:[pciClass create:@(buf)] forKey:currentClass];
            }
        }
        else {
            if (*buf == 0x09) {
                buf++;
                if (*buf != 0x09) {
                    device_id = strtol(buf, NULL, 16);
                    buf += 4;
                    while (*buf == ' ' || *buf == 0x09) buf++;
                    [[[vendors objectForKey:currentVendor] devices] setObject:@(buf) forKey:@(device_id)];
                }
            }
            else if (*buf != '\\') {
                currentVendor = @(strtol(buf, NULL, 16));
                buf += 4;
                while (*buf == ' ' || *buf == 0x09) buf++;
                [vendors setObject:[pciVendor create:@(buf)] forKey:currentVendor];
            }
        }
	}
    fclose(handle);
    io_iterator_t itThis;
    if(IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOPCIDevice"), &itThis) == KERN_SUCCESS) {
        io_service_t service;
        while((service = IOIteratorNext(itThis))){
            [pcis addObject:[pciDevice create:service]];
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    classes = [NSMutableDictionary dictionary];
    vendors = [NSMutableDictionary dictionary];
}
-(void)listDevices{
    io_iterator_t itThis;
    io_service_t service;
    io_service_t parent;
    io_name_t name;
    #pragma mark Graphics
    [status setObject:[NSMutableArray array] forKey:@"graphics"];
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
                [[status objectForKey:@"graphics"] addObject:card];
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
                [[status objectForKey:@"graphics"] addObject:card];
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
    #pragma mark Network
    [status setObject:[NSMutableArray array] forKey:@"network"];
    if(IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOEthernetInterface"), &itThis) == KERN_SUCCESS) {
        CFStringRef model;
        CFBooleanRef builtin;
        while((service = IOIteratorNext(itThis))){
            IORegistryEntryGetName(service, name);
            IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent);
            model = (CFStringRef)IORegistryEntryCreateCFProperty(parent, CFSTR("IOModel"), kCFAllocatorDefault, 0);
            builtin = (CFBooleanRef)IORegistryEntryCreateCFProperty(service, CFSTR("IOBuiltin"), kCFAllocatorDefault, 0);
            [[status objectForKey:@"network"] addObject:@{@"model":(__bridge NSString *)model,@"bsd":@(name),@"builtin":(__bridge NSNumber*)builtin}];
            CFRelease(model);
            CFRelease(builtin);
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    #pragma mark Audio
    [status setObject:[NSMutableArray array] forKey:@"audio"];
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
                    long codecid;
                    char *codecname = NULL;
                    codecid = CODEC_ID(strtol(strstr((char *)address,"Vendor: ")+8, NULL, 16),strtol(strstr((char *)address,"Device: ")+8, NULL, 16));
                    for(int n = 0; gCodecList[n].name; n++)
                        if(HDA_DEV_MATCH(gCodecList[n].id, codecid)) { codecname = gCodecList[n].name; break; }
                    if(codecname==NULL) codecname = (codecid==0) ? "NULL Codec" : "Unknown Codec";
                    [[status objectForKey:@"audio"] addObject:@{@"device":[NSString stringWithFormat:pciFormat, [audio.vendor integerValue], [audio.device integerValue]], @"subdevice":[NSString stringWithFormat:pciFormat, [audio.subVendor integerValue], [audio.subDevice integerValue]], @"codecid":[NSString stringWithFormat:@"0x%08lX", codecid], @"model":[NSString stringWithUTF8String:codecname]}];
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
            if(IORegistryEntryGetChildEntry(service, kIOServicePlane, &child) == KERN_SUCCESS){
                long codecid;
                char *codecname = NULL;
                CFNumberRef codec = (CFNumberRef)IORegistryEntryCreateCFProperty(child, CFSTR("IOHDACodecVendorID"), kCFAllocatorDefault, 0);
                CFNumberGetValue(codec, kCFNumberLongType, &codecid);
                CFRelease(codec);
                for(int n = 0; gCodecList[n].name; n++)
                    if(HDA_DEV_MATCH(gCodecList[n].id, codecid)) { codecname = gCodecList[n].name; break; }
                if(codecname==NULL) codecname = (codecid==0) ? "NULL Codec" : "Unknown Codec";
                [[status objectForKey:@"audio"] addObject:@{@"device":[NSString stringWithFormat:pciFormat, [audio.vendor integerValue], [audio.device integerValue]], @"subdevice":[NSString stringWithFormat:pciFormat, [audio.subVendor integerValue], [audio.subDevice integerValue]], @"codecid":[NSString stringWithFormat:@"0x%08lX", codecid], @"model":[NSString stringWithUTF8String:codecname]}];
                IOObjectRelease(child);
            }
            //}
            IOObjectRelease(parent);
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    NSArray *filter = [[status objectForKey:@"audio"] valueForKey:@"device"];
    NSString *matchString;
    for(pciDevice *pci in pcis) {
        matchString = [NSString stringWithFormat:pciFormat, [pci.vendor integerValue], [pci.device integerValue]];
        if ([pci.pciClassCode integerValue] == 0x40300 && ![filter containsObject:matchString]) {
            if((service = IOServiceGetMatchingService(kIOMasterPortDefault, CFDictionaryCreateCopy(kCFAllocatorDefault,(__bridge CFDictionaryRef)[pciDevice match:pci])))){
                io_connect_t connect;
                if(IOServiceOpen(service, mach_task_self(), 0, &connect)==KERN_SUCCESS){
                    //TODO: Map Memory
                    IOServiceClose(connect);
                }
                else [[status objectForKey:@"audio"] addObject:@{@"device":matchString, @"subdevice":[NSString stringWithFormat:pciFormat, [pci.subVendor integerValue], [pci.subDevice integerValue]], @"codecid":@"", @"model":@""}];
                IOObjectRelease(service);
            }
        }
    }
    #pragma mark Storage
    [status setObject:[NSMutableArray array] forKey:@"storage"];
    if(IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOAHCIBlockStorageDevice"), &itThis) == KERN_SUCCESS) {
        CFDictionaryRef device;
        CFDictionaryRef protocol;
        while((service = IOIteratorNext(itThis))){
            device = (CFDictionaryRef)IORegistryEntryCreateCFProperty(service, CFSTR("Device Characteristics"), kCFAllocatorDefault, 0);
            protocol = (CFDictionaryRef)IORegistryEntryCreateCFProperty(service, CFSTR("Protocol Characteristics"), kCFAllocatorDefault, 0);
            [[status objectForKey:@"storage"] addObject:@{@"model":(__bridge NSString*)(CFStringRef)CFDictionaryGetValue(device, CFSTR("Product Name")), @"block":(__bridge NSNumber*)(CFNumberRef)CFDictionaryGetValue(device, CFSTR("Physical Block Size")), @"inter":(__bridge NSString*)(CFStringRef)CFDictionaryGetValue(protocol, CFSTR("Physical Interconnect")), @"loc":(__bridge NSString*)(CFStringRef)CFDictionaryGetValue(protocol, CFSTR("Physical Interconnect Location"))}];
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
            [[status objectForKey:@"storage"] addObject:@{@"model":[NSString stringWithFormat:@"%@ %@", (__bridge NSString*)ven, (__bridge NSString*)dev], @"block":(__bridge NSNumber*)block, @"inter":(__bridge NSString*)(CFStringRef)CFDictionaryGetValue(protocol, CFSTR("Physical Interconnect")), @"loc":(__bridge NSString*)(CFStringRef)CFDictionaryGetValue(protocol, CFSTR("Physical Interconnect Location"))}];
            CFRelease(block);
            CFRelease(dev);
            CFRelease(ven);
            CFRelease(protocol);
        }
        IOObjectRelease(itThis);
    }
}
-(void)acpitables:(CFStringRef)only{
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

#pragma mark NSToolbarDelegate
-(BOOL)validateToolbarItem:(NSToolbarItem *)theItem{
    return [theItem isEnabled];
}

#pragma mark NSConnectionDelegate
-(void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
    [submitButton setLabel:([(NSHTTPURLResponse *)response statusCode]==200)?@"Success":@"Failed"];
}
-(NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse{
    return nil;
}
-(NSURLRequest *) connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response{
    return request;
}

#pragma mark GUI
-(IBAction)update:(id)sender{
    [sender setEnabled:false];
    NSURL *url = [NSURL URLWithString:@"http://pci-ids.ucw.cz/pci.ids"];
    NSDate *filemtime = [[[NSFileManager defaultManager] attributesOfItemAtPath:file error:nil] fileModificationDate];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"HEAD"];
    NSHTTPURLResponse *response;
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
    NSString *urlmstr = nil;
    if ([response respondsToSelector:@selector(allHeaderFields)])
        urlmstr = [[response allHeaderFields] objectForKey:@"Last-Modified"];
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'";
    df.locale = [[NSLocale new] initWithLocaleIdentifier:@"en_US"];
    df.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
    NSDate *urlmtime = [df dateFromString:urlmstr];
    if ([filemtime laterDate:urlmtime] == urlmtime){
        [sender setLabel:@"Found"];
        NSData *data = [NSData dataWithContentsOfURL:url];
        [data writeToFile:file atomically:true];
        [[NSFileManager defaultManager] setAttributes:@{NSFileModificationDate: urlmtime} ofItemAtPath:file error:nil];
        [NSTask launchedTaskWithLaunchPath:[[NSBundle mainBundle] executablePath] arguments:@[]];
        [NSApp terminate:self];
    }
    else {
        [[NSFileManager defaultManager] setAttributes:@{NSFileModificationDate: urlmtime} ofItemAtPath:file error:nil];
        [sender setLabel:@"None"];
    }
}
-(IBAction)submit:(id)sender{
    [sender setEnabled:false];
    NSMutableArray *pciids = [NSMutableArray array];
    for(pciDevice *dev in pcis)
        [pciids addObject:[NSString stringWithFormat:@"id[]=%04lX,%04lX,%04lX,%04lX,%06lX", dev.vendor.integerValue, dev.device.integerValue, dev.subVendor.integerValue, dev.subDevice.integerValue, dev.pciClassCode.integerValue]];
    NSString *postData = [pciids componentsJoinedByString:@"&"];
    NSURL *url = [NSURL URLWithString:@"http://dpcimanager.sourceforge.net/receiver"];
    NSMutableURLRequest *DPCIReceiver = [NSMutableURLRequest requestWithURL:url];
    [DPCIReceiver setHTTPMethod:@"POST"];
    [DPCIReceiver addValue: @"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [DPCIReceiver setValue:[NSString stringWithFormat: @"%lu",[postData length]] forHTTPHeaderField:@"Content-Length"];
    [DPCIReceiver setHTTPBody: [postData dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:true]];
    [NSURLConnection connectionWithRequest:DPCIReceiver delegate:self];
}
-(IBAction)dumpTables:(id)sender{
    [self acpitables:nil];
}
-(IBAction)dumpDsdt:(id)sender{
    [self acpitables:CFSTR("DSDT")];
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
                    if (strcmp(ending, "NVKernel") == 0 || strcmp(ending, "ntroller") == 0) {//TODO: Intel
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
        else NSBeep();
        IOObjectRelease(service);
    }
}
@end

#pragma mark Device Class
@implementation pciDevice

@synthesize vendor;
@synthesize device;
@synthesize subVendor;
@synthesize subDevice;
@synthesize pciClassCode;
@synthesize pciClass;
@synthesize pciSubClass;
@synthesize vendorString;
@synthesize deviceString;
@synthesize classString;
@synthesize subClassString;

+(NSNumber *)grabEntry:(CFStringRef)entry forService:(io_service_t)service{
    CFTypeRef data = IORegistryEntryCreateCFProperty(service,entry,kCFAllocatorDefault,0);
    if(data==NULL) return @0;
    else{
        NSNumber *temp = @(*(NSInteger *)CFDataGetBytePtr(data));
        CFRelease(data);
        return temp;
    }
}
+(NSDictionary *)match:(pciDevice *)pci{
    NSInteger vendor = [[pci vendor] integerValue];
    NSInteger device = [[pci device] integerValue];
    return @{@kIOPropertyMatchKey:@{@"vendor-id":[NSData dataWithBytes:&vendor length:4], @"device-id":[NSData dataWithBytes:&device length:4]}};
}
+(pciDevice *)create:(io_service_t)service{
    pciDevice *temp = [pciDevice new];
    temp.vendor = [self grabEntry:CFSTR("vendor-id") forService:service];
    temp.vendorString = [[[[NSApp delegate] vendors] objectForKey:temp.vendor] name];
    temp.device = [self grabEntry:CFSTR("device-id") forService:service];
    temp.deviceString = [[[[[NSApp delegate] vendors] objectForKey:temp.vendor] devices] objectForKey:temp.device];
    temp.subVendor = [self grabEntry:CFSTR("subsystem-vendor-id") forService:service];
    temp.subDevice = [self grabEntry:CFSTR("subsystem-id") forService:service];
    temp.pciClassCode = [self grabEntry:CFSTR("class-code") forService:service];
    temp.pciClass = @(([temp.pciClassCode integerValue] >> 16) &0xFF);
    temp.classString = [[[[NSApp delegate] classes] objectForKey:temp.pciClass] name];
    temp.pciSubClass = @(([temp.pciClassCode integerValue] >>8) &0xFF);
    temp.subClassString = [[[[[NSApp delegate] classes] objectForKey:temp.pciClass] subClasses] objectForKey:temp.pciSubClass];
    return temp;
}
-(NSString *)fullClassString{
    return [NSString stringWithFormat:@"%@, %@", [self classString], [self subClassString]];
}
@end

#pragma mark ID Classes
@implementation pciVendor
@synthesize name;
@synthesize devices;
+(pciVendor *)create:(NSString *)name{
    pciVendor *temp = [pciVendor new];
    temp.name = name;
    temp.devices = [NSMutableDictionary dictionary];
    return temp;
}
@end

@implementation pciClass
@synthesize name;
@synthesize subClasses;
+(pciClass *)create:(NSString *)name{
    pciClass *temp = [pciClass new];
    temp.name = name;
    temp.subClasses = [NSMutableDictionary dictionary];
    return temp;
}
@end

#pragma mark Formatter
@implementation hexFormatter
+(BOOL)allowsReverseTransformation{
    return false;
}
+(Class)transformedValueClass{
    return [NSString class];
}
-(id)transformedValue:(id)value{
    return [NSString stringWithFormat:@"%04lX",[(NSNumber *)value integerValue]];
}
@end
