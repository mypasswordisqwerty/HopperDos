//
//  MZLoader.m
//  DOSExeLoader
//
//  Created by john on 02.04.17.
//  Copyright © 2017 bjfn. All rights reserved.
//

#import "MZLoader.h"
#include "mz.h"
#include <set>
using namespace std;

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
    uint codeofs = mz->header_paragraphs * MZ_PARA;
    uint exesz = mz->blocks_in_file * MZ_BLOCK;
    if (mz->bytes_in_last_block){
        exesz -= MZ_BLOCK - mz->bytes_in_last_block;
    }
    uint codesz = exesz - codeofs;

    set<ushort> segs;
    segs.insert(0);

    MZReloc *reloc = (MZReloc*)(bytes + mz->reloc_table_offset);
    for (int i=0; i<mz->num_relocs; i++){
        segs.insert(reloc->segment);
        ushort* rval = (ushort*)(bytes + codeofs + (reloc->segment << 4) + reloc->offset);
        segs.insert(*rval);
        reloc++;
    }

    NSObject<HPSegment> *segment = [file addSegmentAt:0 size:codesz];
    segment.segmentName = @"DOS EXE";
    segment.mappedData = [NSData dataWithBytes:bytes+codeofs length:codesz];
    segment.fileOffset = codeofs;
    segment.fileLength = codesz;

    uint max = (*segs.rbegin()) << 4;
    for (auto it=segs.begin(); it!=segs.end(); ++it){
        set<ushort>::iterator prev;
        if (it == segs.begin()){
            prev = it;
            continue;
        }

        uint32 end = 0;
        do{
            uint start = *prev << 4;
            end = start==max ? codesz : *it << 4;
            size_t sz = end - start;
            NSLog(@"found segment %08X-%08X", start, end);

            NSObject<HPSection> *section = [segment addSectionAt:start size:sz];

            if (start!=max){
                section.sectionName = [NSString stringWithFormat:@"%04X:0000_CODE", *prev];
                section.pureCodeSection = NO;
                section.containsCode = YES;
                NSString *comment = [NSString stringWithFormat:@"\n%@ SEGMENT\n", section.sectionName];
                [file setComment:comment atVirtualAddress:start reason:CCReason_Automatic];
            }else{
                section.sectionName = [NSString stringWithFormat:@"%04X:0000_DATA", *prev];
                section.pureDataSection = YES;
                NSString *comment = [NSString stringWithFormat:@"\n%@ SEGMENT\n", section.sectionName];
                [file setComment:comment atVirtualAddress:start reason:CCReason_Automatic];

            }
            section.fileOffset = codeofs + start;
            section.fileLength = sz;

            prev=it;

        }while(end == max);
    }


    file.cpuFamily = @"intel16";
    file.cpuSubFamily = @"8086";
    [file setAddressSpaceWidthInBits:16];

    NSLog(@"Entry point at 0x%4.4X:0x%4.4X", mz->cs, mz->ip);
    [file addEntryPoint: mz->cs * MZ_PARA + mz->ip];

    return DIS_OK;
}


@end
