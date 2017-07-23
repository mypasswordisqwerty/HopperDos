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
    NSDictionary* ints;
}

+(NSString*)commentForOpcode:(DisasmStruct*)disasm CPU:(Intel16CPU*)cpu {
    static OpComment *opc = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        opc = [[OpComment alloc] init];
    });
    switch (disasm->instruction.userData){
        case X86_INS_OUT:
            return [opc getPortDescr:disasm CPU:cpu isIn:NO];
        case X86_INS_IN:
            return [opc getPortDescr:disasm CPU:cpu isIn:YES];
        case X86_INS_INT:
            return [opc getIntDescr:disasm CPU:cpu];
    }
    return nil;
}

- (instancetype)init {
    if ( self == [super init]){
        //load ports
        NSBundle *bundle  = [NSBundle bundleForClass:[Intel16CPU class]];
        NSString *fname=[bundle pathForResource:@"ports" ofType:@"json"];
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
        fname=[bundle pathForResource:@"ints" ofType:@"json"];
        data = [NSData dataWithContentsOfFile:fname];
        if (data){
            NSError *e = nil;
            ints = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&e];
            if (!ints || e){
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

- (NSString*)getPortDescr:(DisasmStruct*)disasm CPU:(Intel16CPU*)cpu isIn:(BOOL)isIn {
    uint64_t val = [self operandValue:disasm CPU:cpu intl:(isIn ? 1 : 0) att:(isIn ? 0 : 1)];
    if (val==UNDEFINED_STATE || !ports){
        return nil;
    }
    return [ports objectForKey:[NSString stringWithFormat:@"%04X", (uint32_t)val]];
}

- (NSString*)getValue:(NSDictionary*)dict forReg:(x86_reg)reg CPU:(Intel16CPU*)cpu size:(int)size {
    if (!dict){
        return nil;
    }
    uint64_t val = [cpu getCapstoneReg:reg];
    if (val == UNDEFINED_STATE){
        return nil;
    }
    static NSString *fmts[] = {@"%01X", @"%02X", @"%03X", @"%04X"};
    return [dict objectForKey:[NSString stringWithFormat:fmts[size-1], val]];
}

- (NSString*)getIntDescr:(DisasmStruct*)disasm CPU:(Intel16CPU*)cpu {
    uint64_t val = [self operandValue:disasm CPU:cpu intl:0 att:0];
    if (val == UNDEFINED_STATE || !ints){
        return nil;
    }
    NSDictionary* d = [ints objectForKey:[NSString stringWithFormat:@"%02X", (uint32_t)val]];
    if (!d){
        return nil;
    }
    NSString* ret = nil;
    if ((ret = [self getValue:[d objectForKey:@"AH"] forReg:X86_REG_AH CPU:cpu size:1])){
        return ret;
    }
    if ((ret = [self getValue:[d objectForKey:@"AL"] forReg:X86_REG_AL CPU:cpu size:1])){
        return ret;
    }
    if ((ret = [self getValue:[d objectForKey:@"AX"] forReg:X86_REG_AX CPU:cpu size:2])){
        return ret;
    }
    if ((ret = [self getValue:[d objectForKey:@"BX"] forReg:X86_REG_BX CPU:cpu size:2])){
        return ret;
    }
    if ((ret = [self getValue:[d objectForKey:@"CX"] forReg:X86_REG_CX CPU:cpu size:2])){
        return ret;
    }
    return d[@"name"];
}


@end
