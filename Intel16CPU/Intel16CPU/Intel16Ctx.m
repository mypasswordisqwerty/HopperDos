//
//  Intel16Ctx.m
//  Intel16CPU
//
//  Created by john on 01.04.17.
//  Copyright © 2017 bjfn. All rights reserved.
//

#import "Intel16Ctx.h"
#import "Intel16CPU.h"
#import <Hopper/CommonTypes.h>
#import <Hopper/CPUDefinition.h>
#import <Hopper/HPDisassembledFile.h>
#import "OpComment.h"

#include <capstone/capstone.h>
#include <stdlib.h>

#define FORMAT(fmt) if (format == Format_Default) format = fmt

@implementation Intel16Ctx {
    Intel16CPU *_cpu;
    NSObject<HPDisassembledFile> *_file;
    csh _handle;
    NSArray* intelPtrs;
    uint64_t maxAddress;
}

- (instancetype)initWithCPU:(Intel16CPU *)cpu andFile:(NSObject<HPDisassembledFile> *)file {
    if (self = [super init]) {
        _cpu = cpu;
        _file = file;
        if (cs_open(CS_ARCH_X86, CS_MODE_16, &_handle) != CS_ERR_OK) {
            return nil;
        }
        cs_option(_handle, CS_OPT_DETAIL, CS_OPT_ON);
        if (file.userRequestedSyntaxIndex & 1){
            cs_option(_handle, CS_OPT_SYNTAX, CS_OPT_SYNTAX_ATT);
        }else{
            cs_option(_handle, CS_OPT_SYNTAX, CS_OPT_SYNTAX_INTEL);
        }
        intelPtrs = @[@"byte ptr ", @"word ptr ", @"dword ptr "];
        [_cpu setFile:file];
        maxAddress = [[file firstSegment] endAddress];
    }
    return self;
}

- (void)dealloc {
    cs_close(&_handle);
}

- (NSObject<CPUDefinition> *)cpuDefinition {
    return _cpu;
}

- (void)initDisasmStructure:(DisasmStruct*)disasm withSyntaxIndex:(NSUInteger)syntaxIndex {
    bzero(disasm, sizeof(DisasmStruct));
    disasm->syntaxIndex = _file.userRequestedSyntaxIndex;
}

// Analysis

- (Address)adjustCodeAddress:(Address)address {
    return address;
}

- (uint8_t)cpuModeFromAddress:(Address)address {
    return 0;
}

- (BOOL)addressForcesACPUMode:(Address)address {
    return NO;
}

- (Address)nextAddressToTryIfInstructionFailedToDecodeAt:(Address)address forCPUMode:(uint8_t)mode {
    return address+1;
}

- (int)isNopAt:(Address)address {
    uint8_t byte = [_file readUInt8AtVirtualAddress:address];
    return byte==0x90;
}

- (BOOL)hasProcedurePrologAt:(Address)address {
    uint32_t data = [_file readUInt32AtVirtualAddress:address];
    return (data & 0x00FFFFFF) == 0xEC8B55;
}

- (NSUInteger)detectedPaddingLengthAt:(Address)address {
    return 0;
}

- (void)analysisBeginsAt:(Address)entryPoint {

}

- (void)analysisEnded {

}

- (void)procedureAnalysisBeginsForProcedure:(NSObject<HPProcedure> *)procedure atEntryPoint:(Address)entryPoint {
    [_cpu clearState];
}

- (void)procedureAnalysisOfPrologForProcedure:(NSObject<HPProcedure> *)procedure atEntryPoint:(Address)entryPoint {

}

- (void)procedureAnalysisOfEpilogForProcedure:(NSObject<HPProcedure> *)procedure atEntryPoint:(Address)entryPoint {

}

- (void)procedureAnalysisEndedForProcedure:(NSObject<HPProcedure> *)procedure atEntryPoint:(Address)entryPoint {
    [_cpu clearState];
}

- (void)procedureAnalysisContinuesOnBasicBlock:(NSObject<HPBasicBlock> *)basicBlock {

}

- (Address)getThunkDestinationForInstructionAt:(Address)address {
    return BAD_ADDRESS;
}

- (void)resetDisassembler {

}

- (uint8_t)estimateCPUModeAtVirtualAddress:(Address)address {
    return 0;
}


