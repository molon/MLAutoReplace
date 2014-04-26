//
//  ClassProperties.h
//
//
//  Created by Molon on 13-12-10.
//  Copyright (c) 2013年 Molon. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ClassProperties : NSObject

+ (instancetype)shareInstance;
- (NSDictionary *)getPropertiesOfClass:(Class)cls;

//得到属性直到某个父类为止，包括此父类，记住父类和子类不能有重名不同类型的属性！！
- (NSDictionary *)getPropertiesOfClass:(Class)cls untilSuperClass:(Class)supercls;

@end
