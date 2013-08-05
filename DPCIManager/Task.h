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

+(NSString *)launchAndOut:(NSString *)path args:(NSArray *)arguments;
+(NSTask *)create:(NSString *)path args:(NSArray *)arguments callback:(SEL)selector listener:(id)object;
+(NSTask *)createSingle:(NSString *)path args:(NSArray *)arguments callback:(SEL)selector listener:(id)object;
-(void)launchAndWait;
-(void)read:(NSNotification *)aNotification;

@end

@interface AScript : NSObject

+(NSString *)tempFile:(NSString *)template;
+(NSAppleEventDescriptor *)adminExec:(NSString *)command;
+(NSAppleEventDescriptor *)loadKext:(NSString *)path;

@end

@interface URLTask : NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property NSURLConnection *connection;
@property NSMutableData *hold;
@property NSNumber *progress;
@property (copy, nonatomic) void (^successBlock)(NSData *data);
@property (copy, nonatomic) void (^errorBlock)(NSError *error);

+(bool)conditionalGet:(NSURL *)url toFile:(NSString *)file;
+(NSDictionary *)getMACs;
+(NSURL *)getURL:(NSString *)url withQuery:(NSDictionary *)dict;
+(URLTask *)asyncUpload:(NSURLRequest *)request withMode:(NSString *)mode onSuccess:(void(^)(NSData *data))successBlock onError:(void(^)(NSError *error))errorBlock;

@end

@interface NSConditionLock (NSTaskAdditions)

-(void)waitOn:(NSUInteger)condition;
-(void)setCondition:(NSInteger)condition;
-(void)increment;
-(void)decrement;

@end

@interface NSAlert (HyperlinkAdditions)

+(NSTextView *)hyperlink:(NSString *)hyperlink title:(NSString *)title;
+(NSAlert *)alertWithMessageTextAndView:(NSString *)message defaultButton:(NSString *)defaultButton alternateButton:(NSString *)alternateButton otherButton:(NSString *)otherButton accessoryView:(NSView *)view informativeTextWithFormat:(NSString *)format, ...;

@end