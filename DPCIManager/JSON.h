//
//  JSON.h
//  DPCIManager
//
//  Created by Muntashir Al-Islam on 8/18/18.
//  See: https://stackoverflow.com/a/20262259/4147849
//

#ifndef JSON_h
#define JSON_h

@interface NSDictionary (BVJSONString)
-(NSString*) bv_jsonStringWithPrettyPrint:(BOOL) prettyPrint;
@end

@interface NSArray (BVJSONString)
- (NSString *)bv_jsonStringWithPrettyPrint:(BOOL)prettyPrint;
@end

#endif /* JSON_h */
