//
//  DataTypeHandler.h
//  DPCIManager
//
//  Created by Muntashir Al-Islam on 8/20/18.
//

#ifndef DataTypeHandler_h
#define DataTypeHandler_h

#import "DDCommandLineInterface.h"

#define DTH_HANDLE_DEFAULT @"" // Same as DT_LIST_DEFAULT

@interface DataTypeHandler : NSObject {
    // PCI related
    NSMutableDictionary *classes;
    NSMutableDictionary *vendors;
    NSMutableArray *devices;
    
    NSString *fetchDate;
    unsigned dataType; // ...
    @public
    // Arguments
    BOOL printJSON;
}

- (int) handleDataType: (NSString *)dataType;
@end
#endif /* DataTypeHandler_h */
