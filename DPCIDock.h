/* DPCIDock */

#import <Cocoa/Cocoa.h>

#if MAC_OS_X_VERSION_MIN_REQUIRED == MAC_OS_X_VERSION_10_4
typedef int NSInteger;
#endif

typedef struct pci_devices_tab
{
	unsigned int vendor_id;
	unsigned int device_id;
	unsigned int device_class;
	
} pci_devices_tab_t;

typedef struct device_tab
{
	unsigned int id;
	char *name;
	struct device_tab *next;
} device_tab_t;


typedef struct vendor_tab
{
	unsigned int id;
	char *name;
	device_tab_t	*devices;
	struct vendor_tab *next;
} vendor_tab_t;

typedef struct subclass_tab
{
	unsigned int id;
	char *name;
	struct subclass_tab *next;
} subclass_tab_t;

typedef struct class_tab
{
	unsigned int id;
	char *name;
	subclass_tab_t	*subclasses;
	struct class_tab *next;
} class_tab_t;


@interface DPCIDock : NSObject
{
	IBOutlet NSTableView	*pciTableView;
	IBOutlet NSTextField	*pciClass;
    IBOutlet id             submitButton;
    IBOutlet id             updateButton;
	
	pci_devices_tab_t		pciDevs[100];
	int						pciDevsCount;
}
-(IBAction)tableClick:(id)sender;
-(IBAction)update:(id)sender;
-(IBAction)submit:(id)sender;
-(void)updateDetails;
@end
