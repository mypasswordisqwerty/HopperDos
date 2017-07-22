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
    if (!strcmp(disasm->instruction.mnemonic, "out")){
        return [NSString stringWithFormat:@"          ;Comment for opcode %s\r\n;and more", disasm->instruction.mnemonic];
    }
    return nil;
}

@end
