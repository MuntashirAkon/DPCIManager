//
//  pci.h
//  DPCIManager
//
//  Created by PHPdev32 on 10/8/12.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import <Cocoa/Cocoa.h>

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
@property (nonatomic) long fullID;
@property (nonatomic) long fullSubID;

+(NSNumber *)grabEntry:(CFStringRef)entry forService:(io_service_t)service;
+(NSDictionary *)match:(pciDevice *)pci;
+(pciDevice *)create:(io_service_t)service classes:(NSMutableDictionary *)classes vendors:(NSMutableDictionary *)vendors;
+(pciDevice *)create:(io_service_t)service;
-(NSString *)fullClassString;
-(long)fullID;
-(long)fullSubID;
+(NSArray *)readIDs;

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