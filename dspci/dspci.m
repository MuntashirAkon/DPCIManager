//
//  dspci.m
//  dspci
//
//  Created by Muntashir Al-Islam on 8/20/18.
//

#import <Foundation/Foundation.h>
#import "dspci.h"
#import "DataTypeHandler.h"


@implementation DSPCI

- (id) init {
    self = [super init];
    if (self == nil)
        return nil;
    return self;
}

- (void) printUsage: (FILE *) stream {
    ddfprintf(stream, @"%@: Usage [OPTIONS] [<data type>]\n", DDCliApp);
}

- (void) printHelp {
    [self printUsage: stdout];
    printf("\n"
           "  -l, --listDataTypes           List possible data types\n"
           "  -j, --json                    Output in JSON format\n"
           "      --version                 Display version info\n"
           "  -h, --help                    Show this help\n"
           "\n"
           "dspci is a command line tool for getting PCI and other PCI-related information.\n");
}

- (void) printVersion {
    ddprintf(@"%@ version %s\n", DDCliApp, CURRENT_MARKETING_VERSION);
}

- (void) listDataTypes {
    printf("Available data types:\n"
           "  DTListPCIID                       List only PCI IDs\n"
           "  DTListAudio                       List audio related info\n"
           "  DTListAudioID                     List audio device IDs\n"
           "  DTListAudioCodecID                List audio codec IDs\n"
           "  DTListAudioCodecIDWithRevision    List audio codec IDs\n"
           "  DTListGPU                         List GPU related info\n"
           "  DTListGPUID                       List GPU only IDs\n"
           "  DTListNetwork                     List network devices\n"
           "  DTListNetworkID                   List network device IDs\n"
           "  DTListConnected                   List connected devices via USB\n"
           "  DTListConnectedID                 List connected device IDs via USB\n"
           "\n"
           "By default, all the PCI device info will be printed.\n");
}

- (void) application: (DDCliApplication *) app willParseOptions: (DDGetoptLongParser *) optionsParser {
    DDGetoptOption optionTable[] = {
        // Long             Short   Argument options
        {"listDataTypes",   'l',     DDGetoptNoArgument},
        {"json",            'j',     DDGetoptNoArgument},
        {"version",          0,      DDGetoptNoArgument},
        {"help",            'h',     DDGetoptNoArgument},
        {"",                 0,      0},
    };
    [optionsParser addOptionsFromTable: optionTable tableSize:(sizeof(optionTable)/sizeof(*optionTable))];
}

- (int) application: (DDCliApplication *) app runWithArguments: (NSArray *) arguments {
    if (_help) {
        [self printHelp];
        return EXIT_SUCCESS;
    }
    
    if (_version) {
        [self printVersion];
        return EXIT_SUCCESS;
    }
    
    if (_listDataTypes) {
        [self listDataTypes];
        return EXIT_SUCCESS;
    }
    
    DataTypeHandler *DTHandler = [[DataTypeHandler alloc] init];
    DTHandler->printJSON = _json;
    switch ([arguments count]) {
        case 1:
            // Data type is given
            return [DTHandler handleDataType:arguments[0]];
        case 0:
            // Print default
            return [DTHandler handleDataType:DTH_HANDLE_DEFAULT];
        default:
            @throw [DDCliParseException parseExceptionWithReason:[NSString stringWithFormat:@"Invalid Arguments.\nTry `%@ --help` for more information.", DDCliApp]  exitCode:EX_DATAERR];
    }
}
@end
