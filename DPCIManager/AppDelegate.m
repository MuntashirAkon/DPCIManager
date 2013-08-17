//
//  AppDelegate.m
//  DPCIManager
//
//  Created by PHPdev32 on 9/12/12.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "AppDelegate.h"
#import "PCI.h"
#import "Task.h"
#import "Hardware.h"
#import "Match.h"

@implementation AppDelegate
@synthesize panel;
@synthesize pop;
@synthesize nodeLocation;
@synthesize patch;
@synthesize bdmesg;
@synthesize pcis;
@synthesize status;
@synthesize watcher;
@synthesize cond;
@synthesize log;
@synthesize match;
@synthesize matches;
@synthesize report;
@synthesize reporter;
@synthesize flashout;

#pragma mark ApplicationDelegate
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification{
    // Insert code here to initialize your application
    self.patch = @"0x00000000";
    self.bdmesg = [AppDelegate bdmesg];
    self.pcis = [pciDevice readIDs];
    self.status = [AppDelegate readHardware];
    watcher = [NSTask create:@"/usr/bin/tail" args:@[@"-n", @"0", @"-f", @"/var/log/system.log"] callback:@selector(readLog:) listener:self];
    [watcher launch];
    cond = [NSConditionLock new];
    [panel setLevel:NSNormalWindowLevel];
}
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender{
    return true;
}
-(void)applicationWillTerminate:(NSNotification *)notification{
    [watcher terminate];
    if (cond.condition == 1) [cond setCondition:2];
    [cond waitOn:0];
}

#pragma mark NSToolbarDelegate
-(BOOL)validateToolbarItem:(NSToolbarItem *)theItem{
    return theItem.isEnabled;
}

