//
//  main.m
//  dspci
//
//  Created by PHPdev32 on 1/14/13.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import <Foundation/Foundation.h>
#import <mach-o/getsect.h>
#import "PCI.h"

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        
        // insert code here...
        unsigned long len;
        char *handle = strdup(getsectdata("__TEXT", "__pci_ids", &len));
        NSMutableDictionary *classes = [NSMutableDictionary dictionary];
        NSMutableDictionary *vendors = [NSMutableDictionary dictionary];
        NSNumber *currentClass;
        NSNumber *currentVendor;
        char buffer[LINE_MAX];
        sscanf(strstr(handle, "Version:"), "Version: %[^\n]", buffer);
        printf("Using PCI.IDs %s\n", buffer);
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
                pciDevice *pci = [pciDevice create:service classes:classes vendors:vendors];
                if (pci.fullID+pci.fullSubID > 0) printf("%s\n", pci.lspciString.UTF8String);
                IOObjectRelease(service);
            }
            IOObjectRelease(itThis);
        }
        
    }
    return 0;
}