- (int)disassembleSingleInstruction:(DisasmStruct *)disasm usingProcessorMode:(NSUInteger)mode {
    if (disasm->bytes == NULL) return DISASM_UNKNOWN_OPCODE;

    cs_insn *insn;
    size_t count = cs_disasm(_handle, disasm->bytes, 16, disasm->virtualAddr, 1, &insn);
    if (count == 0) return DISASM_UNKNOWN_OPCODE;

    disasm->instruction.branchType = DISASM_BRANCH_NONE;
    disasm->instruction.addressValue = 0;
    disasm->instruction.userData = insn->id;
    disasm->instruction.pcRegisterValue = disasm->virtualAddr + insn->size;

    int op_index;
    for (op_index=0; op_index<insn->detail->x86.op_count; op_index++) {
        cs_x86_op *op = insn->detail->x86.operands + op_index;
        DisasmOperand *hop_op = disasm->operand + op_index;

        switch (op->type) {
            case X86_OP_IMM:
                hop_op->type = DISASM_OPERAND_CONSTANT_TYPE;
                hop_op->immediateValue = op->imm;
                break;

            case X86_OP_REG:
                hop_op->userData[0] = op->reg;
                hop_op->type = DISASM_OPERAND_REGISTER_TYPE;
                hop_op->type |= DISASM_BUILD_REGISTER_CLS_MASK([_cpu capstoneToRegClass:op->reg]);
                hop_op->type |= DISASM_BUILD_REGISTER_INDEX_MASK([_cpu capstoneToRegIndex:op->reg]);
                break;


            case X86_OP_MEM: {
                hop_op->type = DISASM_OPERAND_MEMORY_TYPE;
                hop_op->memory.displacement = (int16_t) op->mem.disp;
                BOOL dispOnly=YES;
                DisasmSegmentReg seg = DISASM_DS_Reg;
                if (op->mem.segment != X86_REG_INVALID){
                    hop_op->segmentReg = (DisasmSegmentReg)[_cpu capstoneToRegIndex:op->mem.segment];
                    seg = hop_op->segmentReg;
                }
                if (op->mem.base!=X86_REG_INVALID){
                    hop_op->type |= DISASM_BUILD_REGISTER_CLS_MASK(RegClass_GeneralPurposeRegister);
                    uint64_t mask = DISASM_BUILD_REGISTER_INDEX_MASK([_cpu capstoneToRegIndex:op->mem.base]);
                    hop_op->type |= mask;
                    hop_op->memory.baseRegistersMask = mask;
                    dispOnly = NO;
                }
                if (op->mem.index!=X86_REG_INVALID){
                    hop_op->type |= DISASM_BUILD_REGISTER_CLS_MASK(RegClass_GeneralPurposeRegister);
                    uint64_t mask = DISASM_BUILD_REGISTER_INDEX_MASK([_cpu capstoneToRegIndex:op->mem.index]);
                    hop_op->type |= mask;
                    hop_op->memory.indexRegistersMask = mask;
                    hop_op->memory.scale = op->mem.scale;
                    dispOnly = NO;
                }

                if (dispOnly && op->mem.disp){
                    uint64_t a = [_cpu getReg:seg ofClass:RegClass_X86_SEG];
                    if (a == UNDEFINED_STATE){
                        a = [_cpu dataSeg];
                    }
                    if (a!=UNDEFINED_STATE){
                        disasm->instruction.addressValue = (a<<4) + hop_op->memory.displacement;
                    }
                }

                hop_op->size = op->size * 8;
                break;
            }

            default:
                hop_op->type = DISASM_OPERAND_OTHER;
                break;
        }

    }
    for ( ; op_index < DISASM_MAX_OPERANDS; op_index++) {
        disasm->operand[op_index].type = DISASM_OPERAND_NO_OPERAND;
    }
    strcpy(disasm->instruction.mnemonic, insn->mnemonic);

    // In this early version, only branch instructions are analyzed in order to correctly
    // construct basic blocks of procedures.
    //
    // This is the strict minimum!
    //
    // You should also fill the "operand" description for every other instruction to take
    // advantage of the various analysis of Hopper.
    bool loop = (insn->id == X86_INS_LOOP || insn->id == X86_INS_LOOPE || insn->id == X86_INS_LOOPNE);

    if (loop || cs_insn_group(_handle, insn, X86_GRP_JUMP) || cs_insn_group(_handle, insn, X86_GRP_CALL)) {
        disasm->instruction.addressValue = 0;
        disasm->operand[0].type |= DISASM_OPERAND_ABSOLUTE;
        do{
            if (insn->detail->x86.op_count <1)
                break;
            if (insn->detail->x86.operands[0].type!=X86_OP_IMM)
                break;
            disasm->operand[0].isBranchDestination = 1;
            uint8_t op = disasm->bytes[0];
            int16_t *op16 = (int16_t*)(disasm->bytes+1);
            if (op == 0x9A || op == 0xEA){
                //ptr16:16
                disasm->instruction.addressValue = op16[0] + (op16[1]<<4);
                disasm->operand[0].size = 32;
                disasm->operand[1].type = DISASM_OPERAND_NO_OPERAND;
                break;
            }
            if (op==0xE9 || op == 0xE8){
                //rel16
                disasm->instruction.addressValue = disasm->virtualAddr + insn->size + op16[0];
                break;
            }
            //rel 8
            int8_t *op8 = (int8_t*)disasm->bytes+1;
            disasm->instruction.addressValue = disasm->virtualAddr + insn->size + op8[0];
        }while(0);
        if (disasm->instruction.addressValue){
            disasm->operand[0].immediateValue = disasm->instruction.addressValue;
        }

        if(cs_insn_group(_handle, insn, X86_GRP_CALL)){
            disasm->instruction.branchType = DISASM_BRANCH_CALL;
        }

        switch(insn->id) {
            case X86_INS_JGE:
            case X86_INS_JAE:
                disasm->instruction.branchType = DISASM_BRANCH_JGE;
                break;
            case X86_INS_JA:
                disasm->instruction.branchType = DISASM_BRANCH_JA;
                break;
            case X86_INS_JLE:
            case X86_INS_JBE:
                disasm->instruction.branchType = DISASM_BRANCH_JLE;
                break;
            case X86_INS_JB:
                disasm->instruction.branchType = DISASM_BRANCH_JB;
                break;
            case X86_INS_JCXZ:
                disasm->instruction.branchType = DISASM_BRANCH_JCXZ;
                break;
            case X86_INS_JECXZ:
            case X86_INS_LOOP:
            case X86_INS_LOOPE:
            case X86_INS_LOOPNE:
                disasm->instruction.branchType = DISASM_BRANCH_JECXZ;
                break;
            case X86_INS_JE:
                disasm->instruction.branchType = DISASM_BRANCH_JE;
                break;
            case X86_INS_JG:
                disasm->instruction.branchType = DISASM_BRANCH_JG;
                break;
            case X86_INS_JL:
                disasm->instruction.branchType = DISASM_BRANCH_JL;
                break;
            case X86_INS_JMP:
            case X86_INS_LJMP:
                disasm->instruction.branchType = DISASM_BRANCH_JMP;
                break;
            case X86_INS_JNE:
                disasm->instruction.branchType = DISASM_BRANCH_JNE;
                break;
            case X86_INS_JNO:
                disasm->instruction.branchType = DISASM_BRANCH_JNO;
                break;
            case X86_INS_JNP:
                disasm->instruction.branchType = DISASM_BRANCH_JNP;
                break;
            case X86_INS_JNS:
                disasm->instruction.branchType = DISASM_BRANCH_JNS;
                break;
            case X86_INS_JO:
                disasm->instruction.branchType = DISASM_BRANCH_JO;
                break;
            case X86_INS_JP:
                disasm->instruction.branchType = DISASM_BRANCH_JP;
                break;
            case X86_INS_JRCXZ:
                disasm->instruction.branchType = DISASM_BRANCH_JRCXZ;
                break;
            case X86_INS_JS:
                disasm->instruction.branchType = DISASM_BRANCH_JS;
                break;
        }
    }

    if (cs_insn_group(_handle, insn, X86_GRP_RET) || cs_insn_group(_handle, insn, X86_GRP_IRET)) {
        disasm->instruction.branchType = DISASM_BRANCH_RET;
    }

    int len = (int) insn->size;
    cs_free(insn, count);

    [_cpu updateState:disasm];

    return len;
}