#pragma mark GUI
-(IBAction)copy:(id)sender{
    NSResponder *obj = [[NSApp keyWindow] firstResponder];
    if (obj.class == NSTableView.class) {
        if (![(NSTableView *)obj numberOfSelectedRows]) return;
        bool viewBased = ([(NSTableView *)obj rowViewAtRow:[(NSTableView *)obj selectedRow] makeIfNecessary:false]);
        __block NSMutableArray *rows = [NSMutableArray array];
        [[(NSTableView *)obj selectedRowIndexes] enumerateIndexesUsingBlock:^void(NSUInteger idx, BOOL *stop){
            NSUInteger i = 0, j = [(NSTableView *)obj numberOfColumns];
            NSMutableArray *row = [NSMutableArray array];
            if (viewBased) {
                NSText *view;
                while (i < j)
                    if ((view = [(NSTableView *)obj viewAtColumn:i++ row:idx makeIfNecessary:false]) && [view isKindOfClass:NSText.class])
                        [row addObject:[view.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
            }
            else {
                NSCell *cell;
                while (i < j)
                    if ((cell = [(NSTableView *)obj preparedCellAtColumn:i++ row:idx]) && [cell isKindOfClass:NSTextFieldCell.class])
                        [row addObject:[cell.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
            }
            [row removeObject:@""];
            [rows addObject:[row componentsJoinedByString:@", "]];
        }];
        [NSPasteboard.generalPasteboard clearContents];
        [NSPasteboard.generalPasteboard writeObjects:@[[rows componentsJoinedByString:@"\n"]]];
    }
}
-(IBAction)updateIDs:(id)sender{
    [sender setEnabled:false];
    if ([URLTask conditionalGet:[NSURL URLWithString:@"http://pci-ids.ucw.cz/pci.ids"] toFile:[NSBundle.mainBundle pathForResource:@"pci" ofType:@"ids"]]) {
        [sender setLabel:@"Found"];
        self.pcis = [pciDevice readIDs];
    }
    else
        [sender setLabel:@"None"];
}
-(IBAction)updateSeed:(id)sender{
    [sender setEnabled:false];
    NSString *version = [[[[NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"] objectForKey:@"ProductVersion"] componentsSeparatedByString:@"."] objectAtIndex:1];
    if ([URLTask conditionalGet:[NSURL URLWithString:[NSString stringWithFormat:@"http://dpcimanager.sourceforge.net/10.%@/seed.plist", version]] toFile:[NSBundle.mainBundle pathForResource:@"seed" ofType:@"plist"]]) {
        [sender setLabel:@"Found"];
        match = nil;
    }
    else
        [sender setLabel:@"None"];
}
-(IBAction)submit:(id)sender{
    [sender setEnabled:false];
    NSMutableArray *pciids = [NSMutableArray array];
    for(pciDevice *dev in pcis)
        [pciids addObject:[NSString stringWithFormat:@"id[]=%04lX,%04lX,%04lX,%04lX,%06lX", dev.shadowVendor.integerValue, dev.shadowDevice.integerValue, dev.subVendor.integerValue, dev.subDevice.integerValue, dev.pciClassCode.integerValue]];
    NSString *postData = [pciids componentsJoinedByString:@"&"];
    NSMutableURLRequest *DPCIReceiver = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://dpcimanager.sourceforge.net/receiver"]];
    [DPCIReceiver setHTTPMethod:@"POST"];
    [DPCIReceiver addValue: @"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [DPCIReceiver setValue:[NSString stringWithFormat: @"%lu", postData.length] forHTTPHeaderField:@"Content-Length"];
    [DPCIReceiver setHTTPBody: [postData dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:true]];
    [NSURLConnection sendAsynchronousRequest:DPCIReceiver queue:NSOperationQueue.currentQueue completionHandler:^void(NSURLResponse *response, NSData *data, NSError *err){
        if (!err)
            [sender setLabel:([(NSHTTPURLResponse *)response statusCode] == 200)?@"Success":@"Failed"];
        else
            ModalError(err);
    }];
}
-(IBAction)dumpTables:(id)sender{
    [AppDelegate acpitables:nil];
}
-(IBAction)dumpDsdt:(id)sender{
    [AppDelegate acpitables:@"DSDT"];
}
-(IBAction)fetchKext:(id)sender{
    NSUInteger row = [(NSTableView *)sender selectedRow];
    NSPredicate *filter = [NSPredicate predicateWithFormat:@"shadowVendor == %d AND shadowDevice == %d", strHexDec([[(NSTableView *)sender preparedCellAtColumn:1 row:row] stringValue]), strHexDec([[(NSTableView *)sender preparedCellAtColumn:2 row:row] stringValue])];
    pciDevice *pci;
    io_service_t service;
    NSURL *url;
    if ((pci = [[pcis filteredArrayUsingPredicate:filter] lastObject]) && (service = IOServiceGetMatchingService(kIOMasterPortDefault, (__bridge_retained CFDictionaryRef)[pciDevice match:pci]))) {
        pciDevice *dev = [pciDevice create:service];
        io_service_t child;
        if (dev.pciClassCode.integerValue == 0x30000) {
            io_iterator_t itThis;
            if (IORegistryEntryGetChildIterator(service, kIOServicePlane, &itThis) == KERN_SUCCESS) {
                io_name_t name;
                char ending[9];
                while ((child = IOIteratorNext(itThis))) {
                    IORegistryEntryGetName(child, name);
                    strlcpy(ending, name+MAX(0, strlen(name)-8), MIN(strlen(name), 9));
                    if (!strcmp(ending, "NVKernel") || !strcmp(ending, "ntroller")) {
                        NSString *class = (__bridge_transfer NSString *)IOObjectCopyClass(child), *bundle = (__bridge_transfer NSString *)IOObjectCopyBundleIdentifierForClass((__bridge CFStringRef)class);
                        url = [AppDelegate findKext:bundle];
                        IOObjectRelease(child);
                        break;
                    }
                    IOObjectRelease(child);
                }
                IOObjectRelease(itThis);
            }
        }
        else if (IORegistryEntryGetChildEntry(service, kIOServicePlane, &child) == KERN_SUCCESS){
            NSString *class = (__bridge_transfer NSString *)IOObjectCopyClass(child), *bundle = (__bridge_transfer NSString *)IOObjectCopyBundleIdentifierForClass((__bridge CFStringRef)class);
            url = [AppDelegate findKext:bundle];
            IOObjectRelease(child);
        }
        if (url) SHOWFILE(url.path);
        else {
            if (!match) match = [Match create];
            self.matches = [match match:dev];
            if (matches.count > 0) {
                [pop showRelativeToRect:[sender rectOfRow:[sender selectedRow]] ofView:sender preferredEdge:NSMinXEdge];
                [[[[[[[[[pop contentViewController] view] subviews] objectAtIndex:0] subviews] objectAtIndex:0] subviews] objectAtIndex:0] expandItem:nil expandChildren:true];
            }
            else NSBeep();
        }
        IOObjectRelease(service);
    }
}
-(IBAction)patchNode:(id)sender{
    if ([sender tag] < 2) {
        NSInteger i = [[patch substringWithRange:NSMakeRange(2, 1)] integerValue]&(0b11<<(![sender tag]?0:2));
        i |= [[sender selectedItem] tag]<<(![sender tag]?2:0);
        self.patch = [patch stringByReplacingCharactersInRange:NSMakeRange(2, 1) withString:[NSString stringWithFormat:@"%01lX", i]];
        if ([sender tag] == 1) {
            i=0;
            [nodeLocation removeAllItems];
            for (NSString *choice in [@[@[@"N/A", @"Rear", @"Front", @"Left", @"Right", @"Top", @"Bottom", @"Rear Panel", @"Drive Bay"], @[@"N/A", @"", @"", @"", @"", @"", @"", @"Riser", @"Digital Display", @"ATAPI"], @[@"N/A", @"Rear", @"Front", @"Left", @"Right", @"Top", @"Bottom"], @[@"N/A", @"", @"", @"", @"", @"", @"Bottom", @"Inside Lid", @"Outside Lid"]] objectAtIndex:[[sender selectedItem] tag]]) {
                if (!choice.length) {
                    i++;
                    continue;
                }
                NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:choice action:NULL keyEquivalent:@""];
                [item setTag:i++];
                [[nodeLocation menu] addItem:item];
            }
            [nodeLocation selectItemAtIndex:0];
            [self patchNode:nodeLocation];
        }
    }
    else
        self.patch = [patch stringByReplacingCharactersInRange:NSMakeRange([sender tag]+1, 1) withString:[NSString stringWithFormat:@"%lX", [[sender selectedItem] tag]]];
}
-(IBAction)pstates:(id)sender{
    if (cond.condition) {
        [cond setCondition:2];
        return;
    }
    if (![AppDelegate checkDirect]) return;
    [sender setEnabled:false];
    [panel makeKeyAndOrderFront:sender];
    [cond setCondition:1];
    [self performSelectorInBackground:@selector(logStates:) withObject:sender];
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
    NSString *kext = open.URL.path;
    if ([NSFileManager.defaultManager fileExistsAtPath:[kSLE stringByAppendingPathComponent:kext.lastPathComponent]])
        if (NSRunAlertPanel(@"Kernel Extension Already Exists", @"You are attempting to replace an existing kernel extension, continue?", nil, @"Cancel", nil) != NSAlertDefaultReturn)
            return;
    [sender setEnabled:false];
    [panel makeKeyAndOrderFront:sender];
    [AScript adminExec:[NSString stringWithFormat:@"/bin/rm -r '%@';/bin/cp -RX '%@' %@;/usr/bin/touch %@", [kSLE stringByAppendingPathComponent:[kext.lastPathComponent stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"]], [kext stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"], kSLE, kSLE]];
    [sender setEnabled:true];
}
-(IBAction)fetchCMOS:(id)sender{
    NSRange range = NSMakeRange(0, 128);
    unsigned char buff[range.length];
    NSMutableData *cmos = [NSMutableData data];
    io_service_t service;
    if ((service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleRTC")))) {
        io_connect_t connect;
        if (IOServiceOpen(service, mach_task_self(), 0x0101FACE, &connect) == KERN_SUCCESS){
            while(IOConnectCallMethod(connect, 0, (uint64_t *)&range.location, 1, NULL, 0, NULL, NULL, buff, &range.length) == KERN_SUCCESS) {
                [cmos appendBytes:buff length:range.length];
                range.location += 128;
            }
            IOServiceClose(connect);
        }
        IOObjectRelease(service);
    }
}
-(IBAction)ethString:(id)sender{
    if ([sender selectedRow] == -1) return;
    pciDevice *device = [[[status objectForKey:@"network"] objectAtIndex:[sender selectedRow]] objectForKey:@"device"];
    if ([device isMemberOfClass:[NSNull class]]) {
        NSRunAlertPanel(@"Not a PCI Device", @"The chosen interface is not a PCI device", nil, nil, nil);
        return;
    }
    NSString *efi = [efiObject stringWithArray:@[[efiObject create:device injecting:@{@"built-in":@(YES)}]]];
    if (efi)
        NSRunInformationalAlertPanel(@"Ethernet EFI String", @"Add the following to org.chameleon.boot.plist\n<key>device-properties</key>\n<string>%@</string>", nil, nil, nil, efi);
    else
        NSBeep();
}
-(IBAction)fetchvBIOS:(id)sender{
    if ([sender selectedRow] == -1) return;
    NSOpenPanel *open = DirectoryChooser();
    [open setTitle:@"Save Video BIOS"];
    if ([open runModal] != NSFileHandlingPanelOKButton) return;
    pciDevice *device = [[[status objectForKey:@"graphics"] objectAtIndex:[sender selectedRow]] objectForKey:@"device"];
    io_service_t service;
    if ((service = IOServiceGetMatchingService(kIOMasterPortDefault, (__bridge_retained CFDictionaryRef)[pciDevice match:device]))) {
        NSError *err;
        NSData *bin;
        if ((bin = (__bridge_transfer NSData *)IORegistryEntryCreateCFProperty(service, CFSTR("ATY,bin_image"), kCFAllocatorDefault, 0))) {
            [bin writeToFile:[NSString stringWithFormat:@"%@/%04lx_%04lx_%04lx%04lx.rom", open.URL.path, device.vendor.integerValue, device.device.integerValue, device.subDevice.integerValue, device.subVendor.integerValue] options:NSDataWritingAtomic error:&err];
            ModalError(err);
        }
        else if ((bin = (__bridge_transfer NSData *)IORegistryEntryCreateCFProperty(service, CFSTR("vbios"), kCFAllocatorDefault, 0))) {
            [bin writeToFile:[NSString stringWithFormat:@"%@/%04lx_%04lx.rom", open.URL.path, device.vendor.integerValue, device.device.integerValue] options:NSDataWritingAtomic error:&err];
            ModalError(err);
        }
        else if (device.vendor.integerValue == 0x10DE)
            NSRunInformationalAlertPanel(@"NVidia Video BIOS Not Loaded", @"The video BIOS was not loaded at boot. Please reboot, enter 'VBIOS=Yes', and try again.", nil, nil, nil);
        else NSBeep();
        IOObjectRelease(service);
    }
}
#pragma mark Logging
-(void)logStates:(id)sender{
    io_service_t service;
    if ((service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("DirectHWService")))) {
        NSUInteger frequency = 10;
        NSMutableSet *states = [NSMutableSet set];
        io_connect_t connect;
        if (IOServiceOpen(service, mach_task_self(), 0, &connect) == KERN_SUCCESS) {
            NSUInteger i = 0;
            msrcmd_t in = {0, 0x198}, out;
            size_t size = sizeof(msrcmd_t);
            kern_return_t ret;
            while (cond.condition != 2) {
                usleep(kMillisecondScale/frequency);
                if ((ret = IOConnectCallStructMethod(connect, 3, &in, size, &out, &size)) != KERN_SUCCESS) {
                    if (ret == kIOReturnIOError && frequency > 1) {
                        [self logLine:[@"P States: I/O error, throttling to " stringByAppendingFormat:@"%ldHz", --frequency]];
                        continue;
                    }
                    [self logLine:[NSString stringWithFormat:@"P States: method failed, exiting 0x%X", ret]];
                    break;
                }
                NSNumber *state = [NSNumber numberWithInteger:(!(out.lo&0xFF)) ? out.lo>>8&0xFF : out.lo&0xFF];
                [states addObject:state];
                if (!(i++ % (5*frequency))) {
                    [self logLine:[NSString stringWithFormat:@"P States: %@", [[states.allObjects sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@", "]]];
                    [self logLine:[NSString stringWithFormat:@"Current State: %@", state]];
                }
            }
            IOServiceClose(connect);
        }
        IOObjectRelease(service);
    }
    [[sender toolbar] setSelectedItemIdentifier:nil];
    [cond setCondition:0];
}
-(void)readLog:(NSData *)data{
    [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] enumerateLinesUsingBlock:^(NSString *line, BOOL *stop){
        if ([line rangeOfString:@"kextd"].location != NSNotFound || [line rangeOfString:@"kextcache"].location != NSNotFound || [line rangeOfString:@"DirectHW"].location != NSNotFound || [line rangeOfString:@"Repair Permissions"].location != NSNotFound)
            [self logLine:[line substringFromIndex:[line rangeOfString:@" " options:0 range:NSMakeRange(16, line.length-16)].location+1]];
    }];
}
-(void)logTask:(NSData *)data{
    [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] enumerateLinesUsingBlock:^(NSString *line, BOOL *stop){
        if (line.length > 0) [self logLine:line];
    }];
}
-(void)logLine:(NSString *)line{
    if (!NSThread.isMainThread) {
        [self performSelectorOnMainThread:_cmd withObject:line waitUntilDone:false];
        return;
    }
    if (!log) log = [NSMutableArray array];
    [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:0] forKey:@"log"];
    [log insertObject:@{@"timestamp":[NSDate date], @"entry":line} atIndex:0];
    [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:0] forKey:@"log"];
}
@end