//
//  AppDelegate.h
//  DPCIManager
//
//  Created by PHPdev32 on 9/12/12.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import <Cocoa/Cocoa.h>
#import "Tables.h"
#import <IOKit/kext/KextManager.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSToolbarItem *submitButton;
@property NSString *file;
@property NSString *pciFormat;
@property NSMutableArray *pcis;
@property NSMutableDictionary *status;
@property NSMutableDictionary *vendors;
@property NSMutableDictionary *classes;

-(IBAction)update:(id)sender;
-(IBAction)submit:(id)sender;
-(IBAction)dumpTables:(id)sender;
-(IBAction)dumpDsdt:(id)sender;
-(IBAction)fetchKext:(id)sender;

@end

@interface pciDevice : NSObject

@property NSNumber *vendor;
@property NSNumber *device;
@property NSNumber *subVendor;
@property NSNumber *subDevice;
@property NSNumber *pciClassCode;
@property NSNumber *pciClass;
@property NSNumber *pciSubClass;
@property NSString *vendorString;
@property NSString *deviceString;
@property NSString *classString;
@property NSString *subClassString;
@property (nonatomic) NSString *fullClassString;

+(NSNumber *)grabEntry:(CFStringRef)entry forService:(io_service_t)service;
+(NSDictionary *)match:(pciDevice *)pci;
+(pciDevice *)create:(io_service_t)service;
-(NSString *)fullClassString;

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