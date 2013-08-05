//
//  Hardware.h
//  DPCIManager
//
//  Created by PHPdev32 on 3/29/13.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "AppDelegate.h"
#define kStubMAC @"88:88:88:88:87:88"

@interface AppDelegate (HardwareAdditions)

+(bool)securityCheck;
+(void)acpitables:(NSString *)only;
+(bool)checkDirect;
+(NSString *)bdmesg;
+(NSDictionary *)readHardware;
+(NSURL *)findKext:(NSString *)bundle;

@end