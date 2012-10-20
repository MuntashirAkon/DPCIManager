//
//  Task.m
//  DPCIManager
//
//  Created by PHPdev32 on 10/13/12.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "Task.h"
#import "AppDelegate.h"
#import <objc/runtime.h>

static char kCallbackKey;
static char kListenerKey;

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

+(NSTask *)create:(NSString *)path args:(NSArray *)arguments callback:(SEL)selector listener:(id)object{
    NSTask *temp = [NSTask new];
    [temp setLaunchPath:path];
    [temp setArguments:arguments];
    [temp setListener:object];
    [temp setCallback:selector];
    [temp setStandardError:[NSPipe pipe]];
    [temp setStandardOutput:[NSPipe pipe]];
    [[temp.standardError fileHandleForReading] readInBackgroundAndNotify];
    [[temp.standardOutput fileHandleForReading] readInBackgroundAndNotify];
    [[NSNotificationCenter defaultCenter] addObserver:temp selector:@selector(read:) name:NSFileHandleReadCompletionNotification object:nil];
    return temp;
}
-(void)launchAndWait{
    [self launch];
    [self waitUntilExit];
    [self clean];
}
-(void)close{
    [self terminate];
    [self clean];
}
-(void)clean{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:nil];
    objc_removeAssociatedObjects(self);
}
-(void)read:(NSNotification *)aNotification{
    if (self.listener == nil) return;
    NSData *dat = [[aNotification userInfo] objectForKey:@"NSFileHandleNotificationDataItem"];
    if ([dat length] == 0) return;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self.listener performSelector:self.callback withObject:dat];
#pragma clang diagnostic pop
    [[aNotification object] readInBackgroundAndNotify];
}

@end

@implementation AScript

+(NSString *)tempFile{
    char *temp = (char *)[[NSTemporaryDirectory() stringByAppendingPathComponent:@"DPCIXXXXX.kext"] fileSystemRepresentation];
    close(mkstemps(temp, 5));
    unlink(temp);
    return [NSString stringWithUTF8String:temp];
}

+(NSAppleEventDescriptor *)adminExec:(NSString *)command{
    __autoreleasing NSDictionary *err;
    NSAppleEventDescriptor *evt = [[[NSAppleScript alloc] initWithSource:[NSString stringWithFormat:@"do shell script \"%@\" with administrator privileges", command]] executeAndReturnError:&err];
    [AppDelegate modalErrorWithDict:err];
    return evt;
}
+(NSAppleEventDescriptor *)loadKext:(NSString *)kext{
    NSError *error;
    NSString *path = [AScript tempFile];
    [[NSFileManager defaultManager] copyItemAtPath:kext toPath:path error:&error];
    [AppDelegate modalError:error];
    if (error != nil) return nil;
    __autoreleasing NSDictionary *err;
    NSAppleEventDescriptor *evt = [[[NSAppleScript alloc] initWithSource:[NSString stringWithFormat:@"do shell script \"/usr/sbin/chown -R 0:0 %@;/sbin/kextload '%@';while :;do if kill -0 %d;then sleep 5;else /sbin/kextunload '%@';/bin/rm -rf '%@';break;fi;done &>/dev/null&\" with administrator privileges", path, path, [[NSProcessInfo processInfo] processIdentifier], path, path]] executeAndReturnError:&err];
    [AppDelegate modalErrorWithDict:err];
    return evt;
}

@end

@implementation URLTask

+(bool)conditionalGet:(NSURL *)url toFile:(NSString *)file{
    NSError *err;
    NSDate *filemtime = [[[NSFileManager defaultManager] attributesOfItemAtPath:file error:&err] fileModificationDate];
    [AppDelegate modalError:err];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"HEAD"];
    NSHTTPURLResponse *response;
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&err];
    [AppDelegate modalError:err];
    NSString *urlmstr = [[response allHeaderFields] objectForKey:@"Last-Modified"];
    NSDateFormatter *df = [NSDateFormatter new];
    [df setDateFormat:@"EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"];
    [df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
    [df setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
    NSDate *urlmtime = [df dateFromString:urlmstr];
    if ([filemtime laterDate:urlmtime] == urlmtime){
        [[NSData dataWithContentsOfURL:url] writeToFile:file atomically:true];
        [[NSFileManager defaultManager] setAttributes:@{NSFileModificationDate: urlmtime} ofItemAtPath:file error:&err];
        [AppDelegate modalError:err];
        return true;
    }
    else {
        [[NSFileManager defaultManager] setAttributes:@{NSFileModificationDate: urlmtime} ofItemAtPath:file error:&err];
        [AppDelegate modalError:err];
        return false;
    }
}

@end