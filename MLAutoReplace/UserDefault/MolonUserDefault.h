//
//  MolonUserDefault.h
//  InventoryTool
//
//  Created by molon on 3/7/14.
//  Copyright (c) 2014 Molon. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MolonUserDefault : NSObject

/**
 *  这里需要继承做初始化赋值，即为默认值
 */
- (void)initValues;

+ (instancetype)shareInstance;

@end
