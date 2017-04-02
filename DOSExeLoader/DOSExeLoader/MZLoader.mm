//
//  MZLoader.m
//  DOSExeLoader
//
//  Created by john on 02.04.17.
//  Copyright © 2017 bjfn. All rights reserved.
//

#import "MZLoader.h"
#include "mz.h"

@implementation MZLoader{
    NSObject<HPHopperServices> *_services;
}

- (instancetype)initWithHopperServices:(NSObject<HPHopperServices> *)services {
    if (self = [super init]) {
        _services = services;
    }
    return self;
}

- (HopperUUID *)pluginUUID {
    return [_services UUIDWithString:@"1a56d108-f990-478b-8b0b-f026973a2651"];
}

- (HopperPluginType)pluginType {
    return Plugin_Loader;
}

- (NSString *)pluginName {
    return @"DOS MZ Loader";
}

- (NSString *)pluginDescription {
    return @"DOS MZ File Loader";
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
    if ([data length] < 0x1c)
        return @[];

    const void *bytes = (const void *)[data bytes];
    MZHeader *mz=(MZHeader*)bytes;
    if (mz->signature!=MZ_MAGIC){
        return @[];
    }

    NSObject<HPDetectedFileType> *type = [_services detectedType];
    [type setFileDescription:@"DOS MZ Executable"];
    [type setAddressWidth:AW_16bits];
    [type setCpuFamily:@"intel16"];
    [type setCpuSubFamily:@"8086"];
    [type setShortDescriptionString:@"dos_mz"];
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

    const unsigned char *bytes = (const unsigned char *)[data bytes];
    MZHeader* mz = (MZHeader*)bytes;
    //MZReloc *reloc = (MZReloc*)bytes+sizeof(MZHeader);
    int codeofs = mz->header_paragraphs*16;
    size_t exesz = mz->blocks_in_file * MZ_BLOCK;
    if (mz->bytes_in_last_block){
        exesz -= MZ_BLOCK - mz->bytes_in_last_block;
    }
    size_t codesz = exesz - codeofs;

    NSObject<HPSegment> *segment = [file addSegmentAt:0 size:codesz];
    NSObject<HPSection> *section = [segment addSectionAt:0 size:codesz];

    segment.segmentName = @"CODE";
    section.sectionName = @"code";
    section.containsCode = YES;
    NSString *comment = [NSString stringWithFormat:@"\n\nDOS EXE SEGMENT %@\n\n", segment.segmentName];
    [file setComment:comment atVirtualAddress:0 reason:CCReason_Automatic];

    segment.mappedData = [NSData dataWithBytes:bytes + codeofs length:codesz];
    segment.fileOffset = codeofs;
    segment.fileLength = codesz;
    section.fileOffset = codeofs;
    section.fileLength = codesz;


    file.cpuFamily = @"intel16";
    file.cpuSubFamily = @"8086";
    [file setAddressSpaceWidthInBits:16];

    NSLog(@"Entry point at 0x%4.4X:0x%4.4X", mz->cs, mz->ip);
    [file addEntryPoint: mz->cs * 0x10 + mz->ip];

    return DIS_OK;
}


@end