- (BOOL)instructionHaltsExecutionFlow:(DisasmStruct *)disasm {
    return NO;
}

- (void)performBranchesAnalysis:(DisasmStruct *)disasm computingNextAddress:(Address *)next andBranches:(NSMutableArray *)branches forProcedure:(NSObject<HPProcedure> *)procedure basicBlock:(NSObject<HPBasicBlock> *)basicBlock ofSegment:(NSObject<HPSegment> *)segment calledAddresses:(NSMutableArray *)calledAddresses callsites:(NSMutableArray *)callSitesAddresses {

}

- (void)performInstructionSpecificAnalysis:(DisasmStruct *)disasm forProcedure:(NSObject<HPProcedure> *)procedure inSegment:(NSObject<HPSegment> *)segment {
    NSString* comment = [OpComment commentForOpcode:disasm CPU:_cpu];
    if (comment){
        [_file setComment:comment atVirtualAddress:disasm->virtualAddr reason:CCReason_Automatic];
    }
}

- (void)performProcedureAnalysis:(NSObject<HPProcedure> *)procedure basicBlock:(NSObject<HPBasicBlock> *)basicBlock disasm:(DisasmStruct *)disasm {
}

- (void)updateProcedureAnalysis:(DisasmStruct *)disasm {
}

//Printing
static inline int firstBitIndex(uint64_t mask) {
    for (int i=0, j=1; i<64; i++, j<<=1) {
        if (mask & j) {
            return i;
        }
    }
    return -1;
}


