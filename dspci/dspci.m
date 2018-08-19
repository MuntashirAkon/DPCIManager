//
//  dspci.m
//  dspci
//
//  Created by Muntashir Al-Islam on 8/20/18.
//

#import <Foundation/Foundation.h>
#import <mach-o/getsect.h>
#import <string.h>
#import "dspci.h"
#import "PCI.h"
#import "JSON.h"


@implementation DSPCI

- (id) init {
    self = [super init];
    if (self == nil)
        return nil;
    classes = [NSMutableDictionary dictionary];
    vendors = [NSMutableDictionary dictionary];
    fetchDate = [self loadPCIIDs];
    return self;
}

- (void) printUsage: (FILE *) stream {
    ddfprintf(stream, @"%@: Usage [OPTIONS] [<argument>]\n", DDCliApp);
}

- (void) printHelp {
    [self printUsage: stdout];
    printf("\n"
           "      --verbose                 Increase verbosity\n"
           "      --version                 Display version and exit\n"
           "  -h, --help                    Display this help and exit\n"
           "\n"
           "dspci is a command line tool for getting PCI and other PCI-related information.\n");
}

- (void) printVersion {
    ddprintf(@"%@ version %s\n", DDCliApp, CURRENT_MARKETING_VERSION);
}

- (void) application: (DDCliApplication *) app willParseOptions: (DDGetoptLongParser *) optionsParser {
    DDGetoptOption optionTable[] = {
        // Long         Short   Argument options
        {"json",        0,      DDGetoptNoArgument},
        {"version",     0,      DDGetoptNoArgument},
        {"help",       'h',     DDGetoptNoArgument},
        {"",            0,      0},
    };
    [optionsParser addOptionsFromTable: optionTable tableSize:(sizeof(optionTable)/sizeof(*optionTable))];
}

- (int) application: (DDCliApplication *) app runWithArguments: (NSArray *) arguments {
    if (_help) {
        [self printHelp];
        return EXIT_SUCCESS;
    }
    
    if (_version) {
        [self printVersion];
        return EXIT_SUCCESS;
    }
    
    [self printPCIList:@""];
//    if ([arguments count] < 1) {
//        ddfprintf(stderr, @"%@: At least one argument is required\n", DDCliApp);
//        [self printUsage: stderr];
//        ddfprintf(stderr, @"Try `%@ --help' for more information.\n",
//                  DDCliApp);
//        return EX_USAGE;
//    }

//    ddprintf(@"foo: %@, bar: %@, longOpt: %@, verbosity: %d\n",
//             _foo, _bar, _longOpt, _verbosity);
//    ddprintf(@"Include directories: %@\n", _includeDirectories);
//    ddprintf(@"Arguments: %@\n", arguments);
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
    return [NSString stringWithUTF8String:buffer];
}

- (void) printPCIList: (NSString *) dataType {
    io_iterator_t itThis;
    if(!_json) ddprintf(@"Using PCI.IDs %@\n", fetchDate);
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOPCIDevice"), &itThis) == KERN_SUCCESS) {
        io_service_t service;
        NSMutableArray *devices = [NSMutableArray array];
        NSMutableArray *devicesJSON = [NSMutableArray array];
        while((service = IOIteratorNext(itThis))){
            pciDevice *device = [pciDevice create:service classes:classes vendors:vendors];
            if (device.fullID + device.fullSubID > 0) [devices addObject:device];
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
        for (pciDevice *device in [devices sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            return [obj1 bdf] - [obj2 bdf];
        }]){
            if(_json) [devicesJSON addObject:device.lspciDictionary];
            else printf("%s\n", device.lspciString.UTF8String);
        }
        if(_json) printf("%s\n", [devicesJSON bv_jsonStringWithPrettyPrint:true].UTF8String);
    }
}
@end
