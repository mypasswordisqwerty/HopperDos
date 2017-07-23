//
//  OpComments.m
//  Intel16CPU
//
//  Created by john on 22.07.17.
//  Copyright © 2017 bjfn. All rights reserved.
//

#import "OpComment.h"

@implementation OpComment {
}

+(NSString*)commentForOpcode:(DisasmStruct*)disasm CPU:(Intel16CPU*)cpu {
    static OpComment *opc = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        opc = [[OpComment alloc] init];
    });
    if (disasm->instruction.userData == X86_INS_OUT){
        DisasmOperand *op=&disasm->operand[0];
        if (disasm->syntaxIndex & 1){
            op=&disasm->operand[1];
        }
        uint64_t val=0;
        if (op->type & DISASM_OPERAND_CONSTANT_TYPE){
            val = op->immediateValue;
        }else if (op->type & DISASM_OPERAND_REGISTER_TYPE){
            val = [cpu getCapstoneReg:(x86_reg)op->userData[0]];
        }
        return [NSString stringWithFormat:@"out comment %04X\n and more", (uint32_t)val];
    }
    return nil;
}

@end