static inline RegClass regClassFromType(uint64_t type) {
    return (RegClass) firstBitIndex(DISASM_GET_REGISTER_CLS_MASK(type));
}

static inline int regIndexFromType(uint64_t type) {
    return firstBitIndex(DISASM_GET_REGISTER_INDEX_MASK(type));
}

- (NSObject<HPASMLine> *)buildMnemonicString:(DisasmStruct *)disasm inFile:(NSObject<HPDisassembledFile> *)file {
    NSObject<HPHopperServices> *services = _cpu.hopperServices;

    NSObject<HPASMLine> *line = [services blankASMLine];
    if ((disasm->syntaxIndex & 2) != 0){
        [line appendRawString:[NSString stringWithFormat:@"%04X:%04X    ", [_cpu getCS], [_cpu getIP]]];
    }
    NSString *mnemonic = @(disasm->instruction.mnemonic);
    [line appendMnemonic:mnemonic];
    return line;
}



-(void)printRegisterIndex:(NSUInteger)regIdx ofClass:(RegClass)regCls line:(NSObject<HPASMLine> *)line disasm:(DisasmStruct*)disasm {
    if (disasm->syntaxIndex & 1){
        [line appendRawString:@"%"];
    }
    [line appendRegister:[_cpu registerIndexToString:regIdx
                                             ofClass:regCls
                                         withBitSize:16
                                            position:DISASM_LOWPOSITION
                                      andSyntaxIndex:disasm->syntaxIndex]
                 ofClass:regCls
                andIndex:regIdx];
}

-(void)printRegisterType:(DisasmOperandType)type line:(NSObject<HPASMLine> *)line disasm:(DisasmStruct*)disasm {
    RegClass regCls = regClassFromType(type);
    int regIdx = regIndexFromType(type);
    [self printRegisterIndex:regIdx ofClass:regCls line:line disasm:disasm];
}


- (NSObject<HPASMLine> *)buildOperandString:(DisasmStruct *)disasm forOperandIndex:(NSUInteger)operandIndex inFile:(NSObject<HPDisassembledFile> *)file raw:(BOOL)raw {
    if (operandIndex >= DISASM_MAX_OPERANDS) return nil;
    DisasmOperand *operand = disasm->operand + operandIndex;
    if (operand->type == DISASM_OPERAND_NO_OPERAND) return nil;

    // Get the format requested by the user
    ArgFormat format = [file formatForArgument:operandIndex atVirtualAddress:disasm->virtualAddr];
    NSObject<HPHopperServices> *services = _cpu.hopperServices;
    NSObject<HPASMLine> *line = [services blankASMLine];
    [line setIsOperand:operandIndex startingAtIndex:0];

    bool att = disasm->syntaxIndex & 1;
    bool memFilled = false;
    int regIdx = 0;

    if (operand->type & DISASM_OPERAND_CONSTANT_TYPE) {
        if (att){
            [line appendRawString:@"$"];
        }
        if (disasm->instruction.branchType != DISASM_BRANCH_NONE) {
            FORMAT(Format_Address);
        }else{
            FORMAT(Format_Hexadecimal);
        }
        [line append:[file formatNumber:operand->immediateValue at:disasm->virtualAddr usingFormat:format andBitSize:operand->size]];
    }
    else if (operand->type & DISASM_OPERAND_REGISTER_TYPE) {
        // Single register
        [self printRegisterType:operand->type line:line disasm:disasm];
    }else if (operand->type & DISASM_OPERAND_MEMORY_TYPE) {
        if (!att){
            [line appendRawString:intelPtrs[operand->size == 8 ? 0 : (operand->size == 32 ? 2 : 1)]];
        }
        if (operand->segmentReg){
            [self printRegisterIndex:operand->segmentReg ofClass:RegClass_X86_SEG line:line disasm:disasm];
            [line appendRawString:@":"];
        }
        //att disp
        if (att && operand->memory.displacement){
            FORMAT(Format_Hexadecimal);
            [line append:[file formatNumber:operand->memory.displacement at:disasm->virtualAddr usingFormat:format andBitSize:16]];
            if (!operand->memory.baseRegistersMask && !operand->memory.indexRegistersMask){
                return line;
            }
        }
        [line appendRawString:att ? @"(" : @"["];
        //base
        if (operand->memory.baseRegistersMask) {
            int regIdx = firstBitIndex(operand->memory.baseRegistersMask);
            [self printRegisterIndex:regIdx ofClass:RegClass_GeneralPurposeRegister line:line disasm:disasm];
            memFilled = true;
        }
        //index
        if (operand->memory.indexRegistersMask){
            if (memFilled){
                [line appendRawString:att ? @"," : @"+"];
            }
            regIdx = firstBitIndex(operand->memory.indexRegistersMask);
            [self printRegisterIndex:regIdx ofClass:RegClass_GeneralPurposeRegister line:line disasm:disasm];
            if(operand->memory.scale>1){
                [line appendRawString:att ? @"," : @"*"];
                [line append:[file formatNumber:operand->memory.scale at:disasm->virtualAddr usingFormat:Format_Decimal andBitSize:16]];
            }
            memFilled = true;
        }
        //intel disp
        if (!att && (operand->memory.displacement || !memFilled) ){
            if (memFilled){
                [line appendRawString:@"+"];
            }
            FORMAT(Format_Hexadecimal);
            [line append:[file formatNumber:operand->memory.displacement at:disasm->virtualAddr usingFormat:format andBitSize:16]];
        }
        [line appendRawString:att ? @")" : @"]"];
    }else{
        [line appendRawString:[NSString stringWithCString:operand->userString encoding:NSASCIIStringEncoding]];
    }

    [line setIsOperand:operandIndex startingAtIndex:0];

    return line;
}

