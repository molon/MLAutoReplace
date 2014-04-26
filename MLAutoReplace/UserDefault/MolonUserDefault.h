//
//  MolonUserDefault.h
//  InventoryTool
//
//  Created by molon on 3/7/14.
//  Copyright (c) 2014 Molon. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MolonUserDefault : NSObject

@property (nonatomic,assign) BOOL isUseAutoReIndent;

+ (instancetype)shareInstance;

@end
