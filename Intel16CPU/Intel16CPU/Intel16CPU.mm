//
//  Intel16CPU.m
//  Intel16CPU
//
//  Created by john on 01.04.17.
//  Copyright © 2017 bjfn. All rights reserved.
//

#import "Intel16CPU.h"
#import "Intel16Ctx.h"

#include <map>
#include <string>
#include <vector>

using namespace std;

struct RegInfo{
    x86_reg capstone;
    int rid;
    RegClass rclass;
    int64_t *statePtr;
    int size;
    string name;
};

static struct CpuState{
    int64_t EAX, EBX, ECX, EDX, EBP, ESP, ESI, EDI, EIP;
    int64_t ES, DS, FS, GS, CS, SS;
    int64_t EFLAGS;
    vector<int64_t> stack;
} _state;


static RegInfo regs[]={
    {X86_REG_EFLAGS, 0, RegClass_CPUState, &_state.EFLAGS, 4, "eflags"},
    {X86_REG_AL, AL, RegClass_GeneralPurposeRegister, &_state.EAX, 1, "al"},
    {X86_REG_AH, AH, RegClass_GeneralPurposeRegister, &_state.EAX, 0x101, "ah"},
    {X86_REG_AX, AX, RegClass_GeneralPurposeRegister, &_state.EAX, 2, "ax"},
    {X86_REG_EAX, EAX, RegClass_GeneralPurposeRegister, &_state.EAX, 4, "eax"},
    {X86_REG_BL, BL, RegClass_GeneralPurposeRegister, &_state.EBX, 1, "bl"},
    {X86_REG_BH, BH, RegClass_GeneralPurposeRegister, &_state.EBX, 0x101, "bh"},
    {X86_REG_BX, BX, RegClass_GeneralPurposeRegister, &_state.EBX, 2, "bx"},
    {X86_REG_EBX, EBX, RegClass_GeneralPurposeRegister, &_state.EBX, 4, "ebx"},
    {X86_REG_CL, CL, RegClass_GeneralPurposeRegister, &_state.ECX, 1, "cl"},
    {X86_REG_CH, CH, RegClass_GeneralPurposeRegister, &_state.ECX, 0x101, "ch"},
    {X86_REG_CX, CX, RegClass_GeneralPurposeRegister, &_state.ECX, 2, "cx"},
    {X86_REG_ECX, ECX, RegClass_GeneralPurposeRegister, &_state.ECX, 4, "ecx"},
    {X86_REG_DL, DL, RegClass_GeneralPurposeRegister, &_state.EDX, 1, "dl"},
    {X86_REG_DH, DH, RegClass_GeneralPurposeRegister, &_state.EDX, 0x101, "dh"},
    {X86_REG_DX, DX, RegClass_GeneralPurposeRegister, &_state.EDX, 2, "dx"},
    {X86_REG_EDX, EDX, RegClass_GeneralPurposeRegister, &_state.EDX, 4, "edx"},
    {X86_REG_BP, BP, RegClass_GeneralPurposeRegister, &_state.EBP, 2, "bp"},
    {X86_REG_EBP, EBP, RegClass_GeneralPurposeRegister, &_state.EBP, 4, "ebp"},
    {X86_REG_SP, SP, RegClass_GeneralPurposeRegister, &_state.ESP, 2, "sp"},
    {X86_REG_ESP, ESP, RegClass_GeneralPurposeRegister, &_state.ESP, 4, "esp"},
    {X86_REG_SI, SI, RegClass_GeneralPurposeRegister, &_state.ESI, 2, "si"},
    {X86_REG_ESI, ESI, RegClass_GeneralPurposeRegister, &_state.ESI, 4, "esi"},
    {X86_REG_DI, DI, RegClass_GeneralPurposeRegister, &_state.EDI, 2, "di"},
    {X86_REG_EDI, EDI, RegClass_GeneralPurposeRegister, &_state.EDI, 4, "edi"},
    {X86_REG_IP, IP, RegClass_GeneralPurposeRegister, &_state.EIP, 2, "ip"},
    {X86_REG_EIP, EIP, RegClass_GeneralPurposeRegister, &_state.EIP, 4, "eip"},
    {X86_REG_CS, DISASM_CS_Reg, RegClass_X86_SEG, &_state.CS, 2, "cs"},
    {X86_REG_DS, DISASM_DS_Reg, RegClass_X86_SEG, &_state.DS, 2, "ds"},
    {X86_REG_ES, DISASM_ES_Reg, RegClass_X86_SEG, &_state.ES, 2, "es"},
    {X86_REG_SS, DISASM_SS_Reg, RegClass_X86_SEG, &_state.SS, 2, "ss"},
    {X86_REG_FS, DISASM_FS_Reg, RegClass_X86_SEG, &_state.FS, 2, "fs"},
    {X86_REG_GS, DISASM_GS_Reg, RegClass_X86_SEG, &_state.GS, 2, "gs"},
    {X86_REG_INVALID, 0, RegClass_X86_SEG, NULL, 2, "invalid"},
};



@implementation Intel16CPU {
    NSObject<HPHopperServices> *_services;
    map<int,RegInfo*> capstoneRegs;
    map<int,map<int,RegInfo*>> localRegs;
}

- (void)fillRegs {
    for (auto it: regs){
        capstoneRegs[it.capstone] = &it;
        localRegs[it.rclass][it.rid] = &it;
        if (it.capstone==X86_REG_INVALID){
            break;
        }
    }
}

- (instancetype)initWithHopperServices:(NSObject<HPHopperServices> *)services {
    if (self = [super init]) {
        _services = services;
        [self fillRegs];
        [self clearState];
        NSLog(@"inited");
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

- (Class)cpuContextClass {
    return [Intel16Ctx class];
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
        case RegClass_GeneralPurposeRegister: return EIP+1;
        case RegClass_X86_SEG: return DISASM_SS_Reg+1;
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

- (BOOL)registerHasSideEffectForIndex:(NSUInteger)reg andClass:(RegClass)reg_class {
    return NO;
}

- (NSString *)registerIndexToString:(NSUInteger)reg ofClass:(RegClass)reg_class withBitSize:(NSUInteger)size position:(DisasmPosition)position andSyntaxIndex:(NSUInteger)syntaxIndex {
    RegInfo* info = localRegs[reg_class][(int)reg];
    if (!info){
        return nil;
    }
    return [NSString stringWithCString:info->name.c_str() encoding:NSUTF8StringEncoding];
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

- (NSUInteger)capstoneToRegIndex:(x86_reg)reg {
    return capstoneRegs[reg]->rid;
}

- (RegClass)capstoneToRegClass:(x86_reg)reg {
    return capstoneRegs[reg]->rclass;
}

- (void)clearState {
    //set state to int64 0xFFFFFFFFFFFFFFFF
    memset(&_state, 0xFF, 16*sizeof(int64_t));
    _state.stack.clear();
}

- (void)updateState:(DisasmStruct*)disasm{
    
}

- (int64_t)valueReg:(NSUInteger)reg ofClass:(RegClass)rclass{
    RegInfo* info=localRegs[rclass][(int)reg];
    if(!info || *info->statePtr==UNDEFINED_STATE){
        return UNDEFINED_STATE;
    }
    int ofs = info->size >> 8;
    int64_t res=0;
    memcpy(&res, ((uint8_t*)info->statePtr)+ofs, info->size & 0xFF);
    return res;
}

@end