- (NSObject<HPASMLine> *)buildCompleteOperandString:(DisasmStruct *)disasm inFile:(NSObject<HPDisassembledFile> *)file raw:(BOOL)raw {
    NSObject<HPHopperServices> *services = _cpu.hopperServices;

    NSObject<HPASMLine> *line = [services blankASMLine];

    for (int op_index=0; op_index<=DISASM_MAX_OPERANDS; op_index++) {
        NSObject<HPASMLine> *part = [self buildOperandString:disasm forOperandIndex:op_index inFile:file raw:raw];
        if (part == nil) break;
        if (op_index) [line appendRawString:@", "];
        [line append:part];
    }

    return line;
}

// Decompiler

- (BOOL)canDecompileProcedure:(NSObject<HPProcedure> *)procedure {
    return NO;
}

- (Address)skipHeader:(NSObject<HPBasicBlock> *)basicBlock ofProcedure:(NSObject<HPProcedure> *)procedure {
    return basicBlock.from;
}

- (Address)skipFooter:(NSObject<HPBasicBlock> *)basicBlock ofProcedure:(NSObject<HPProcedure> *)procedure {
    return basicBlock.to;
}

- (ASTNode *)rawDecodeArgumentIndex:(int)argIndex
                           ofDisasm:(DisasmStruct *)disasm
                  ignoringWriteMode:(BOOL)ignoreWrite
                    usingDecompiler:(Decompiler *)decompiler {
    return nil;
}

- (ASTNode *)decompileInstructionAtAddress:(Address)a
                                    disasm:(DisasmStruct *)d
                                 addNode_p:(BOOL *)addNode_p
                           usingDecompiler:(Decompiler *)decompiler {
    return nil;
}

// Assembler

- (NSData *)assembleRawInstruction:(NSString *)instr atAddress:(Address)addr forFile:(NSObject<HPDisassembledFile> *)file withCPUMode:(uint8_t)cpuMode usingSyntaxVariant:(NSUInteger)syntax error:(NSError **)error {
    return nil;
}

- (BOOL)instructionCanBeUsedToExtractDirectMemoryReferences:(DisasmStruct *)disasmStruct {
    return NO;
}

- (BOOL)instructionOnlyLoadsAddress:(DisasmStruct *)disasmStruct {
    char* ins=disasmStruct->instruction.mnemonic;
    return ins[0]=='l' && (ins[1]=='e' || ins[1]=='d') && (ins[2]=='a' || ins[2]=='s');
}


- (BOOL)instructionMayBeASwitchStatement:(DisasmStruct *)disasmStruct {
    return NO;
}

- (uint8_t)cpuModeForNextInstruction:(nonnull DisasmStruct *)disasmStruct {
    return 0;
}


- (BOOL)instructionConditionsCPUModeAtTargetAddress:(nonnull DisasmStruct *)disasmStruct resultCPUMode:(nonnull uint8_t *)cpuMode {
    return NO;
}


- (BOOL)instructionManipulatesFloat:(nonnull DisasmStruct *)disasmStruct {
    return NO;
}




@end
