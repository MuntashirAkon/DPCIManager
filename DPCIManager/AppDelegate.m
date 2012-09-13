//
//  AppDelegate.m
//  DPCIManager
//
//  Created by PHPdev32 on 9/12/12.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "AppDelegate.h"

@implementation AppDelegate
@synthesize window;
@synthesize submitButton;
@synthesize file;
@synthesize pcis;
@synthesize vendors;
@synthesize classes;

#pragma mark ApplicationDelegate
-(void)awakeFromNib{
    file = [[NSBundle mainBundle] pathForResource:@"pci" ofType:@"ids"];
    [self readIDs];
    [self listDevices];
}
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification{
    // Insert code here to initialize your application
}
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender{
    return true;
}

#pragma mark PCI IDs
-(void)readIDs{
    FILE *handle = fopen([file UTF8String],"rb");
    NSMutableDictionary *class = [NSMutableDictionary dictionary];
    NSMutableDictionary *vendor = [NSMutableDictionary dictionary];
    NSNumber *currentClass;
    NSNumber *currentVendor;
    char buffer[256];
	long vendor_id, device_id, class_id;
	char c;
	char *buf;
	bool class_parse = false;
	while(fgets(buffer, 256, handle)) {
        if(buffer[0]=='#') continue;
		buf = buffer;
		if (strlen(buffer) <= 4) continue;
        buffer[strlen(buffer)-1]='\0';
        c = *buf;
        if (c == 'C') class_parse = true;
        if (class_parse) {
            if (c == 'C') buf += 2;
            if (c == 0x09) {
                buf++;
                c = *buf;
                if (c != 0x09) {
                    class_id = strtol(buf, NULL, 16);
                    buf += 4;
                    while (*buf == ' ' || *buf == 0x09) buf++;
                    [[[class objectForKey:currentClass] subClasses] setObject:@(buf) forKey:@(class_id)];
                }
            }
            else if (c != '\\') {
                class_id = strtol(buf, NULL, 16);
                currentClass = @(class_id);
                buf += 4;
                while (*buf == ' ' || *buf == 0x09) buf++;
                [class setObject:[pciClass create:@(buf)] forKey:@(class_id)];
            }
        }
        else {
            if (c == 0x09) {
                buf++;
                c = *buf;
                if (c != 0x09) {
                    device_id = strtol(buf, NULL, 16);
                    buf += 4;
                    while (*buf == ' ' || *buf == 0x09) buf++;
                    [[[vendor objectForKey:currentVendor] devices] setObject:@(buf) forKey:@(device_id)];
                }
            }
            else if (c != '\\') {
                vendor_id = strtol(buf, NULL, 16);
                currentVendor = @(vendor_id);
                buf += 4;
                while (*buf == ' ' || *buf == 0x09) buf++;
                [vendor setObject:[pciVendor create:@(buf)] forKey:@(vendor_id)];
            }
        }
	}
    fclose(handle);
    classes = [NSDictionary dictionaryWithDictionary:class];
    vendors = [NSDictionary dictionaryWithDictionary:vendor];
}
-(void)listDevices{
    mach_port_t masterPort;
    io_iterator_t itThis;
    io_service_t service;
    NSMutableArray *list = [NSMutableArray array];
    if(IOMasterPort(MACH_PORT_NULL, &masterPort) != KERN_SUCCESS) {
        [NSAlert alertWithMessageText:@"Could not get master port!" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"Accessing the master Mach port failed"];
		return;
    }
    if(IOServiceGetMatchingServices(masterPort, IOServiceMatching("IOPCIDevice"), &itThis) != KERN_SUCCESS) {
        [NSAlert alertWithMessageText:@"No matching services!" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"IO Registry query returned no services"];
		return;
    }
    while((service = IOIteratorNext(itThis))){
        [list addObject:[pciDevice create:service]];
        IOObjectRelease(service);
	}
    IOObjectRelease(itThis);
    self.pcis = [NSArray arrayWithArray:list];
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

+(NSNumber *)grabEntry:(CFStringRef)entry forService:(io_service_t)service{
    CFTypeRef data = IORegistryEntryCreateCFProperty(service,entry,kCFAllocatorDefault,0);
    return @((data==NULL)?0:*(NSInteger *)CFDataGetBytePtr(data));
}
+(pciDevice *)create:(io_service_t)service{
    pciDevice *temp = [pciDevice new];
    temp.vendor = [self grabEntry:CFSTR("vendor-id") forService:service];
    temp.device = [self grabEntry:CFSTR("device-id") forService:service];
    temp.subVendor = [self grabEntry:CFSTR("subsystem-vendor-id") forService:service];
    temp.subDevice = [self grabEntry:CFSTR("subsystem-id") forService:service];
    temp.pciClassCode = [self grabEntry:CFSTR("class-code") forService:service];
    temp.pciClass = @(([temp.pciClassCode integerValue] >> 16) &0xFF);
    temp.pciSubClass = @(([temp.pciClassCode integerValue] >>8) &0xFF);
    return temp;
}
-(NSString *)vendorString{
    return [[[[NSApp delegate] vendors] objectForKey:self.vendor] name];
}
-(NSString *)deviceString{
    return [[[[[NSApp delegate] vendors] objectForKey:self.vendor] devices] objectForKey:self.device];
}
-(NSString *)classString{
    return [[[[NSApp delegate] classes] objectForKey:self.pciClass] name];
}
-(NSString *)subClassString{
    return [[[[[NSApp delegate] classes] objectForKey:self.pciClass] subClasses] objectForKey:self.pciSubClass];
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
