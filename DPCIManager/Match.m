//
//  Match.m
//  DPCIManager
//
//  Created by PHPdev32 on 10/12/12.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "Match.h"
#import "PCI.h"

#define kSeed 100
#define kNative 101
#define kIOPCIMatch 0
#define kIOPCIPrimaryMatch 1
#define kIOPCISecondaryMatch 2
#define kIOPCIClassMatch 3
#define kIOPropertyMatch 4
#define kIONameMatch 5
#define kIOResourceMatch 6
#define kIOParentMatch 7
#define kIOPathMatch 8
#define kIOProviderClass 9


@implementation Match
static NSArray *matchKeys;
@synthesize seed;
@synthesize native;

+(void)initialize{
    matchKeys = @[@"IOPCIMatch", @"IOPCIPrimaryMatch", @"IOPCISecondaryMatch", @"IOPCIClassMatch", //PCI
    @"IOPropertyMatch", @"IONameMatch", @"IOResourceMatch", @"IOParentMatch", @"IOPathMatch"/*, @"IOProviderClass"*/];//OF
}
+(Match *)create{
    Match *temp = [Match new];
    temp.seed = [NSDictionary dictionaryWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"seed" ofType:@"plist"]];
    NSMutableDictionary *kexts = [NSMutableDictionary dictionary];
    NSDirectoryEnumerator *iterator = [NSFileManager.defaultManager enumeratorAtPath:kSLE];
    NSString *path;
    NSDictionary *personalities;
    NSString *name;
    while ((path = iterator.nextObject))
        if ([path.lastPathComponent isEqualToString:@"Info.plist"])
            if ((personalities = [Match personalities:[NSString stringWithFormat:@"%@/%@", kSLE, path]]))
                for (NSString *personality in personalities) {
                    if ((name = [NSString stringWithFormat:@"%@:%@", [self kextNameFromPath:path], personality]) && ![kexts objectForKey:name])
                    [kexts setObject:[personalities objectForKey:personality] forKey:name];
                    else
                        [kexts setObject:[[NSSet setWithArray:[[kexts objectForKey:name] arrayByAddingObjectsFromArray:[personalities objectForKey:personality]]] allObjects] forKey:name];
                }
    temp.native = [kexts copy];
    return temp;
}
+(NSDictionary *)personalities:(NSString *)path{
    NSDictionary *personalities = [[NSDictionary dictionaryWithContentsOfFile:path] objectForKey:@"IOKitPersonalities"];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (NSString *personality in personalities) {
        NSMutableArray *temp = [NSMutableArray array];
        __block NSUInteger index;
        [[personalities objectForKey:personality] enumerateKeysAndObjectsUsingBlock:^void(id key, id obj, BOOL *stop){
            index = [matchKeys indexOfObject:key];
            if (index != NSNotFound)
                [temp addObject:@{[NSString stringWithFormat:@"%ld", index]:obj}];
        }];
        if (temp.count > 0) [dict setObject:[temp copy] forKey:personality];
    }
    return !dict.count?nil:[dict copy];
}
+(NSString *)kextNameFromPath:(NSString *)path{
    for (NSString *component in path.pathComponents.reverseObjectEnumerator)
        if ([component hasSuffix:@".kext"])
            return component;
    return @"";
}
+(bool)masked:(pciDevice *)device as:(NSUInteger)type to:(NSString *)masked{
    if (type == kIOPCIMatch) return ([Match masked:device as:kIOPCIPrimaryMatch to:masked] || [Match masked:device as:kIOPCISecondaryMatch to:masked]);
    if ([masked rangeOfString:@"&"].location != NSNotFound){
        NSArray *temp = [masked componentsSeparatedByString:@"&"];
        long candidate = strHexDec([temp objectAtIndex:0]), mask = strHexDec([temp objectAtIndex:1]);
        switch (type) {
            case kIOPCIPrimaryMatch:
                if (device.vendor.integerValue != (candidate&0x0000FFFF)) return false;
                return ((device.fullID&mask) == candidate);
                break;
            case kIOPCISecondaryMatch:
                if (device.subVendor.integerValue != (candidate&0x0000FFFF)) return false;
                return ((device.fullSubID&mask) == candidate);
                break;
        }
        return false;
    }
    else
        return [self PCI:device to:strHexDec(masked)];
}
+(bool)class:(pciDevice *)device to:(NSString *)class{
    if ([class rangeOfString:@"&"].location != NSNotFound){
        NSArray *temp = [class componentsSeparatedByString:@"&"];
        return (((device.pciClassCode.integerValue<<8)&strHexDec([temp objectAtIndex:1])) == strHexDec([temp objectAtIndex:0]));
    }
    else {
        return ((device.pciClassCode.integerValue<<8) == strHexDec(class));
    }
}
+(bool)PCI:(pciDevice *)device to:(NSUInteger)candidate{
    if ([device.vendor integerValue] != (candidate&0x0000FFFF)) return false;
    return NSLocationInRange(((device.fullID&0xFFFF0000)>>0x10), NSMakeRange(((candidate&0xFFFF0000)>>0x10)-0x8, 0x10));
}
+(bool)name:(pciDevice *)device to:(NSString *)candidate{
    long ids = [pciDevice nameToLong:candidate];
    return ids?[self PCI:device to:ids]:false;
    //TODO: more matches
}
-(NSArray *)match:(pciDevice *)device{
    return [[NSArray arrayWithArray:[self find:device in:seed as:kSeed]] arrayByAddingObjectsFromArray:[self find:device in:native as:kNative]];
}
-(NSArray *)find:(pciDevice *)device in:(NSDictionary *)catalogue as:(NSUInteger)type{
    NSMutableArray *matches = [NSMutableArray array];
    NSArray *temp;
    NSString *temp1;
    for (NSString *kext in catalogue) {
        NSMutableArray *submatches = [NSMutableArray array];
        for (NSDictionary *match in [catalogue objectForKey:kext]) {
            for (NSNumber *predicate in match.allKeys) {
                switch (predicate.integerValue) {
                    case kIOPCIMatch:
                    case kIOPCIPrimaryMatch:
                    case kIOPCISecondaryMatch:
                        temp1 = [[[match objectForKey:predicate] stringByReplacingOccurrencesOfString:@"\n" withString:@""] stringByReplacingOccurrencesOfString:@"\t" withString:@""];
                        if ([temp1 rangeOfString:@" "].location != NSNotFound)
                            temp = [temp1 componentsSeparatedByString:@" "];
                        else temp = [NSArray arrayWithObject:temp1];
                        for (NSString *submatch in temp)
                            if ([Match masked:device as:predicate.integerValue to:submatch])
                                [submatches addObject:@{@"type":predicate, @"name":submatch}];
                        break;
                    case kIOPCIClassMatch:
                        if ([Match class:device to:[match objectForKey:predicate]])
                            [submatches addObject:@{@"type":predicate, @"name":[match objectForKey:predicate]}];
                    case kIONameMatch:
                        if (![[match objectForKey:predicate] isKindOfClass:[NSArray class]])
                            temp = [NSArray arrayWithObject:[match objectForKey:predicate]];
                        else temp = [match objectForKey:predicate];
                        for (NSString *submatch in temp)
                            if ([Match name:device to:submatch])
                                [submatches addObject:@{@"type":predicate, @"name":submatch}];
                        break;
                }
            }
        }
        if (submatches.count == [[catalogue objectForKey:kext] count]) [matches addObject:@{@"type":@(type), @"name":kext, @"children":[submatches copy]}];
    }
    return matches;
}

@end

@implementation matchFormatter
+(BOOL)allowsReverseTransformation {
    return false;
}
+(Class)transformedValueClass {
    return [NSImage class];
}
-(id)transformedValue:(id)value {
    if (!value) return nil;
    switch ([value integerValue]){
        case kSeed:
            return [NSImage imageNamed:NSImageNameNetwork];
            break;
        case kNative:
            return [NSImage imageNamed:NSImageNameComputer];
            break;
        case kIOPCIMatch:
            return [NSImage imageNamed:NSImageNameEveryone];
            break;
        case kIOPCIPrimaryMatch:
            return [NSImage imageNamed:NSImageNameUser];
            break;
        case kIOPCISecondaryMatch:
            return [NSImage imageNamed:NSImageNameUserGroup];
            break;
        case kIOPCIClassMatch:
            return [NSImage imageNamed:NSImageNameHomeTemplate];
            break;
        case kIONameMatch:
            return [NSImage imageNamed:NSImageNameBookmarksTemplate];
            break;
    }
    return nil;
}
@end