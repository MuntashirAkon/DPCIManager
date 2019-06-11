//
//  AppDelegate.h
//  DPCIManager
//
//  Created by PHPdev32 on 9/12/12.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

@class Match;

typedef struct {
	UInt32 core;
	UInt32 index;
	UInt32 hi;
	UInt32 lo;
} msrcmd_t;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSPanel *panel;
@property (assign) IBOutlet NSPopover *pop;
@property (assign) IBOutlet NSPopUpButton *nodeLocation;
@property (assign) IBOutlet NSWindow *reporter;
@property NSMutableDictionary *report;
@property NSMutableData *flashout;
@property Match *match;
@property NSConditionLock *cond;
@property NSArray *matches;
@property NSString *patch;
@property NSString *bdmesg;
@property NSTask *watcher;
@property NSMutableArray *log;
@property NSArray *pcis;
@property NSDictionary *status;

-(IBAction)updateIDs:(id)sender;
-(IBAction)dumpTables:(id)sender;
-(IBAction)dumpDsdt:(id)sender;
-(IBAction)ethString:(id)sender;
-(IBAction)fetchKext:(id)sender;
-(IBAction)repair:(id)sender;
-(IBAction)rebuild:(id)sender;
-(IBAction)install:(id)sender;
-(IBAction)fetchvBIOS:(id)sender;
-(IBAction)savePCIInfo:(id)sender;
-(void)logTask:(NSData *)data;

@end
