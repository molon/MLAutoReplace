//
//  ClassProperties.m
//
//
//  Created by Molon on 13-12-10.
//  Copyright (c) 2013年 Molon. All rights reserved.
//

#import "ClassProperties.h"
#import "ObjcRuntime.h"

@interface ClassProperties()

@property (nonatomic, strong) NSMutableDictionary *dict;

@end

@implementation ClassProperties

+ (instancetype)shareInstance {
    static ClassProperties *_shareInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shareInstance = [[ClassProperties alloc]init];
    });
    return _shareInstance;
}

- (NSMutableDictionary*)dict
{
    if (!_dict) {
        _dict = [[NSMutableDictionary alloc]init];
    }
    return _dict;
}

- (NSDictionary *)getPropertiesOfClass:(Class)cls
{
    NSString *clsname = NSStringFromClass(cls);
    if (!self.dict[clsname]) {
        [self.dict setValue:GetPropertyListOfClass(cls) forKey:clsname];
    }
    return self.dict[clsname];
}

//得到属性直到某个父类为止，包括此父类
- (NSDictionary *)getPropertiesOfClass:(Class)cls untilSuperClass:(Class)supercls
{
    NSString *clsname =  [NSString stringWithFormat:@"%@-%@",NSStringFromClass(cls),NSStringFromClass(supercls)];
    if (!self.dict[clsname]) {
        NSAssert([cls isSubclassOfClass:supercls]&&![NSStringFromClass(cls) isEqualToString:NSStringFromClass(supercls)], @"getPropertiesOfClass:untilSuperClass:父类传递错误");
        
        Class supersupercls = [supercls superclass]; //因为要包括当前supercls 所以需要如此
        if (!supersupercls) {
            supersupercls = [NSObject class];
        }
        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        Class currentcls = cls;
        do {
            NSDictionary *properties = [self getPropertiesOfClass:currentcls];
            
            [result addEntriesFromDictionary:properties];
            
            currentcls = [currentcls superclass];
        } while (currentcls&&![NSStringFromClass(currentcls) isEqualToString:NSStringFromClass(supersupercls)]);
        
        
        [self.dict setValue:result forKey:clsname];
    }
    return self.dict[clsname];
}

@end
