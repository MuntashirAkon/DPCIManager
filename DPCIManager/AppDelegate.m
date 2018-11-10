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
    if ([URLTask conditionalGet:[NSURL URLWithString:@"https://pci-ids.ucw.cz/pci.ids"] toFile:[NSBundle.mainBundle pathForResource:@"pci" ofType:@"ids"]]) {
        [sender setLabel:@"Found"];
        self.pcis = [pciDevice readIDs];
    }
    else
        [sender setLabel:@"None"];
}
-(IBAction)dumpTables:(id)sender{
    [AppDelegate acpitables:nil];
}
-(IBAction)dumpDsdt:(id)sender{
    [AppDelegate acpitables:@"DSDT"];
}
-(IBAction)fetchKext:(id)sender{
    NSArrayController *c = [[[[sender tableColumns] lastObject] infoForBinding:NSValueBinding] objectForKey:NSObservedObjectKey];
    pciDevice *pci = [c.arrangedObjects objectAtIndex:[sender clickedRow]];
    io_service_t service;
    NSURL *url;
    if ((service = IOServiceGetMatchingService(kIOMasterPortDefault, IORegistryEntryIDMatching(pci.entryID)))) {
        io_service_t child;
        if (pci.pciClassCode.integerValue == 0x30000) {
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
            self.matches = [match match:pci];
            if (matches.count > 0) {
                [pop showRelativeToRect:[sender rectOfRow:[sender selectedRow]] ofView:sender preferredEdge:NSMinXEdge];
                [[[[[[[[[pop contentViewController] view] subviews] objectAtIndex:0] subviews] objectAtIndex:0] subviews] objectAtIndex:0] expandItem:nil expandChildren:true];
            }
            else NSBeep();
        }
        IOObjectRelease(service);
    }
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
    NSString *version = [[[[NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"] objectForKey:@"ProductVersion"] componentsSeparatedByString:@"."] objectAtIndex:1];
    NSOpenPanel *open = [NSOpenPanel openPanel];
    [open setAllowedFileTypes:@[@"kext"]];
    if ([open runModal] == NSFileHandlingPanelCancelButton) return;
    NSString *kext = open.URL.path;
    // Scan SLE first
    if ([NSFileManager.defaultManager fileExistsAtPath:[kSLE stringByAppendingPathComponent:kext.lastPathComponent]]){
        if (NSRunAlertPanel(@"Kernel Extension Already Exists", @"You are attempting to replace an existing kernel extension, continue?", nil, @"Cancel", nil) != NSAlertDefaultReturn)
            return;
        [AScript adminExec:[NSString stringWithFormat:@"/bin/rm -r '%@'", [kSLE stringByAppendingPathComponent:[kext.lastPathComponent stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"]]]];
    }
    // Scan LE if version is or more 10.11
    if (version.integerValue >= 11 && [NSFileManager.defaultManager fileExistsAtPath:[kLE stringByAppendingPathComponent:kext.lastPathComponent]]){
        if (NSRunAlertPanel(@"Kernel Extension Already Exists", @"You are attempting to replace an existing kernel extension, continue?", nil, @"Cancel", nil) != NSAlertDefaultReturn)
            return;
        [AScript adminExec:[NSString stringWithFormat:@"/bin/rm -r '%@'", [kLE stringByAppendingPathComponent:[kext.lastPathComponent stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"]]]];
    }
    [sender setEnabled:false];
    [panel makeKeyAndOrderFront:sender];
    // Determine install location (LE or SLE)
    NSString *location = version.integerValue >= 11 ? kLE : kSLE;
    [AScript adminExec:[NSString stringWithFormat:@"/bin/cp -RX '%@' %@;/usr/bin/touch %@", [kext stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"], location, location]];
    [sender setEnabled:true];
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
    if ([sender clickedRow] == -1) return;
    NSOpenPanel *open = DirectoryChooser();
    [open setTitle:@"Save Video BIOS"];
    if ([open runModal] != NSFileHandlingPanelOKButton) return;
    pciDevice *device = [[[status objectForKey:@"graphics"] objectAtIndex:[sender clickedRow]] objectForKey:@"device"];
    io_service_t service;
    if ((service = IOServiceGetMatchingService(kIOMasterPortDefault, IORegistryEntryIDMatching(device.entryID)))) {
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
