//
//  Match.h
//  DPCIManager
//
//  Created by PHPdev32 on 10/12/12.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "PCI.h"

@interface Match : NSObject

@property NSDictionary *seed;
@property NSDictionary *native;

+(Match *)create;
-(NSArray *)match:(pciDevice *)device;

@end

@interface matchFormatter : NSValueTransformer
+(BOOL)allowsReverseTransformation;
+(Class)transformedValueClass;
-(id)transformedValue:(id)value;
@end