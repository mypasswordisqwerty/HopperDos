//
//  MZLoader.m
//  DOSExeLoader
//
//  Created by john on 02.04.17.
//  Copyright © 2017 bjfn. All rights reserved.
//

#import "MZLoader.h"
#include "mz.h"
#include <map>
using namespace std;

#define FAR_JMP     0xEA
#define FAR_CALL    0x9A
#define IS_FARJC(OP)  (OP==FAR_JMP || OP==FAR_CALL)
#define IRET    0xCF
#define NRET    0xC3
#define FRET    0xCB
#define IS_RET(OP) (OP==IRET || OP==NRET || OP==FRET)
#define NPRET   0xC2
#define FPRET   0xCA
#define IS_PRET(OP) (OP==NPRET || OP==FPRET)

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
    if ([data length] < sizeof(MZHeader))
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

    map<ushort, bool> segs;
    segs[0] = false;
    segs[mz->cs] = true;

    MZReloc *reloc = (MZReloc*)(bytes + mz->reloc_table_offset);
    for (int i=0; i<mz->num_relocs; i++){
        if (!segs.count(reloc->segment)){
            segs[reloc->segment] = false;
        }
        uint8_t* op = (uint8_t*)(bytes + codeofs + (reloc->segment << 4) + reloc->offset - 3);  // check far call/jmp bytes - OP OFFS SEGM
        ushort rval = *(ushort*)(op+3);
        segs[rval] |= IS_FARJC(*op);
        reloc++;
    }

    NSObject<HPSegment> *segment = [file addSegmentAt:0 size:codesz];
    segment.segmentName = @"DOS EXE";
    segment.mappedData = [NSData dataWithBytes:bytes+codeofs length:codesz];
    segment.fileOffset = codeofs;
    segment.fileLength = codesz;

    uint32 max = segs.rbegin()->first << 4;
    uint32 ofs=0;
    for (auto it=segs.begin(); it!=segs.end(); ++it){
        map<ushort, bool>::iterator prev;
        if (it == segs.begin()){
            prev = it;
            continue;
        }

        uint32 end = 0;
        do{
            uint start = (prev->first << 4)+ofs;
            end = start==max+ofs ? codesz : it->first << 4;
            //tune seg end to ret opcode
            if (it->second && prev->second){ // both code sections
                uint8_t *op = (uint8_t*)(bytes + codeofs + end -3); //3 bytes for stack pop RET
                for (ofs=0; ofs<2 && !IS_PRET(*op); ++ofs) ++op;
                if (ofs>1){
                    for (ofs=0; ofs<16 && !IS_RET(*op) && !IS_PRET(*op); ++ofs) ++op;
                    if (ofs>15){
                        //ret not found
                        ofs=0;
                    }else if (IS_PRET(*op)){
                        ofs+=2;
                    }
                }
                end += ofs;
            }else{
                ofs=0;
            }
            size_t sz = end - start;
            NSLog(@"found segment %08X-%08X", start, end);

            NSObject<HPSection> *section = [segment addSectionAt:start size:sz];

            if (prev->second){
                section.sectionName = [NSString stringWithFormat:@"%04X:%04X CODE", prev->first, start-(prev->first << 4)];
                section.pureCodeSection = NO;
                section.containsCode = YES;
            }else{
                section.sectionName = [NSString stringWithFormat:@"%04X:%04X DATA", prev->first, start-(prev->first << 4)];
                section.pureDataSection = YES;
                section.containsCode = NO;

            }
            section.fileOffset = codeofs + start;
            section.fileLength = sz;

            prev=it;

        }while(end == max+ofs);
    }


    file.cpuFamily = @"intel16";
    file.cpuSubFamily = @"8086";
    [file setAddressSpaceWidthInBits:16];

    NSLog(@"Entry point at 0x%4.4X:0x%4.4X", mz->cs, mz->ip);
    [file addEntryPoint: mz->cs * MZ_PARA + mz->ip];

    return DIS_OK;
}


@end
