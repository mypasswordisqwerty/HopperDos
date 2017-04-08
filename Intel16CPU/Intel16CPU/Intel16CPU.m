//
//  Intel16CPU.m
//  Intel16CPU
//
//  Created by john on 01.04.17.
//  Copyright © 2017 bjfn. All rights reserved.
//

#import "Intel16CPU.h"
#import "Intel16Ctx.h"


@implementation Intel16CPU {
    NSObject<HPHopperServices> *_services;
}


- (instancetype)initWithHopperServices:(NSObject<HPHopperServices> *)services {
    if (self = [super init]) {
        _services = services;
    }
    return self;
}

- (NSObject<HPHopperServices> *)hopperServices {
    return _services;
}

- (NSObject<CPUContext> *)buildCPUContextForFile:(NSObject<HPDisassembledFile> *)file {
    return [[Intel16Ctx alloc] initWithCPU:self andFile:file];
}

- (HopperUUID *)pluginUUID {
    return [_services UUIDWithString:@"9f8d07d0-b9d4-4a96-8862-392ed8028cd6"];
}

- (HopperPluginType)pluginType {
    return Plugin_CPU;
}

- (NSString *)pluginName {
    return @"Intel16";
}

- (NSString *)pluginDescription {
    return @"Intel x86 16-bit CPU support";
}

- (NSString *)pluginAuthor {
    return @"bjohnfn@gmail.com";
}

- (NSString *)pluginCopyright {
    return @"©2017 - bjohnfn@gmail.com";
}

- (NSArray *)cpuFamilies {
    return @[@"intel16"];
}

- (NSString *)pluginVersion {
    return @"0.0.1";
}

- (NSArray *)cpuSubFamiliesForFamily:(NSString *)family {
    if ([family isEqualToString:@"intel16"]) return @[@"8086"];
    return nil;
}

- (int)addressSpaceWidthInBitsForCPUFamily:(NSString *)family andSubFamily:(NSString *)subFamily {
    if ([family isEqualToString:@"intel16"] && [subFamily isEqualToString:@"8086"]) return 16;
    return 0;
}

- (CPUEndianess)endianess {
    return CPUEndianess_Little;
}

- (NSUInteger)cpuModeCount {
    return 1;
}

- (NSArray<NSString *> *)cpuModeNames {
    return @[@"generic"];
}

- (NSUInteger)syntaxVariantCount {
    return 4;
}

- (NSArray<NSString *> *)syntaxVariantNames {
    return @[@"intel", @"AT&T", @"intel s:o", @"AT&T s:o"];
}

- (NSString *)framePointerRegisterNameForFile:(NSObject<HPDisassembledFile> *)file {
    return nil;
}

- (NSUInteger)registerClassCount {
    return RegClass_X86_SEG;
}

- (NSUInteger)registerCountForClass:(RegClass)reg_class {
    switch (reg_class) {
        case RegClass_CPUState: return 1;
        case RegClass_GeneralPurposeRegister: return IP+1;
        case RegClass_X86_SEG: return SS+1;
        default: break;
    }
    return 0;
}

- (BOOL)registerIndexIsStackPointer:(NSUInteger)reg ofClass:(RegClass)reg_class {
    return reg_class == RegClass_GeneralPurposeRegister && reg == SP;
}

- (BOOL)registerIndexIsFrameBasePointer:(NSUInteger)reg ofClass:(RegClass)reg_class {
    return reg_class == RegClass_GeneralPurposeRegister && reg == BP;
}

- (BOOL)registerIndexIsProgramCounter:(NSUInteger)reg {
    return NO;
}

- (NSString *)lowercaseStringForRegister:(NSUInteger)reg ofClass:(RegClass)reg_class {
    static NSString *GNames[] = {@"ah", @"al", @"bh", @"bl", @"ch", @"cl", @"dh", @"dl",
        @"ax", @"bx", @"cx", @"dx", @"bp", @"sp", @"si", @"di", @"ip"};
    static NSString *SNames[] = {@"cs", @"ds", @"es", @"ss"};

    switch (reg_class) {
        case RegClass_CPUState: return @"flags";
        case RegClass_GeneralPurposeRegister: return GNames[reg];
        case RegClass_X86_SEG: return SNames[reg];
        default: break;
    }
    return nil;
}

- (NSString *)registerIndexToString:(NSUInteger)reg ofClass:(RegClass)reg_class withBitSize:(NSUInteger)size position:(DisasmPosition)position andSyntaxIndex:(NSUInteger)syntaxIndex {
    NSString *regName = [self lowercaseStringForRegister:reg ofClass:reg_class];
    return regName;
}

- (NSString *)cpuRegisterStateMaskToString:(uint32_t)cpuState {
    return @"";
}

- (NSUInteger)translateOperandIndex:(NSUInteger)index operandCount:(NSUInteger)count accordingToSyntax:(uint8_t)syntaxIndex {
    return index;
}

- (NSData *)nopWithSize:(NSUInteger)size andMode:(NSUInteger)cpuMode forFile:(NSObject<HPDisassembledFile> *)file {
    NSMutableData *nopArray = [[NSMutableData alloc] initWithCapacity:size];
    [nopArray setLength:size];
    uint16_t *ptr = (uint16_t *)[nopArray mutableBytes];
    for (NSUInteger i=0; i<size; i+=1) {
        *ptr++ = 0x90;
    }
    return [NSData dataWithData:nopArray];
}

- (BOOL)canAssembleInstructionsForCPUFamily:(NSString *)family andSubFamily:(NSString *)subFamily {
    return NO;
}

- (BOOL)canDecompileProceduresForCPUFamily:(NSString *)family andSubFamily:(NSString *)subFamily {
    return NO;
}


@end
