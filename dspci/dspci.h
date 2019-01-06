//
//  dspci.h
//  dspci
//
//  Created by Muntashir Al-Islam on 8/20/18.
//

#ifndef dspci_h
#define dspci_h

#import "DDCommandLineInterface.h"
#define CURRENT_MARKETING_VERSION "1.9"

@interface DSPCI : NSObject <DDCliApplicationDelegate>
{
    BOOL _listDataTypes;
    BOOL _json;
    BOOL _version;
    BOOL _help;
}

@end

#endif /* dspci_h */
