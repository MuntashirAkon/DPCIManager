#import "DPCIDock.h"

FILE *file_in;

vendor_tab_t *vendors;

class_tab_t *classes;

@implementation DPCIDock

-(char *)vendorString:(int)vid
{
	vendor_tab_t *cur_vendor;
	cur_vendor = vendors->next;
	while(cur_vendor)
	{
		if(cur_vendor->id == vid)
			return cur_vendor->name;
		cur_vendor = cur_vendor->next;
	}
	return "ERROR: Unknown Vendor";
}

-(char *)classString:(int)cid
{
	class_tab_t *cur_class;
	cur_class = classes->next;
	while(cur_class)
	{
		if(cur_class->id == cid)
			return cur_class->name;
		cur_class = cur_class->next;
	}
	return "ERROR: Unknown Device Class";
}

-(char *)subclassString:(int)sid forClass:(int)cid
{
	class_tab_t *cur_class;
	subclass_tab_t *cur_subclass;
	
	cur_class = classes->next;
	while(cur_class)
	{
		if(cur_class->id == cid)
			break;
		cur_class = cur_class->next;
	}
	if (cur_class)
	{
		cur_subclass = cur_class->subclasses->next;
		while(cur_subclass)
		{
			if(cur_subclass->id == sid)
				return cur_subclass->name;
			cur_subclass=cur_subclass->next;
		}
	}
	
	return "ERROR: Unknown Device Subclass";
}

-(char *)deviceString:(int)did forVendor:(int)vid
{
	vendor_tab_t *cur_vendor;
	device_tab_t *cur_device;
	
	cur_vendor = vendors->next;
	while(cur_vendor)
	{
		if(cur_vendor->id == vid)
			break;
		cur_vendor = cur_vendor->next;
	}
	if (cur_vendor)
	{
		cur_device = cur_vendor->devices->next;
		while(cur_device)
		{
			if(cur_device->id == did)
				return cur_device->name;
			cur_device=cur_device->next;
		}
	}

	return "ERROR: Unknown Device";
}

- (bool) readLine:(char *) buffer
{
	char c;
	char *buf;
	
	buf = buffer;
	
	do
	{
		c = fgetc(file_in);
		if (c == 0x0a || c == 0x0d)
		{
			*buf++ = 0;
			return true;
		}
		if (c == '#')
			c = 0;
		*buf++ = c;
	} while(!feof(file_in));
	return false;
}

-(unsigned int) getNumber:(char *) buffer count:(int)cnt
{
	int i;
	char c;
	unsigned int val;
	char *buf;
	
	buf = buffer;
	
	val = 0;
	for (i = 0 ; i < cnt ; i++)
	{
		c = *buf++;
		//printf("%c", c);
		if (c >= '0' && c <= '9')
			c = c - '0';
		else if (c >= 'a' && c <= 'z')
			c = c - 'a' + 10;
		else if (c >= 'A' && c <= 'Z')
			c = c - 'A' + 10;
		else
			printf("ERROR CONVERTING TO NUMBER!: %s\n", buffer);
		if (c < 0)
			printf("ERROR CONVERTING TO NUMBER (NEGATIVE)!: %s\n", buffer);
		val = (val << 4) + c;
	}
	return val;
}

