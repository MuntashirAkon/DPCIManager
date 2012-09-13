//
//  AppDelegate.h
//  DPCIManager
//
//  Created by PHPdev32 on 9/12/12.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSToolbarItem *submitButton;
@property NSString *file;
@property NSArray *pcis;
@property NSDictionary *vendors;
@property NSDictionary *classes;

-(IBAction)update:(id)sender;
-(IBAction)submit:(id)sender;

@end

@interface pciDevice : NSObject

@property NSNumber *vendor;
@property NSNumber *device;
@property NSNumber *subVendor;
@property NSNumber *subDevice;
@property NSNumber *pciClassCode;
@property NSNumber *pciClass;
@property NSNumber *pciSubClass;
@property (nonatomic) NSString *vendorString;
@property (nonatomic) NSString *deviceString;
@property (nonatomic) NSString *classString;
@property (nonatomic) NSString *subClassString;
@property (nonatomic) NSString *fullClassString;

+(pciDevice *)create:(io_service_t)service;

@end

@interface pciVendor : NSObject
@property NSString *name;
@property NSMutableDictionary *devices;
+(pciVendor *)create:(NSString *)name;
@end

@interface pciClass : NSObject
@property NSString *name;
@property NSMutableDictionary *subClasses;
+(pciClass *)create:(NSString *)name;
@end

@interface hexFormatter : NSValueTransformer
+(BOOL)allowsReverseTransformation;
+(Class)transformedValueClass;
-(id)transformedValue:(id)value;
@end