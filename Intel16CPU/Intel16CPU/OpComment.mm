//
//  OpComments.m
//  Intel16CPU
//
//  Created by john on 22.07.17.
//  Copyright © 2017 bjfn. All rights reserved.
//

#import "OpComment.h"

@implementation OpComment {
    NSDictionary* ports;
}

+(NSString*)commentForOpcode:(DisasmStruct*)disasm CPU:(Intel16CPU*)cpu {
    static OpComment *opc = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        opc = [[OpComment alloc] init];
    });
    switch (disasm->instruction.userData){
        case X86_INS_OUT:
            return [opc getOutDescr:disasm CPU:cpu];
    }
    return nil;
}

- (instancetype)init {
    if ( self == [super init]){
        //load ports
        NSBundle *bundle  = [NSBundle bundleForClass:[Intel16CPU class]];
        NSString *fname=[bundle pathForResource:@"ports" ofType:@"json"];
        NSLog(@"resource file at %@", fname);
        NSData *data = [NSData dataWithContentsOfFile:fname];
        if (data){
            NSError *e = nil;
            ports = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&e];
            if (!ports || e){
                NSLog(@"Can't load ports %@", e);
            }
        }else{
            NSLog(@"Can't load file%@", fname);
        }
    }
    return self;
}

- (uint64_t)operandValue:(DisasmStruct*)disasm CPU:(Intel16CPU*)cpu intl:(int)intl att:(int)att {
    DisasmOperand *op=&disasm->operand[ (disasm->syntaxIndex & 1) ? att : intl];
    uint64_t val = UNDEFINED_STATE;
    if (op->type & DISASM_OPERAND_CONSTANT_TYPE){
        val = op->immediateValue;
    }else if (op->type & DISASM_OPERAND_REGISTER_TYPE){
        val = [cpu getCapstoneReg:(x86_reg)op->userData[0]];
    }
    return val;
}

- (NSString*)getOutDescr:(DisasmStruct*)disasm CPU:(Intel16CPU*)cpu {
    uint64_t val = [self operandValue:disasm CPU:cpu intl:0 att:1];
    if (val==UNDEFINED_STATE){
        return nil;
    }
    return ports ? [ports objectForKey:[NSString stringWithFormat:@"%04X", (uint32_t)val]] : nil;
}

@end
