//
//  DPDPlus.h
//  DPDplus
//
//  Created by hewig on 5/19/15.
//  Copyright (c) 2015 fourplex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DPDPRecord.h"
#import "DPDEncrypt.h"
#import "DPDPOperation.h"

#define DPLUSId @"128"
#define DPLUSKey @"sQW9<Fzq"
@interface DPDPlus : NSObject

// DNSPod http request timeout
+ (void)setRequestTimeout:(NSTimeInterval)timeout;

// Domains to resolve
+ (void)registerDomains:(NSArray *)domains;

// Force update cache
+ (void)updateCache;

// IP addresses for domain
+ (DPDPRecord *)ipAddressesForDomain:(NSString *)domain;

// Update HTTP request, replace domain with ip, set Host header
+ (void)applyHTTPDNSForRequest:(NSMutableURLRequest *)request;

// Helper method for HTTPS request used in delegate method
// -(void)connection:willSendRequestForAuthenticationChallenge
// -(void)URLSession:didReceiveChallenge:completionHandler:
//+ (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust
//                  forDomain:(NSString *)domain;

// Timestamp mach_absolute_time
+ (NSTimeInterval)now;

+ (BOOL) needFetchDNSList:(NSString *)domain;

+ (NSMutableArray *)getAllIPSAtLocal;
@end
