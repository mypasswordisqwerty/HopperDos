//
//  Intel16CPU.h
//  Intel16CPU
//
//  Created by john on 01.04.17.
//  Copyright © 2017 bjfn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Hopper/Hopper.h>
#include <capstone/capstone.h>

typedef NS_ENUM(NSUInteger, GRegs) {
    AH, AL, BH, BL, CH, CL, DH, DL, AX, BX, CX, DX, BP, SP, SI, DI, IP,
    EAX, EBX, ECX, EDX, EBP, ESP, ESI, EDI, EIP
};

#define UNDEFINED_STATE     ((int64_t)-1)

@interface Intel16CPU : NSObject<CPUDefinition>

- (NSObject<HPHopperServices> *)hopperServices;

- (NSUInteger)capstoneToRegIndex:(x86_reg)reg;
- (RegClass)capstoneToRegClass:(x86_reg)reg;
- (void)clearState;
- (void)updateState:(DisasmStruct*)disasm;
- (int64_t)valueReg:(NSUInteger)reg ofClass:(RegClass)rclass;

@end
