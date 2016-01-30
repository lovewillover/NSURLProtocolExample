//
//  DPDPOperation.m
//  DPDplus
//
//  Created by hewig on 5/19/15.
//  Copyright (c) 2015 fourplex. All rights reserved.
//

#import "DPDPOperation.h"


@interface DPDPOperation ()

@property (nonatomic, strong, readwrite) DPDPRecord *resultRecord;
@property (nonatomic, strong, readwrite) NSError *error;

@end

@implementation DPDPOperation

- (instancetype)init
{
    self = [super init];
    if (self) {
        _requestTimeout = 3;
    }
    return self;
}

- (void)main
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/d?ttl=1&dn=%@&id=%@", kDPDPHost, self.encrypt, DPLUSId]];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:self.requestTimeout];
    
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    if (error) {
        self.error = error;
    } else {
        if (data.length == 0) {
            NSLog(@"empty response, DNSPod resolve failed?");
            return;
        }
        
        NSString *dataString = [DPDEncrypt decrypt:data];
        NSMutableDictionary * dic = [NSMutableDictionary dictionary];
        [dic setValue:dataString forKey:[NSString stringWithFormat:@""]];
        DPDPRecord *record = [[DPDPRecord alloc] initWithResponseString:dataString];
        record.host = self.domain;
        self.resultRecord = record;
    }
}

@end
