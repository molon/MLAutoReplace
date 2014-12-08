//
//  ObjcRuntime.h
//  MolonFrame
//
//  Created by Molon on 13-10-20.
//  Copyright (c) 2013年 Molon. All rights reserved.
//

#import <Foundation/Foundation.h>

//根据类名称获取类
//系统就提供 NSClassFromString(NSString *clsname)

//获取一个类的所有属性名字:类型的名字，具有@property的, 父类的获取不了！
NSDictionary *GetPropertyListOfObject(NSObject *object);
NSDictionary *GetPropertyListOfClass(Class cls);

//移魂大法，俩方法移形换位
void Swizzle(Class c, SEL origSEL, SEL newSEL);