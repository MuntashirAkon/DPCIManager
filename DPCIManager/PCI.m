//
//  pci.m
//  DPCIManager
//
//  Created by PHPdev32 on 10/8/12.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "PCI.h"
#import "AppDelegate.h"

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
+(pciDevice *)create:(io_service_t)service classes:(NSMutableDictionary *)classes vendors:(NSMutableDictionary *)vendors{
    pciDevice *temp = [pciDevice create:service];
    temp.vendorString = [[vendors objectForKey:temp.vendor] name];
    temp.deviceString = [[[vendors objectForKey:temp.vendor] devices] objectForKey:temp.device];
    temp.classString = [[classes objectForKey:temp.pciClass] name];
    temp.subClassString = [[[classes objectForKey:temp.pciClass] subClasses] objectForKey:temp.pciSubClass];
    return temp;
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
-(NSString *)fullClassString{
    return [NSString stringWithFormat:@"%@, %@", [self classString], [self subClassString]];
}
-(long)fullID{
    return [device integerValue]<<16 | [vendor integerValue];
}
-(long)fullSubID{
    return [subDevice integerValue]<<16 | [subVendor integerValue];
}
+(NSArray *)readIDs{
    FILE *handle = fopen([[[NSApp delegate] file] fileSystemRepresentation],"rb");
    NSMutableArray *pcis = [NSMutableArray array];
    NSMutableDictionary *classes = [NSMutableDictionary dictionary];
    NSMutableDictionary *vendors = [NSMutableDictionary dictionary];
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
            [pcis addObject:[pciDevice create:service classes:classes vendors:vendors]];
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    return pcis;
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