//
//  Intel16Ctx.h
//  Intel16CPU
//
//  Created by john on 01.04.17.
//  Copyright © 2017 bjfn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Hopper/Hopper.h>

@class Intel16CPU;

@interface Intel16Ctx : NSObject<CPUContext>

- (instancetype)initWithCPU:(Intel16CPU *)cpu andFile:(NSObject<HPDisassembledFile> *)file;

@end
