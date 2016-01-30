//
//  DPDEncrypt.h
//  Pods
//
//  Created by admin on 16/1/21.
//
//

#import <Foundation/Foundation.h>

#import "DPDPlus.h"
@interface DPDEncrypt : NSObject


+ (NSString *)encrypt:(NSString*)domain;
+ (NSString *)decrypt:(NSData*)raw ;

@end
