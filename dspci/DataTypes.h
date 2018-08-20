//
//  DataTypes.h
//  DPCIManager
//
//  Created by Muntashir Al-Islam on 8/20/18.
//

#ifndef DataTypes_h
#define DataTypes_h

// Data type to int
#define DT_TO_INT(dataType) ((unsigned) (dataType##_INT))

//
// Data types
//

#define DT_LIST_DEFAULT     @""
// List only PCI IDs (VendorID:ProductID)
#define DT_LIST_PCI_ID      @"DTListPCIID"
// Audio
#define DT_LIST_AUDIO       @"DTListAudio"
#define DT_LIST_AUDIO_ID    @"DTListAudioID"
#define DT_LIST_AUDIO_CODEC_ID  @"DTListAudioCodecID"
#define DT_LIST_AUDIO_CODEC_ID_WITH_REVISION  @"DTListAudioCodecIDWithRevision" // CodecID:Revision
// GPU
#define DT_LIST_GPU         @"DTListGPU"
#define DT_LIST_GPU_ID      @"DTListGPUID"
// Network devices
#define DT_LIST_NETWORK     @"DTListNetwork"
#define DT_LIST_NETWORK_ID  @"DTListNetworkID"
// Connected devices
#define DT_LIST_CONNECTED     @"DTListConnected"
#define DT_LIST_CONNECTED_ID  @"DTListConnectedID"
// List ALL IDs
#define DT_LIST_ALL_ID      @"DTListAllID"

//
// Associated integer values
//
#define DT_LIST_DEFAULT_INT         1
#define DT_LIST_PCI_ID_INT          2
#define DT_LIST_AUDIO_INT           3
#define DT_LIST_AUDIO_ID_INT        4
#define DT_LIST_AUDIO_CODEC_INT     5
#define DT_LIST_AUDIO_CODEC_ID_INT  6
#define DT_LIST_AUDIO_CODEC_ID_WITH_REVISION_INT 7
#define DT_LIST_GPU_INT             8
#define DT_LIST_GPU_ID_INT          9
#define DT_LIST_NETWORK_INT         10
#define DT_LIST_NETWORK_ID_INT      11
#define DT_LIST_CONNECTED_INT       12
#define DT_LIST_CONNECTED_ID_INT    13
#define DT_LIST_ALL_ID_INT          14

#endif /* DataTypes_h */