-(bool) readDB
{
	char buffer[256];
	// int i = 0;
	int len;
	int vendor_id, device_id;
	char c;
	char *buf;
	vendor_tab_t *cur_vendor;
	device_tab_t *cur_device;
	int class_parse;
	int cid;
	
	class_tab_t *cur_class;
	subclass_tab_t *cur_subclass;
	
	
	vendors = (vendor_tab_t *)malloc(sizeof(vendor_tab_t));
	cur_vendor = vendors;
	
	classes = (class_tab_t *)malloc(sizeof(class_tab_t));
	cur_class = classes;
	
	class_parse = 0;
	
	while([self readLine:buffer])
	{
		buf = buffer;
		len = strlen(buffer); 
		if (len > 4)
		{
			c = *buf;
			if (c == 'C')
			{
				// hack hack hack
				//break;
				class_parse = 1;
			}
			if (class_parse)
			{
				if (c == 'C')
					buf += 2;
				if (c == 0x09)
				{
					buf++;
					c = *buf;
					if (c == 0x09)
					{
					// subvendor, blah blah blah
					}
					else
					{
						cid = [self getNumber:buf count:2];
						buf += 4;
						while (*buf == ' ' || *buf == 0x09)
							buf++;
						len = strlen(buf);
						cur_subclass->next = (subclass_tab_t *)malloc(sizeof(subclass_tab_t));
						cur_subclass = cur_subclass->next;
						cur_subclass->id = cid;
						cur_subclass->next = NULL;
						cur_subclass->name = (char *)malloc(len+1);
						strcpy(cur_subclass->name, buf);
					}
				}
				else if (c == '\\')
				{
				// hack :)
				}
				else
				{
					cid = [self getNumber:buf count:2];
					buf += 4;
					while (*buf == ' ' || *buf == 0x09)
						buf++;
					len = strlen(buf);
					cur_class->next = (class_tab_t *)malloc(sizeof(class_tab_t));
					cur_class = cur_class->next;
					cur_class->id = cid;
					cur_class->next = NULL;
					cur_class->name = (char *)malloc(len+1);
					cur_class->subclasses = (subclass_tab_t *)malloc(sizeof(subclass_tab_t));
					cur_subclass = cur_class->subclasses;
					strcpy(cur_class->name, buf);
				}
			}
			else
			{
				if (c == 0x09)
				{
					buf++;
					c = *buf;
					if (c == 0x09)
					{
					// subvendor, blah blah blah
					}
					else
					{
						device_id = [self getNumber:buf count:4];
						buf += 4;
						while (*buf == ' ' || *buf == 0x09)
							buf++;
						len = strlen(buf);
						cur_device->next = (device_tab_t *)malloc(sizeof(device_tab_t));
						cur_device = cur_device->next;
						cur_device->id = device_id;
						cur_device->next = NULL;
						cur_device->name = (char *)malloc(len+1);
						strcpy(cur_device->name, buf);
					}
				}
				else if (c == '\\')
				{
				// hack :)
			}
				else
				{
					vendor_id = [self getNumber:buf count:4];
					buf += 4;
					while (*buf == ' ' || *buf == 0x09)
						buf++;
					len = strlen(buf);
					cur_vendor->next = (vendor_tab_t *)malloc(sizeof(vendor_tab_t));
					cur_vendor = cur_vendor->next;
					cur_vendor->id = vendor_id;
					cur_vendor->next = NULL;
					cur_vendor->name = (char *)malloc(len+1);
					cur_vendor->devices = (device_tab_t *)malloc(sizeof(device_tab_t));
					cur_device = cur_vendor->devices;
					strcpy(cur_vendor->name, buf);
				}
			}
		}
	}
	cur_vendor = vendors->next;
	while(cur_vendor)
	{
//		printf("Vendor %08x %s\n", cur_vendor->id, cur_vendor->name);
		cur_vendor = cur_vendor->next;
	}
	return 0;
}


char device_string[512];

