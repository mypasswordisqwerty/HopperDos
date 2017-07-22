//
//  ComLoader.m
//  HopperDos
//
//  Created by john on 01.04.17.
//  Copyright © 2017 bjfn. All rights reserved.
//

#import "ComLoader.h"

@implementation ComLoader {
    NSObject<HPHopperServices> *_services;
}

- (instancetype)initWithHopperServices:(NSObject<HPHopperServices> *)services {
    if (self = [super init]) {
        _services = services;
    }
    return self;
}

- (HopperUUID *)pluginUUID {
    return [_services UUIDWithString:@"9f8d07d0-b9d4-4a96-8862-392ed8028cd6"];
}

- (HopperPluginType)pluginType {
    return Plugin_Loader;
}

- (NSString *)pluginName {
    return @"DOS COM Loader";
}

- (NSString *)pluginDescription {
    return @"DOS COM File Loader";
}

- (NSString *)pluginAuthor {
    return @"bjohnfn@gmail.com";
}

- (NSString *)pluginCopyright {
    return @"©2017 - bjohnfn@gmail.com";
}

- (NSString *)pluginVersion {
    return @"0.0.1";
}

- (CPUEndianess)endianess {
    return CPUEndianess_Little;
}

- (BOOL)canLoadDebugFiles {
    return NO;
}

// Returns an array of DetectedFileType objects.
- (NSArray *)detectedTypesForData:(NSData *)data {
    if ([data length] < 1) return @[];

    NSObject<HPDetectedFileType> *type = [_services detectedType];
    [type setFileDescription:@"DOS COM Executable"];
    [type setAddressWidth:AW_16bits];
    [type setCpuFamily:@"intel16"];
    [type setCpuSubFamily:@"8086"];
    [type setShortDescriptionString:@"dos_com"];
    return @[type];
}

- (void)fixupRebasedFile:(NSObject<HPDisassembledFile> *)file withSlide:(int64_t)slide originalFileData:(NSData *)fileData {

}

- (FileLoaderLoadingStatus)loadDebugData:(NSData *)data forFile:(NSObject<HPDisassembledFile> *)file usingCallback:(FileLoadingCallbackInfo)callback {
    return DIS_NotSupported;
}

- (NSData *)extractFromData:(NSData *)data usingDetectedFileType:(NSObject<HPDetectedFileType> *)fileType returnAdjustOffset:(uint64_t *)adjustOffset {
    return nil;
}


- (FileLoaderLoadingStatus)loadData:(NSData *)data usingDetectedFileType:(NSObject<HPDetectedFileType> *)fileType options:(FileLoaderOptions)options forFile:(NSObject<HPDisassembledFile> *)file usingCallback:(FileLoadingCallbackInfo)callback {
    NSObject<HPSegment> *segment = [file addSegmentAt:0x100 size:[data length]];
    NSObject<HPSection> *section = [segment addSectionAt:0x100 size:[data length]];

    segment.segmentName = @"CODE";
    section.sectionName = COM_SECTION;
    section.containsCode = YES;
    NSString *comment = [NSString stringWithFormat:@"\n\nDOS COM %@\n\n", segment.segmentName];
    [file setComment:comment atVirtualAddress:0x100 reason:CCReason_Automatic];

    segment.mappedData = data;
    segment.fileOffset = 0;
    segment.fileLength = [data length];
    section.fileOffset = 0;
    section.fileLength = [data length];


    file.cpuFamily = @"intel16";
    file.cpuSubFamily = @"8086";
    [file setAddressSpaceWidthInBits:16];
    
    [file addEntryPoint:0x100];
    
    return DIS_OK;
}


@end
