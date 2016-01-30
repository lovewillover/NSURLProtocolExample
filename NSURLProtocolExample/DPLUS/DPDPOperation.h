//
//  DPDPOperation.h
//  DPDplus
//
//  Created by hewig on 5/19/15.
//  Copyright (c) 2015 fourplex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DPDPlus.h"
@class DPDPRecord;
static NSString *kDPDPHost = @"119.29.29.29";
@interface DPDPOperation : NSOperation

@property (nonatomic, strong) NSString *domain;
@property (nonatomic, assign) NSTimeInterval requestTimeout;
@property (nonatomic, readonly) NSError *error;
@property (nonatomic, readonly) DPDPRecord *resultRecord;
@property (nonatomic, strong) NSString *encrypt;

@end