void enumprops(CFTypeRef object)
{
	CFTypeID 	type;
/*	const void	**keys,**vals, *obj;
	CFTypeRef	key, val;
	int			n, k;
	const char 	*c; */
	
	if (!object) return;
	
	type=CFGetTypeID(object);
	//CFShow(object);
	if (type==CFArrayGetTypeID())
	{
		//printf( "array!\n" );
/*		n=CFArrayGetCount( object );
		for( k=0;k<n;++k )
		{
			obj=CFArrayGetValueAtIndex( object,k );
			enumprops(obj,j);
		}
*/		return;
	}
	else if (type==CFDictionaryGetTypeID())
	{
		//printf( "dictionery!\n" );
/*		macjoyelement(j,object);
		n=CFDictionaryGetCount( object );
		keys=(const void**)malloc( n*sizeof(void*) );
		vals=(const void**)malloc( n*sizeof(void*) );
		CFDictionaryGetKeysAndValues( object,keys,vals );
		for (k=0;k<n;++k)
		{
			key=keys[k];
			val=vals[k];
			type=CFGetTypeID(key);
			if (type==CFStringGetTypeID())
			{
				c=CFStringGetCStringPtr(key,CFStringGetSystemEncoding());
				if (c)
				{
//					printf("%s\n",c);
					enumprops(val,j);
				}
			}
			else
			{
//				printf( "<unknown keytype>\n");
			}
		}
		free( vals );
		free( keys );
*/		return;
	}
	else if (type==CFNumberGetTypeID())
	{
		//printf( "number!\n" );
	}
	else
	{
		//printf("unknown!!!\n");
	}
}

-(void)interrogateHardware
{
	// Local variables for kernel stuff
    kern_return_t err;
    mach_port_t masterPort;
    io_iterator_t itThis;
    io_service_t service;
    CFDataRef vendorID, deviceID, model;
	
	// Get a mach port for us and check for errors
    err = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if(err)
    {
		NSLog(@"Error: Could not get master port!");
		return;
    }

	/*
	    // Grab all the PCI devices out of the registry
    err = IOServiceGetMatchingServices(masterPort, IOServiceMatching(kServiceCategoryRTC), &itThis);
    if(err)
    {
		NSLog(@"Error: No matching services!");
		return;
    } 
	pciDevsCount = 0;
    // Yank everything out of the iterator
    while(1)
    {
		service = IOIteratorNext(itThis);
		if (service)
		{
			NSLog(@"Found found found!!!");
		}
		else 
			break;
	}	
	NSLog(@"Finished SCAN");
	return;
	*/
	
    // Grab all the PCI devices out of the registry
    err = IOServiceGetMatchingServices(masterPort, IOServiceMatching("IOPCIDevice"), &itThis);
    if(err)
    {
		NSLog(@"Error: No matching services!");
		return;
    } 
	pciDevsCount = 0;
	
    // Yank everything out of the iterator
    while(1)
    {
		service = IOIteratorNext(itThis);
		io_name_t dName;
		
		// Make sure we have a valid service
		if(service)
		{
			CFTypeRef	object;
			CFDictionaryRef	properties;

			/* CFDataRef	data; */
			err = IORegistryEntryCreateCFProperties(service, (CFMutableDictionaryRef *)&object, kCFAllocatorDefault, kNilOptions);
			if (err || !object) 
			{
				printf("IORegistryEntryCreateCFProperties failed, "
					   "kr=%d, object=0x%x\n", err, service);
				exit(0);
			}
			properties = (CFDictionaryRef)object;
			/*
			data = IOCFSerialize(properties, kNilOptions);
			if(data) {
				printf("properties = \"%s\"\n", CFDataGetBytePtr(data));
				CFRelease(data);
			}
			*/
			//printf("----- NEW DEVICE -----\n");
			void **keys;
			void **vals;
			int n;
			char *c = NULL;
			CFTypeRef	key,val;
			CFTypeID 	type;
			n=CFDictionaryGetCount( properties );
			keys=(void**)malloc( n*sizeof(void*) );
			vals=(void**)malloc( n*sizeof(void*) );
			CFDictionaryGetKeysAndValues( properties,(const void **)keys,(const void **)vals );
			int k;
			for (k=0;k<n;++k)
			{
				key=keys[k];
				val=vals[k];
				type=CFGetTypeID(key);
				if (type==CFStringGetTypeID())
				{
					c=(char *)CFStringGetCStringPtr(key,CFStringGetSystemEncoding());
					if (c)
					{
						//printf("%s :",c);
						enumprops(val);
					}
				}
				else
				{
					//printf( "<unknown keytype>\n");
				}
			}
			free( vals );
			free( keys );
			
			//CFDictionaryGetKeysAndValues(properties, keys, values);
			
			//int i;
			//for(i = 0 ; i < 10 ; i++)
			//	printf("%d %s %s\n", i, CFStringGetCStringPtr(keys[i], kCFStringEncodingNonLossyASCII), values[i]);
			
			CFRelease(properties);
			
			// Get the classcode so we know what we're looking at
			CFDataRef classCode =  IORegistryEntryCreateCFProperty(service,CFSTR("class-code"),kCFAllocatorDefault,0);
			// Only accept devices that are 
			// PCI Spec - 0x00030000 is a display device
			//if((*(UInt32*)CFDataGetBytePtr(classCode) & 0x00ff0000) == 0x00030000)
			{
				// If all that crap in the if() is true, then this is a display controller
//				serviceList[serviceCount++] = service;
				// Get the name of the service (hw)
				IORegistryEntryGetName(service, dName);
				
				vendorID = IORegistryEntryCreateCFProperty(service, CFSTR("vendor-id"),kCFAllocatorDefault,0);
				deviceID = IORegistryEntryCreateCFProperty(service, CFSTR("device-id"),kCFAllocatorDefault,0);
				model = IORegistryEntryCreateCFProperty(service, CFSTR("compatible"),kCFAllocatorDefault,0);
				CFDataRef irqline;
				irqline = IORegistryEntryCreateCFProperty(service, CFSTR("model"),kCFAllocatorDefault,0);
				//printf("COMPATIBLE %s\n", ((char*)CFDataGetBytePtr(model)));
				pciDevs[pciDevsCount].vendor_id = *((UInt32*)CFDataGetBytePtr(vendorID));
				pciDevs[pciDevsCount].device_id = *((UInt32*)CFDataGetBytePtr(deviceID));
				pciDevs[pciDevsCount].device_class = *((UInt32*)CFDataGetBytePtr(classCode));
				pciDevsCount++;
				
//				printf("PCI: %s %04x %04x\n", dName, *((UInt32*)CFDataGetBytePtr(vendorID)), *((UInt32*)CFDataGetBytePtr(deviceID)));
				// Add this service to the list of available services
			}
		}
		else
			break;
	}
}	

