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
#import "PCI.h"
#import "Match.h"
#import "Task.h"
#define kSLE @"/System/Library/Extensions"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSPanel *panel;
@property (assign) IBOutlet NSPopover *pop;
@property Match *match;
@property NSArray *matches;
@property NSString *file;
@property NSString *pciFormat;
@property NSString *patch;
@property NSTask *watcher;
@property NSMutableArray *log;
@property NSArray *pcis;
@property NSDictionary *status;

+(void)modalErrorWithDict:(NSDictionary *)err;
+(void)modalError:(NSError *)err;

-(IBAction)updateIDs:(id)sender;
-(IBAction)updateSeed:(id)sender;
-(IBAction)submit:(id)sender;
-(IBAction)dumpTables:(id)sender;
-(IBAction)dumpDsdt:(id)sender;
-(IBAction)fetchKext:(id)sender;
-(IBAction)patchNode:(id)sender;
-(IBAction)msrDumper:(id)sender;
-(IBAction)repair:(id)sender;
-(IBAction)rebuild:(id)sender;
-(IBAction)install:(id)sender;
-(IBAction)fetchCMOS:(id)sender;
-(IBAction)readROM:(id)sender;
-(IBAction)writeROM:(id)sender;
-(IBAction)testROM:(id)sender;

@end