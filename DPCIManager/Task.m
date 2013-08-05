//
//  Task.m
//  DPCIManager
//
//  Created by PHPdev32 on 10/13/12.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "Task.h"
#import <objc/runtime.h>
#import <sys/types.h>
#import <sys/socket.h>
#import <ifaddrs.h>
#import <net/if_dl.h>
#import <net/if_types.h>

static char kCallbackKey;
static char kListenerKey;
static char kLockKey;

@implementation NSTask (TaskAdditions)

-(void)setCallback:(SEL)callback{
    objc_setAssociatedObject(self, &kCallbackKey, NSStringFromSelector(callback), OBJC_ASSOCIATION_RETAIN);
}
-(SEL)callback{
    return NSSelectorFromString(objc_getAssociatedObject(self, &kCallbackKey));
}
-(void)setListener:(id)listener{
    objc_setAssociatedObject(self, &kListenerKey, listener, OBJC_ASSOCIATION_RETAIN);
}
-(id)listener{
    return objc_getAssociatedObject(self, &kListenerKey);
}

+(NSString *)launchAndOut:(NSString *)path args:(NSArray *)arguments{
    NSTask *temp = [NSTask new];
    [temp setLaunchPath:path];
    [temp setArguments:arguments];
    [temp setStandardOutput:[NSPipe pipe]];
    [temp launchAndWait];
    return [[NSString alloc] initWithData:[[temp.standardOutput fileHandleForReading] readDataToEndOfFile] encoding:NSASCIIStringEncoding];
}
+(NSTask *)create:(NSString *)path args:(NSArray *)arguments callback:(SEL)selector listener:(id)object{
    NSTask *temp = [NSTask new];
    objc_setAssociatedObject(temp, &kLockKey, [NSConditionLock new], OBJC_ASSOCIATION_RETAIN);
    [temp setLaunchPath:path];
    [temp setArguments:arguments];
    [temp setListener:object];
    [temp setCallback:selector];
    [temp setStandardError:[NSPipe pipe]];
    [temp setStandardOutput:[NSPipe pipe]];
    [temp performSelectorInBackground:@selector(read:) withObject:[temp.standardError fileHandleForReading]];
    [temp performSelectorInBackground:@selector(read:) withObject:[temp.standardOutput fileHandleForReading]];
    return temp;
}
+(NSTask *)createSingle:(NSString *)path args:(NSArray *)arguments callback:(SEL)selector listener:(id)object{
    NSTask *temp = [NSTask new];
    objc_setAssociatedObject(temp, &kLockKey, [NSConditionLock new], OBJC_ASSOCIATION_RETAIN);
    [temp setLaunchPath:path];
    [temp setArguments:arguments];
    [temp setListener:object];
    [temp setCallback:selector];
    [temp setStandardOutput:[NSPipe pipe]];
    [temp setStandardError:temp.standardOutput];
    [temp performSelectorInBackground:@selector(read:) withObject:[temp.standardOutput fileHandleForReading]];
    return temp;
}
-(void)launchAndWait{
    NSConditionLock *cond = objc_getAssociatedObject(self, &kLockKey);
    [cond waitOn:2];
    [self launch];
    [self waitUntilExit];
    [cond waitOn:0];
}
-(void)read:(NSFileHandle *)handle{
    NSData *data;
    NSConditionLock *cond = objc_getAssociatedObject(self, &kLockKey);
    [cond increment];
    if (self.standardOutput == self.standardError) [cond increment];
    while ((data = [handle availableData])){
        if (!data.length) break;
        if (self.listener)
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self.listener performSelector:self.callback withObject:data];
            #pragma clang diagnostic pop
    }
    [cond decrement];
    if (self.standardOutput == self.standardError) [cond decrement];
}

@end

@implementation AScript

+(NSString *)tempFile:(NSString *)template{
    char *temp = (char *)[[NSTemporaryDirectory() stringByAppendingPathComponent:template] fileSystemRepresentation];
    close(mkstemps(temp, (int)template.pathExtension.length+1));
    unlink(temp);
    return [NSFileManager.defaultManager stringWithFileSystemRepresentation:temp length:strlen(temp)];
}