- (void)awakeFromNib
{
	char *filepath = (char *)[[[NSBundle mainBundle] pathForResource:@"pci" ofType:@"ids"] UTF8String];
	//NSLog(@"%s", filepath);
	file_in = fopen(filepath, "rb");
	[self readDB];
	[self interrogateHardware];
	//[[[NSBundle mainBundle] executablePath] UTF8String];
	fclose(file_in);
}

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tab
{
	return (NSInteger)pciDevsCount;
}
- (id)tableView:(NSTableView*)table objectValueForTableColumn:(NSTableColumn*)col row:(NSInteger)rowIndex{
	int column;
	column = [[col identifier] intValue];
	//index = rowIndex;
	switch(column)
	{
		case 0:
			return [NSString stringWithFormat:@"%04X:%04X", pciDevs[rowIndex].vendor_id, pciDevs[rowIndex].device_id];
		case 1:
			return [NSString stringWithFormat:@"%s", [self vendorString: pciDevs[rowIndex].vendor_id]];
		case 2:
			return [NSString stringWithFormat:@"%s", [self deviceString: pciDevs[rowIndex].device_id forVendor:pciDevs[rowIndex].vendor_id]];
		default:
			break;
	}
	return @"Dupa";
}

-(BOOL)validateToolbarItem:(NSToolbarItem *)sender
{
    return [sender isEnabled];
}

