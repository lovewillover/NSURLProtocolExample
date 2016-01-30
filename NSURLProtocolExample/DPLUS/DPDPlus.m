//
//  DPDPlus.m
//  DPDplus
//
//  Created by hewig on 5/19/15.
//  Copyright (c) 2015 fourplex. All rights reserved.
//

#import "DPDPlus.h"
#import <dispatch/dispatch.h>
#import <mach/mach_time.h>

#define DPDPLUS [DPDPlus sharedInstance]

#pragma mark - DPDPlus

@interface DPDPlus()

@property (strong) NSMutableDictionary *cache;
@property (strong) NSMutableDictionary *reverseCache;
@property (strong) NSMutableArray * hosts;

@property (nonatomic, strong) NSOperationQueue *networkQueue;
@property (nonatomic, assign) NSTimeInterval requestTimeout;
@property (strong) NSMutableDictionary *timers;
@end

@implementation DPDPlus

- (instancetype)init
{
    self = [super init];
    if (self) {
        _cache = [NSMutableDictionary new];
        _reverseCache = [NSMutableDictionary new];

        _hosts = [NSMutableArray new];
        _timers = [NSMutableDictionary new];
        _networkQueue = [NSOperationQueue new];
        _networkQueue.name = @"in.fourplex.DPDPlus.network";
        
        _requestTimeout = 3;

    }
    return self;
}


- (void)registerDomains:(NSArray *)domains
{
    for (NSString *domain in domains) {
        [self.hosts addObject:domain];
        [self resolveDomain:domain];
    }
}

- (void)resolveDomain:(NSString *)domain
{
    DPDPOperation *operation = [DPDPOperation new];
    operation.domain = domain;
    operation.encrypt = [DPDEncrypt encrypt:domain];
    
    __weak DPDPOperation *weakOperation = operation;
    __weak DPDPlus * weakSelf = self;
    [operation setCompletionBlock:^{
        DPDPOperation *strongOperation = weakOperation;
        if (!strongOperation.error) {
            NSLog(@"%@", strongOperation.resultRecord);
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf updateTTLTimerForRecord:strongOperation.resultRecord];
            });
        }
    }];
    
    NSLog(@"==> start resolving %@", domain);
    [self.networkQueue addOperation:operation];
}

- (void)updateTTLTimerForRecord:(DPDPRecord *)record
{
    if (record == nil || record.host == nil) {
        return;
    }
    
    if (record.ips.count > 0) {
        for (NSString *ip in record.ips) {
            self.reverseCache[ip] = record.host;
        }
        self.cache[record.host] = record;
       
    }
    
    NSString *domain = record.host;
    if (record.ips.count > 0) {
        for (NSString *ip in record.ips) {
            self.reverseCache[ip] = record.host;
        }
        self.cache[record.host] = record;
    }
    
    NSDictionary *timerInfo = self.timers[domain];
    NSTimer *domainTimer = timerInfo[@"TimerValue"];
    
    if (domainTimer) {
        [domainTimer invalidate];
        domainTimer = nil;
    }
    
    domainTimer = [NSTimer scheduledTimerWithTimeInterval:record.ttl * 0.8
                                                   target:self
                                                 selector:@selector(timerFired:)
                                                 userInfo:@{@"Record":record}
                                                  repeats:NO];
    
}
- (void)timerFired:(NSTimer *)timer
{
    NSDictionary *userInfo = timer.userInfo;
    if (userInfo) {
        DPDPRecord * record = [userInfo valueForKey:@"Record"];
        if (record) {
            record.isTimeOut = YES;
        }
    }
}
- (void)updateCache
{
    NSArray *domains = [NSArray arrayWithArray:self.hosts];
    
    [self cancelAllTimers];
    [self.hosts removeAllObjects];
    [self.reverseCache removeAllObjects];
    [self.cache removeAllObjects];
    
    [self registerDomains:domains];
}

- (void)cancelTimerWithName:(NSString *)name
{
    
    NSTimer *timer = self.timers[name][@"TimerValue"];
    if (timer) {
        [timer invalidate];
        [self.timers removeObjectForKey:name];
    }
}

- (void)cancelAllTimers
{
    for (NSString *name in self.timers.allKeys) {
        [self cancelTimerWithName:name];
    }
}


#pragma mark Class Methods

+(instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    static DPDPlus *instance = nil;
    dispatch_once(&onceToken, ^{
        instance = [DPDPlus new];
    });
    return instance;
}

+ (NSTimeInterval)now
{
    static mach_timebase_info_data_t info;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{ mach_timebase_info(&info); });
    
    NSTimeInterval t = mach_absolute_time();
    t *= info.numer;
    t /= info.denom;
    return t / NSEC_PER_SEC;
}

+ (void)setRequestTimeout:(NSTimeInterval)timeout
{
    DPDPLUS.requestTimeout = timeout;
}

+ (void)registerDomains:(NSArray *)domains
{
    [DPDPLUS registerDomains:domains];
}

+ (void)updateCache
{
    [DPDPLUS updateCache];
}

+ (DPDPRecord *)ipAddressesForDomain:(NSString *)domain
{
    if (domain == nil || domain.length == 0) {
        return nil;
    }
    DPDPRecord *record = [DPDPLUS.cache objectForKey:domain];
    return record;
}

+ (void)applyHTTPDNSForRequest:(NSMutableURLRequest *)request
{
    if (!request) {
        return;
    }
    NSURL *url = request.URL;
    NSString *host = url.host;
    if (DPDPLUS.cache[host]) {
        DPDPRecord *record = DPDPLUS.cache[host];
        if ([record.ips firstObject]) {
            NSString *urlString = url.absoluteString;
            NSString * ip = [record.ips objectAtIndex:arc4random_uniform((uint)[record.ips count])];
            urlString = [urlString stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@://%@", url.scheme, url.host]withString:[NSString stringWithFormat:@"%@://%@", url.scheme, ip]];
            request.URL = [NSURL URLWithString:urlString];
            [request setValue:host forHTTPHeaderField:@"Host"];
            
        }
    }}

+ (NSMutableArray *)getAllIPSAtLocal {
    NSMutableArray * ips = [[NSMutableArray alloc] initWithCapacity:0];
    
    for (DPDPRecord * record in [DPDPLUS.cache allValues]) {
        NSArray * normalIPS = record.ips;
        for (NSString *ip in normalIPS) {
            if ([ips indexOfObject:ip] == NSNotFound) {
                [ips addObject:ip];
            }
        }
    }
    
    return ips;
}

+ (BOOL) needFetchDNSList:(NSString *)domain {
    if ([DPDPLUS.hosts indexOfObject:domain] != NSNotFound) {
        return YES;
    }
    NSString *regex = @"[A-Z0-9a-z._%+-]+.jumei.com";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    BOOL isJumei = [predicate evaluateWithObject:domain];
    
    return isJumei;
    
}

@end