+(NSAppleEventDescriptor *)adminExec:(NSString *)command{
    NSDictionary *error;
    NSAppleEventDescriptor *evt = [[[NSAppleScript alloc] initWithSource:[NSString stringWithFormat:@"do shell script \"%@\" with administrator privileges", command]] executeAndReturnError:&error];
    ModalErrorWithDict(error);
    return evt;
}
+(NSAppleEventDescriptor *)loadKext:(NSString *)kext{
    NSError *err;
    NSString *path = [AScript tempFile:@"DPCIXXXXX.kext"];
    if (![NSFileManager.defaultManager copyItemAtPath:kext toPath:path error:&err])
    if (ModalError(err)) return nil;
    [self recursivePermissions:path files:0644 directories:0755];
    return [self adminExec:[NSString stringWithFormat:@"/usr/sbin/chown -R 0:0 '%@';/sbin/kextload '%@';while :;do if kill -0 %d;then sleep 5;else /sbin/kextunload '%@';/bin/rm -rf '%@';break;fi;done &>/dev/null&", path, path, NSProcessInfo.processInfo.processIdentifier, path, path]];
}
+(void)recursivePermissions:(NSString *)path files:(short)files directories:(short)directories{
    BOOL isDir;
    NSFileManager *mgr = NSFileManager.defaultManager;
    NSDictionary *file = @{NSFilePosixPermissions:[NSNumber numberWithShort:files]};
    NSDictionary *directory = @{NSFilePosixPermissions:[NSNumber numberWithShort:directories]};
    if ([mgr fileExistsAtPath:path isDirectory:&isDir] && isDir)
        [mgr setAttributes:directory ofItemAtPath:path error:nil];
    else
        [mgr setAttributes:file ofItemAtPath:path error:nil];
    for(__strong NSString *item in [mgr enumeratorAtPath:path]) {
        item = [path stringByAppendingPathComponent:item];
        if ([mgr fileExistsAtPath:item isDirectory:&isDir] && isDir)
            [mgr setAttributes:directory ofItemAtPath:item error:nil];
        else
            [mgr setAttributes:file ofItemAtPath:item error:nil];
    }
}

@end

@implementation URLTask

@synthesize connection;
@synthesize hold;
@synthesize progress;
@synthesize successBlock;
@synthesize errorBlock;