-(IBAction)submit:(id)sender
{
    [submitButton setEnabled:false];
    int i=0;
    NSMutableArray *pciids = [NSMutableArray array];
    while(pciDevs[i].device_id!=0){
        [pciids addObject:[NSString stringWithFormat:@"id[]=%04X,%04X,%06X",pciDevs[i].vendor_id,pciDevs[i].device_id,pciDevs[i].device_class]];i++;
    }
    NSString *postData = [pciids componentsJoinedByString:@"&"];
    NSURL   *url = [NSURL URLWithString:@"http://dpcimanager.sourceforge.net/receiver"];
    NSMutableURLRequest *DPCIReceiver = [NSMutableURLRequest requestWithURL:url];
    [DPCIReceiver setHTTPMethod:@"POST"];
    [DPCIReceiver addValue: @"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [DPCIReceiver setValue:[NSString stringWithFormat: @"%u",[postData length]] forHTTPHeaderField:@"Content-Length"];
    [DPCIReceiver setHTTPBody: [postData dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:true]];
    [NSURLConnection sendAsynchronousRequest:DPCIReceiver queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *responseData, NSData *data, NSError *err){
        NSHTTPURLResponse *httpData = (NSHTTPURLResponse *)responseData;
        if (httpData.statusCode!=200) {
            [submitButton setLabel: @"Failed"];
        }
        else{
            [submitButton setLabel: @"Success"];
        }
    }];
    
}

-(IBAction)update:(id)sender
{
    [updateButton setEnabled:false];
    NSString *filepath = [[NSBundle mainBundle] pathForResource:@"pci" ofType:@"ids"];
    NSURL *url = [NSURL URLWithString:@"http://pci-ids.ucw.cz/pci.ids"];
    NSDate *filemtime = [[[NSFileManager defaultManager] attributesOfItemAtPath:filepath error:nil] fileModificationDate];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"HEAD"];
    NSHTTPURLResponse *response;
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
    NSString *urlmstr = nil;
    if ([response respondsToSelector:@selector(allHeaderFields)]){
        urlmstr = [[response allHeaderFields] objectForKey:@"Last-Modified"];
    }
    NSDate *urlmtime = nil;
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'";
    df.locale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease];
    df.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
    urlmtime = [df dateFromString:urlmstr];
    [df release];
    if ([filemtime laterDate:urlmtime] == urlmtime){
        [updateButton setLabel:@"Found"];
        NSData *data = [NSData dataWithContentsOfURL:url];
        [data writeToFile:filepath atomically:true];
        [[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObject:urlmtime forKey:NSFileModificationDate] ofItemAtPath:filepath error:nil];
        [NSTask launchedTaskWithLaunchPath:[[NSBundle mainBundle] executablePath] arguments:[NSArray arrayWithObjects: nil]];
        [NSApp terminate:self];
    }
    else {
        [[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObject:urlmtime forKey:NSFileModificationDate] ofItemAtPath:filepath error:nil];
        [updateButton setLabel:@"None"];   
    }
}

- (NSString *)fullString:(int)sid forClass:(int)cid
{
    return [NSString stringWithFormat:@"%s, %s",[self classString:cid],[self subclassString:sid forClass:cid]];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application
{
    return true;
}

-(void)updateDetails
{
	int row;
	int pcicl;
	int cl, scl;
	
	row = [pciTableView selectedRow];
	pcicl = pciDevs[row].device_class;
	
	cl = ((pcicl >> 16) & 0xff);
	scl = ((pcicl >> 8) & 0xff);
	
    [pciClass setStringValue:[self fullString:scl forClass:cl]];
	//[pciClass setStringValue:[NSString stringWithCString:[self classString:cl] encoding:NSUTF8StringEncoding]];
	//[pciSubclass setStringValue:[NSString stringWithCString:[self subclassString:scl forClass:cl] encoding:NSUTF8StringEncoding]];
}

-(IBAction)tableClick:(id)sender
{
	[self updateDetails];
}
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	[self updateDetails];
}
@end
