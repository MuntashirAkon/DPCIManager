//
//  Task.h
//  DPCIManager
//
//  Created by PHPdev32 on 10/13/12.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

@interface NSTask (TaskAdditions)

@property SEL callback;
@property id listener;

+(NSTask *)create:(NSString *)path args:(NSArray *)arguments callback:(SEL)selector listener:(id)object;
-(void)launchAndWait;
-(void)close;
-(void)read:(NSNotification *)aNotification;

@end

@interface AScript : NSObject

+(NSAppleEventDescriptor *)adminExec:(NSString *)command;
+(NSAppleEventDescriptor *)loadKext:(NSString *)path;

@end

@interface URLTask

+(bool)conditionalGet:(NSURL *)url toFile:(NSString *)file;

@end