+(NSURL *)getURL:(NSString *)url withQuery:(NSDictionary *)dict{
    NSMutableArray *temp = [NSMutableArray array];
    for (NSString *key in dict)
        [temp addObject:[NSString stringWithFormat:@"%@=%@", [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], [[dict objectForKey:key] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@", url, [temp componentsJoinedByString:@"&"]]];
}
+(NSDictionary *)getMACs{
    struct ifaddrs *addrs;
    if (getifaddrs(&addrs)) return nil;
    NSMutableDictionary *macs = [NSMutableDictionary dictionary];
    struct ifaddrs *current = addrs;
    while (current) {
        struct sockaddr_dl *addr = (struct sockaddr_dl *)current->ifa_addr;
        if (current->ifa_addr->sa_family == AF_LINK && addr->sdl_type == IFT_ETHER) {
            [macs setObject:[NSString stringWithFormat:@"%02hhX:%02hhX:%02hhX:%02hhX:%02hhX:%02hhX", addr->sdl_data[addr->sdl_nlen], addr->sdl_data[addr->sdl_nlen+1], addr->sdl_data[addr->sdl_nlen+2], addr->sdl_data[addr->sdl_nlen+3], addr->sdl_data[addr->sdl_nlen+4], addr->sdl_data[addr->sdl_nlen+5]] forKey:[[NSString alloc] initWithBytes:addr->sdl_data length:addr->sdl_nlen encoding:NSASCIIStringEncoding]];
        }
        current = current->ifa_next;
    }
    freeifaddrs(addrs);
    return [macs copy];
}

+(bool)conditionalGet:(NSURL *)url toFile:(NSString *)file{
    NSError *err;
    NSDate *filemtime = [[NSFileManager.defaultManager attributesOfItemAtPath:file error:&err] fileModificationDate];
    if (ModalError(err)) return false;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"HEAD"];
    NSHTTPURLResponse *response;
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&err];
    if (ModalError(err)) return false;
    NSString *urlmstr = [response.allHeaderFields objectForKey:@"Last-Modified"];
    NSDateFormatter *df = [NSDateFormatter new];
    [df setDateFormat:@"EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"];
    [df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
    [df setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
    NSDate *urlmtime = [df dateFromString:urlmstr];
    bool changed = ([filemtime compare:urlmtime] == NSOrderedAscending);
    if (changed)
        if (![[NSData dataWithContentsOfURL:url] writeToFile:file options:NSDataWritingAtomic error:&err])
            if (ModalError(err)) return false;
    if (![NSFileManager.defaultManager setAttributes:@{NSFileModificationDate: urlmtime} ofItemAtPath:file error:&err])
        if (ModalError(err)) return false;
    return changed;
}

+(URLTask *)asyncUpload:(NSURLRequest *)request withMode:(NSString *)mode onSuccess:(void(^)(NSData *data))successBlock onError:(void(^)(NSError *error))errorBlock{
    URLTask *temp = [URLTask new];
    temp.successBlock = successBlock;
    temp.errorBlock = errorBlock;
    temp.connection = [[NSURLConnection alloc] initWithRequest:request delegate:temp startImmediately:false];
    [temp.connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:!mode?NSDefaultRunLoopMode:mode];
    [temp.connection start];
    return temp;
}
#pragma mark NSURLConnectionDataDelegate
-(void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite{
    self.progress = @(totalBytesWritten*100/totalBytesExpectedToWrite);
}

#pragma mark NSURLConnectionDelegate
-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
    if (!hold) hold = [NSMutableData data];
    [hold appendData:data];
}
-(void)connectionDidFinishLoading:(NSURLConnection *)connection{
    self.progress = nil;
    successBlock([NSData dataWithData:hold]);
}
-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
    self.progress = nil;
    errorBlock(error);
}

@end

@implementation NSConditionLock (NSTaskAdditions)

-(void)waitOn:(NSUInteger)condition{
    [self lockWhenCondition:condition];
    [self unlockWithCondition:condition];
}
-(void)setCondition:(NSInteger)condition{
    [self lock];
    [self unlockWithCondition:condition];
}
-(void)increment{
    [self lock];
    [self unlockWithCondition:self.condition+1];
}
-(void)decrement{
    [self lock];
    [self unlockWithCondition:self.condition-1];
}

@end

@implementation NSAlert (HyperlinkAdditions)

+(NSTextView *)hyperlink:(NSString *)hyperlink title:(NSString *)title{
    NSDictionary *link = @{NSFontAttributeName:[NSFont systemFontOfSize:NSFont.smallSystemFontSize], NSLinkAttributeName:hyperlink, NSForegroundColorAttributeName:[NSColor blueColor], NSUnderlineStyleAttributeName:@(NSSingleUnderlineStyle)};
    CGSize size = [title sizeWithAttributes:link];
    NSTextView *temp = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
    [temp.textStorage setAttributedString:[[NSAttributedString alloc] initWithString:title attributes:link]];
    [temp setEditable:false];
    [temp setDrawsBackground:false];
    return temp;
}
+(NSAlert *)alertWithMessageTextAndView:(NSString *)message defaultButton:(NSString *)defaultButton alternateButton:(NSString *)alternateButton otherButton:(NSString *)otherButton accessoryView:(NSView *)view informativeTextWithFormat:(NSString *)format, ...{
    va_list args;
    va_start(args, format);
    NSAlert *temp = [NSAlert alertWithMessageText:message defaultButton:defaultButton alternateButton:alternateButton otherButton:otherButton informativeTextWithFormat:@"%@", [[NSString alloc] initWithFormat:format arguments:args]];
    va_end(args);
    [temp setAccessoryView:view];
    return temp;
}

@end