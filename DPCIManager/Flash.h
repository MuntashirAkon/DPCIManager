//
//  Flash.h
//  DPCIManager
//
//  Created by PHPdev32 on 3/29/13.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "AppDelegate.h"
enum flashromstatus {
    success,
    failure,
    nonfatal,
    critical
};

@interface AppDelegate (FlashingAdditions)

-(IBAction)readROM:(id)sender;
-(IBAction)writeROM:(id)sender;
-(IBAction)testROM:(id)sender;
-(IBAction)patchROM:(id)sender;
-(IBAction)autopatchROM:(id)sender;
-(IBAction)patchflashROM:(id)sender;
-(IBAction)cancelReport:(id)sender;
-(IBAction)submitReport:(id)sender;

@end
