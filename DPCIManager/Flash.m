//
//  Flash.m
//  DPCIManager
//
//  Created by PHPdev32 on 3/29/13.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "Flash.h"
#import "Task.h"
#import "Hardware.h"
#define kROMTemplate @"DPCIXXXXXX.rom"
#define kCAPHeader "\x8B\xA6\x3C\x4A\x23\x77\xFB\x48\x80\x3D\x57\x8C\xC1\xFE\xC4\x4D"
#define kCAPHeaderLen 16

@implementation AppDelegate (FlashingAdditions)
static NSRegularExpression *macregex;
static NSRegularExpression *optest;

+(void)initialize {
    macregex = [NSRegularExpression regularExpressionWithPattern:@"[A-F0-9]{2}:[A-F0-9]{2}:[A-F0-9]{2}:[A-F0-9]{2}:[A-F0-9]{2}:[A-F0-9]{2}" options:0 error:nil];
    optest = [NSRegularExpression regularExpressionWithPattern:@"UNTESTED for operations: ([A-Z ]+)\\n" options:0 error:nil];
}

#pragma mark GUI
-(IBAction)readROM:(id)sender{
    if (![AppDelegate checkDirect]) return;
    NSSavePanel *save = [NSSavePanel savePanel];
    [save setAllowedFileTypes:@[@"rom"]];
    [save setNameFieldStringValue:[self.report objectForKey:@"dmi"]];
    if ([save runModal] != NSFileHandlingPanelOKButton) return;
    [self.panel makeKeyAndOrderFront:sender];
    [self read:save.URL.path];
}
-(IBAction)writeROM:(id)sender{
    NSError *err;
    if (![AppDelegate checkDirect]) return;
    NSOpenPanel *open = [NSOpenPanel openPanel];
    [open setAllowedFileTypes:@[@"rom", @"cap"]];
    if ([open runModal] != NSFileHandlingPanelOKButton) return;
    NSString *new = [self uncap:open.URL.path];
    if (!new) return;
    [self.panel makeKeyAndOrderFront:sender];
    [self flash:new];
    if (![NSFileManager.defaultManager removeItemAtPath:new error:&err])
        ModalError(err);
}
-(IBAction)testROM:(id)sender{
    if (![AppDelegate checkDirect]) return;
    [self.panel makeKeyAndOrderFront:sender];
    NSTask *task = [NSTask createSingle:[NSBundle.mainBundle pathForAuxiliaryExecutable:@"flashrom"] args:@[@"-VV", @"-p", @"internal"] callback:@selector(logReport:) listener:self];
    [task launchAndWait];
    [self prepareReport:task];
}
-(IBAction)patchROM:(id)sender{
    NSError *err;
    NSOpenPanel *open = [NSOpenPanel openPanel];
    [open setAllowedFileTypes:@[@"rom", @"cap"]];
    if ([open runModal] != NSFileHandlingPanelOKButton) return;
    NSString *new = [self uncap:open.URL.path];
    if (!new) return;
    [self.panel makeKeyAndOrderFront:sender];
    if (![self patch:new]) return;
    NSString *old = [NSString stringWithFormat:@"%@ Patched.rom", open.URL.path.stringByDeletingPathExtension];
    if (![NSFileManager.defaultManager moveItemAtPath:new toPath:old error:&err]) {
        ModalError(err);
        return;
    }
    SHOWFILE(old);
}
-(IBAction)autopatchROM:(id)sender{
    if (![AppDelegate checkDirect]) return;
    NSError *err;
    NSString *old = [AScript tempFile:kROMTemplate];
    [self.panel makeKeyAndOrderFront:sender];
    if (![self read:old]) return;
    if (![self patch:old]) return;
    [self flash:old];
    if (![NSFileManager.defaultManager removeItemAtPath:old error:&err])
        ModalError(err);
}
-(IBAction)patchflashROM:(id)sender{
    if (NSRunCriticalAlertPanel(@"BIOS Settings Reset", @"This function will reset your BIOS settings as a result of flashing a new ROM, continue?", nil, @"Cancel", nil) != NSAlertDefaultReturn) return;
    if (![AppDelegate checkDirect]) return;
    NSError *err;
    NSOpenPanel *open = [NSOpenPanel openPanel];
    [open setAllowedFileTypes:@[@"rom", @"cap"]];
    if ([open runModal] != NSFileHandlingPanelOKButton) return;
    NSString *new = [self uncap:open.URL.path];
    if (!new) return;
    [self.panel makeKeyAndOrderFront:sender];
    if (![self patch:new]) return;
    [self flash:new];
    if (![NSFileManager.defaultManager removeItemAtPath:new error:&err])
        ModalError(err);
}
-(IBAction)cancelReport:(id)sender{
    [NSApp endSheet:self.reporter];
    [self.reporter orderOut:sender];
    [NSApp stopModal];
}
-(IBAction)submitReport:(id)sender{
    NSMutableDictionary *report = self.report;
    if (![report objectForKey:@"email"]) [report setObject:@"" forKey:@"email"];
    if ([[report objectForKey:@"status"] boolValue] && ![[report objectForKey:@"email"] length])
        if (NSRunAlertPanel(@"Email Strongly Recommended", @"The flashrom task failed, and it is strongly recommended that you submit your email address with the report to receive support, continue anyway?", nil, @"Cancel", nil) != NSAlertDefaultReturn)
            return;
    NSMutableURLRequest *FRReporter = [NSMutableURLRequest requestWithURL:[URLTask getURL:@"" withQuery:@{@"email":[report objectForKey:@"email"], @"board":[report objectForKey:@"dmi"], @"tested":[[report objectForKey:@"tested"] stringValue], @"status":[[report objectForKey:@"status"] stringValue], @"operation":[report objectForKey:@"operation"], @"chassis":[report objectForKey:@"chassis"]}]];
    [FRReporter setHTTPMethod:@"POST"];
    NSString *boundary = [[@"" stringByPaddingToLength:40 withString:@"-" startingAtIndex:0] stringByAppendingFormat:@"%ld", random()];
    [FRReporter addValue:[@"multipart/form-data; boundary=" stringByAppendingString:boundary] forHTTPHeaderField:@"Content-Type"];
    if (![[report objectForKey:@"status"] boolValue])
        [FRReporter setHTTPBody:[[NSString stringWithFormat:@"--%@\r\ncontent-disposition: form-data; name=\"flashrom\"\r\n\r\n%@\r\n--%@--", boundary, [report objectForKey:@"flashrom"], boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    else
        [FRReporter setHTTPBody:[[NSString stringWithFormat:@"--%@\r\ncontent-disposition: form-data; name=\"flashrom\"\r\n\r\n%@\r\n--%@\r\ncontent-disposition: form-data; name=\"lspci\"\r\n\r\n%@\r\n--%@\r\ncontent-disposition: form-data; name=\"superio\"\r\n\r\n%@\r\n--%@--", boundary, [report objectForKey:@"flashrom"], boundary, [report objectForKey:@"lspci"], boundary, [report objectForKey:@"superio"], boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [FRReporter setValue:[NSString stringWithFormat:@"%ld", FRReporter.HTTPBody.length] forHTTPHeaderField:@"Content-Length"];
    [report setObject:[URLTask asyncUpload:FRReporter withMode:NSModalPanelRunLoopMode onSuccess:^(NSData *data){
        if (data && data.length > 0)
            NSRunInformationalAlertPanel(@"Flashrom Report Response", @"%@", nil, nil, nil, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        [self cancelReport:self];
    } onError:^(NSError *err){
        ModalError(err);
    }] forKey:@"connection"];
}

#pragma mark Functions
-(NSString *)uncap:(NSString *)old{
    NSError *err;
    NSString *new = [AScript tempFile:kROMTemplate];
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:old];
    if (!strncmp([[file readDataOfLength:kCAPHeaderLen] bytes], kCAPHeader, kCAPHeaderLen)) {
        [file seekToFileOffset:2048];
        [[file readDataToEndOfFile] writeToFile:new options:NSDataWritingAtomic error:&err];
        ModalError(err);
        [file closeFile];
        return new;
    }
    else if (![NSFileManager.defaultManager copyItemAtPath:old toPath:new error:&err]) {
        ModalError(err);
        return nil;
    }
    return new;
}
-(bool)fd44:(NSString *)new{
    NSMutableDictionary *report = self.report;
    if (![[report objectForKey:@"dmi"] hasPrefix:@"ASUS"] || (![[report objectForKey:@"socket"] isEqualToNumber:@1155] && ![[report objectForKey:@"socket"] isEqualToNumber:@2011])) return true;
    if ([[[report objectForKey:@"addrs"] allValues] containsObject:kStubMAC]) return true;
    NSString *FD44 = [NSBundle.mainBundle pathForAuxiliaryExecutable:@"FD44Copier"];
    NSTask *copier = [NSTask create:FD44 args:@[new, @"/dev/null"] callback:NULL listener:nil];
    [copier launchAndWait];
    NSString *ret = [[NSString alloc] initWithData:[[copier.standardOutput fileHandleForReading] readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    NSRange mac = [macregex rangeOfFirstMatchInString:ret options:0 range:NSMakeRange(0, ret.length)];
    if (copier.terminationStatus != 4) return false;
    if ([ret rangeOfString:@"modules are empty"].location != NSNotFound || mac.location == NSNotFound || ![[[report objectForKey:@"addrs"] allValues] containsObject:[ret substringWithRange:mac]]) {
        NSString *old = [AScript tempFile:kROMTemplate];
        if (![self read:old]) return false;
        copier = [NSTask create:FD44 args:@[old, new] callback:@selector(logTask:) listener:self];
        [copier launchAndWait];
        NSError *err;
        if (![NSFileManager.defaultManager removeItemAtPath:old error:&err])
            ModalError(err);
        return (copier.terminationStatus < 2);
    }
    return true;
}
-(bool)patch:(NSString *)old{
    NSError *err;
    NSString *new = [AScript tempFile:kROMTemplate];
    NSTask *task = [NSTask create:[NSBundle.mainBundle pathForAuxiliaryExecutable:@"PMPatch"] args:@[old, new] callback:@selector(logTask:) listener:self];
    [task launchAndWait];
    if (task.terminationStatus) {
        NSRunCriticalAlertPanel(@"PMPatch Failed", @"PMPatch failed to patch power management, see the log for details.", nil, nil, nil);
        return false;
    }
    if (![NSFileManager.defaultManager removeItemAtPath:old error:&err] || ![NSFileManager.defaultManager moveItemAtPath:new toPath:old error:&err]) {
        ModalError(err);
        return false;
    }
    return true;
}
-(bool)read:(NSString *)path{
    NSTask *task = [NSTask createSingle:[NSBundle.mainBundle pathForAuxiliaryExecutable:@"flashrom"] args:@[@"-VV", @"-r", path, @"-p", @"internal"] callback:@selector(logReport:) listener:self];
    if ([[self.report objectForKey:@"dmi"] length] > 0)
        [task setEnvironment:@{@"PATH":[task.launchPath stringByDeletingLastPathComponent]}];
    [task launchAndWait];
    return [self prepareReport:task];
}
-(bool)flash:(NSString *)path{
    if (![self fd44:path]) return false;
    NSTask *task = [NSTask createSingle:[NSBundle.mainBundle pathForAuxiliaryExecutable:@"flashrom"] args:@[@"-VV", @"-w", path, @"-p", @"internal"] callback:@selector(logReport:) listener:self];
    if ([[self.report objectForKey:@"dmi"] length] > 0)
        [task setEnvironment:@{@"PATH":[task.launchPath stringByDeletingLastPathComponent]}];
    [task launchAndWait];
    if (!task.terminationStatus)
        NSRunInformationalAlertPanel(@"Flashing Complete", @"A new BIOS has been flashed, please restart.", nil, nil, nil);
    return [self prepareReport:task];
}
-(bool)prepareReport:(NSTask *)task{
    NSString *operation = @"none", *flashout = [[NSString alloc] initWithData:self.flashout encoding:NSASCIIStringEncoding];
    self.flashout = nil;
    enum flashromstatus status = !!task.terminationStatus;
    if ([flashout rangeOfString:@"flash chip apparently didn't do anything"].location != NSNotFound) status = nonfatal;
    else if ([flashout rangeOfString:@"Your flash chip is in an unknown state"].location != NSNotFound) {
        status = critical;
        NSRunCriticalAlertPanel(@"Critical Failure", @"Flashrom has failed critically and you should not restart until your report is reviewed. Please submit the following report.", nil, nil, nil);
    }
    bool tested = true;
    if ([task.arguments containsObject:@"-r"]) operation = @"read";
    else if ([task.arguments containsObject:@"-w"]) {
        operation = @"write";
        if ([flashout rangeOfString:@"marked as untested"].location != NSNotFound) tested = false;
    }
    if (tested) {
        NSRange untested = [[optest firstMatchInString:flashout options:0 range:NSMakeRange(0, flashout.length)] rangeAtIndex:1];
        if (untested.location != 0)
            for (NSString *op in [[flashout substringWithRange:untested] componentsSeparatedByString:@" "]) {
                if ([op isEqualToString:@"PROBE"]) tested = false;
                else if ([op isEqualToString:@"READ"] && [operation isEqualToString:@"read"]) tested = false;
                else if (([op isEqualToString:@"WRITE"] || [op isEqualToString:@"ERASE"]) && [operation isEqualToString:@"write"])
                    tested = false;
            }
    }
    if (!status && tested) return true;
    NSMutableDictionary *report = self.report;
    [self willChangeValueForKey:@"report"];
    [report setObject:@(status) forKey:@"status"];
    [report setObject:@(tested) forKey:@"tested"];
    [report setObject:operation forKey:@"operation"];
    [report setObject:[flashout stringByReplacingOccurrencesOfString:[@"/Users" stringByAppendingPathComponent:NSUserName()] withString:@"~"] forKey:@"flashrom"];
    if (!status) {
        [report setObject:@"Flashrom Task Successful" forKey:@"title"];
        [report setObject:[report objectForKey:@"flashrom"] forKey:@"text"];
    }
    else {
        [report setObject:[[self.pcis valueForKey:@"lspciString"] componentsJoinedByString:@"\n"] forKey:@"lspci"];
        [report setObject:[NSTask launchAndOut:[NSBundle.mainBundle pathForAuxiliaryExecutable:@"superiotool"] args:@[@"-deV"]] forKey:@"superio"];
        [report setObject:[NSString stringWithFormat:@"%@\n%@\n%@", [report objectForKey:@"flashrom"], [report objectForKey:@"lspci"], [report objectForKey:@"superio"]] forKey:@"text"];
        [report setObject:[@"Flashrom Task Failed" stringByAppendingString:(status == critical)?@" Critically":@""] forKey:@"title"];
    }
    [self didChangeValueForKey:@"report"];
    [NSApp beginSheet:self.reporter modalForWindow:[NSApp mainWindow] modalDelegate:nil didEndSelector:nil contextInfo:nil];
    [NSApp runModalForWindow:self.reporter];
    return !status;
}

#pragma mark Logging
-(void)logReport:(NSData *)data{
    if (!self.flashout) self.flashout = [NSMutableData data];
    [self.flashout appendData:data];
    [self logTask:data];
}

@end