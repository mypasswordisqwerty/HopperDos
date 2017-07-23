//
//  OpComments.h
//  Intel16CPU
//
//  Created by john on 22.07.17.
//  Copyright © 2017 bjfn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Hopper/Hopper.h>
#import "Intel16CPU.h"

@interface OpComment : NSObject

- (instancetype)init;
+(NSString*)commentForOpcode:(DisasmStruct*)disasm CPU:(Intel16CPU*)cpu;

@end
