//
//  Intel16CPU.h
//  Intel16CPU
//
//  Created by john on 01.04.17.
//  Copyright © 2017 bjfn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Hopper/Hopper.h>

typedef NS_ENUM(NSUInteger, GRegs) {
    AH, AL, BH, BL, CH, CL, DH, DL, AX, BX, CX, DX, BP, SP, SI, DI, IP,
};

typedef NS_ENUM(NSUInteger, SRegs) {
    CS, DS, ES, SS
};


@interface Intel16CPU : NSObject<CPUDefinition>

- (NSObject<HPHopperServices> *)hopperServices;

@end
