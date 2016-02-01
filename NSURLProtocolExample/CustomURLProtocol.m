//
//  CustomURLProtocol.m
//  NSURLProtocolExample
//
//  Created by lujb on 15/6/15.
//  Copyright (c) 2015年 lujb. All rights reserved.
//

#import "CustomURLProtocol.h"
#import "WBDNSCache.h"
#import "DPDPlus.h"

static NSString * const URLProtocolHandledKey = @"URLProtocolHandledKey";

@interface CustomURLProtocol ()<NSURLConnectionDelegate>

@property (strong, nonatomic) NSURLConnection *connection;


@end
static NSMutableArray * trustedCerts;
@implementation CustomURLProtocol

+(void)initialize
{
    
    NSMutableArray * certsFile = [NSMutableArray arrayWithObjects: @"jumei", nil];
    
    trustedCerts = [NSMutableArray array];
    
    for (NSString *file in certsFile) {
        
        NSString *fpath = [[NSBundle mainBundle] pathForResource:file ofType:@"cer"];
        
        NSData * cerData = [NSData dataWithContentsOfFile:fpath];
        
        SecCertificateRef certificate = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)(cerData));
        [trustedCerts addObject:CFBridgingRelease(certificate)];
        
    }
    
}



+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    //只处理http和https请求
    NSString *scheme = [[request URL] scheme];
    if ( ([scheme caseInsensitiveCompare:@"http"] == NSOrderedSame ||
          [scheme caseInsensitiveCompare:@"https"] == NSOrderedSame))
    {
        //看看是否已经处理过了，防止无限循环
        if ([NSURLProtocol propertyForKey:URLProtocolHandledKey inRequest:request]) {
            return NO;
        }
        
        return YES;
    }
    return NO;
}

+ (NSURLRequest *) canonicalRequestForRequest:(NSURLRequest *)request {
    //    NSMutableURLRequest *mutableReqeust = [request mutableCopy];
    //    mutableReqeust = [self redirectHostInRequset:mutableReqeust];
    return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b
{
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (void)startLoading
{
    /* 如果想直接返回缓存的结果，构建一个NSURLResponse对象
     if (cachedResponse) {
     
     NSData *data = cachedResponse.data; //缓存的数据
     NSString *mimeType = cachedResponse.mimeType;
     NSString *encoding = cachedResponse.encoding;
     
     NSURLResponse *response = [[NSURLResponse alloc] initWithURL:self.request.URL
     MIMEType:mimeType
     expectedContentLength:data.length
     textEncodingName:encoding];
     
     [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
     [self.client URLProtocol:self didLoadData:data];
     [self.client URLProtocolDidFinishLoading:self];
     */
    
    
    NSMutableURLRequest *mutableReqeust = [[self request] mutableCopy];
    
    if ([mutableReqeust.URL host].length == 0) {
        return;
    }
    
    NSString *originUrlString = [mutableReqeust.URL absoluteString];
    NSString *originHostString = [mutableReqeust.URL host];
    NSString *scheme = [[mutableReqeust URL] scheme];
    if ([self isJumeiWithHost:originHostString]) {
        
        if (![self isPicResWithURL:originUrlString]) {
//            DPDPRecord * record =[DPDPlus ipAddressesForDomain:originHostString];
//            if (!record || record.isTimeOut) {
//                [DPDPlus registerDomains:@[originHostString]];
//            }
//            [DPDPlus applyHTTPDNSForRequest:mutableReqeust];
            
            NSArray * array =  [[WBDNSCache sharedInstance] getDomainServerIpFromURL:originUrlString];
            
            if (array.count>0) {
                WBDNSDomainInfo * domainInfo = [array firstObject];
                mutableReqeust.URL = [NSURL URLWithString:domainInfo.url];
                [mutableReqeust setValue:domainInfo.host forHTTPHeaderField:@"Host"];
            }
            
            originUrlString = [mutableReqeust.URL absoluteString];
            originHostString = [mutableReqeust.URL host];
            
            NSLog(@"URL = %@",originUrlString);
            NSLog(@"Header = %@",mutableReqeust.allHTTPHeaderFields);
            
        }
        
    }
    
    //打标签，防止无限循环
    [NSURLProtocol setProperty:@YES forKey:URLProtocolHandledKey inRequest:mutableReqeust];
    
    self.connection = [NSURLConnection connectionWithRequest:mutableReqeust delegate:self];
    
}

- (void)stopLoading
{
    [self.connection cancel];
    self.connection = nil;
    
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    
    NSInteger code = error.code;
    if ((code == NSURLErrorSecureConnectionFailed || code == NSURLErrorServerCertificateHasBadDate || code == NSURLErrorServerCertificateUntrusted || code == NSURLErrorServerCertificateHasUnknownRoot || code == NSURLErrorServerCertificateNotYetValid || code == NSURLErrorClientCertificateRejected || code == NSURLErrorClientCertificateRequired) || code == NSURLErrorUserCancelledAuthentication || code == NSURLErrorUserAuthenticationRequired || (code<=-9819 && code>=-9832) || (code<=-9843 && code>=-9848) )
    {
        
        NSMutableURLRequest *mutableReqeust = [[self request] mutableCopy];
        NSString *originUrlString = [mutableReqeust.URL absoluteString];
        NSString *originHostString = [mutableReqeust.URL host];
        if ([self isJumeiWithHost:originHostString]) {
            NSString* scheme = [[connection.currentRequest URL] scheme];
            if ([scheme isEqualToString:@"https"]) {
                originUrlString = [originUrlString stringByReplacingOccurrencesOfString:@"https" withString:@"http"];
            }
            
            [mutableReqeust setURL:[NSURL URLWithString:originUrlString]];
            self.connection = [NSURLConnection connectionWithRequest:mutableReqeust delegate:self];
            [self.connection start];
            return;
        }
        
    }
    
    [self.client URLProtocol:self
            didFailWithError:error];
    
}
//- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
//{
//    if (response != nil)
//    {
//        [[self client] URLProtocol:self wasRedirectedToRequest:request redirectResponse:response];
//    }
//    return request;
//}



-(NSURLRequest*)connection:(NSURLConnection*)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    //// for 302 or 301 redirect;
    
    if(response!=nil){
        
        NSMutableURLRequest* newRequest =[request mutableCopy];
        
        //        [NSURLProtocol removePropertyForKey:URLProtocolHandledKey inRequest:newRequest]; /////// ??????
        
        if([response isKindOfClass:[NSHTTPURLResponse class]]){
            NSHTTPURLResponse* httpRes = (NSHTTPURLResponse*)response;
            if(httpRes.statusCode == 302 || httpRes.statusCode==301){
                /// New URL
                newRequest.URL = [NSURL URLWithString:[[httpRes allHeaderFields] objectForKey:@"Location"]];
            }
        }
        //////
        [[self client ] URLProtocol:self wasRedirectedToRequest:newRequest redirectResponse:response]; ///
        
        return newRequest; /////
    }
    ////////
    return request;
}

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection
{
    return YES;
}

- (void)connection:(NSURLConnection *)connection
didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    [self.client URLProtocol:self
didReceiveAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection
didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    [self.client URLProtocol:self
didCancelAuthenticationChallenge:challenge];
}


- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSURLResponse *)response
{
    [self.client URLProtocol:self
          didReceiveResponse:response
          cacheStoragePolicy:NSURLCacheStorageAllowed];
}

- (void)connection:(NSURLConnection *)connection
    didReceiveData:(NSData *)data
{
    [self.client URLProtocol:self
                 didLoadData:data];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    return cachedResponse;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self.client URLProtocolDidFinishLoading:self];
}


- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge{
    
    
    NSURLConnection * con = challenge.sender;
    NSURLRequest * request = con.currentRequest;
    NSDictionary * httpHeaderFields =  [request allHTTPHeaderFields];
    NSString * host = [httpHeaderFields valueForKey:@"Host"];
    if (!host) {
        host = challenge.protectionSpace.host;
    }
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        
        if ([self isJumeiWithHost:host]) {
            if ([self evaluateServerTrust:challenge.protectionSpace.serverTrust forDomain:host]) {
                NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
                [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
            } else {
                [[challenge sender] cancelAuthenticationChallenge:challenge];
            }
        }
        else{
            NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
        }
        
        
    }
    
    else {
        if ([challenge previousFailureCount] == 0) {
            [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
        } else {
            [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
        }
    }
    
}

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust forDomain:(NSString *)domain{
    
    if ([self isJumeiWithHost:domain]) {
        
        NSMutableArray *policies = [NSMutableArray array];
        //验证域名
        [policies addObject:(__bridge_transfer id)SecPolicyCreateSSL(true, (__bridge CFStringRef)domain)];
        
        SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef)policies);
        
        SecTrustResultType result;
        
        //这里将之前导入的证书设置成下面验证的Trust Object的anchor certificate
        SecTrustSetAnchorCertificates(serverTrust, (__bridge CFArrayRef)trustedCerts);
        
        
        //SecTrustEvaluate会查找前面SecTrustSetAnchorCertificates设置的证书或者系统默认提供的证书，对trust进行验证
        OSStatus status = SecTrustEvaluate(serverTrust, &result);
        if (status == errSecSuccess &&
            (result == kSecTrustResultProceed ||
             result == kSecTrustResultUnspecified)) {
                //验证成功，生成NSURLCredential凭证cred，告知challenge的sender使用这个凭证来继续连接
                NSLog(@"SSL cert match!");
                return YES;
            }
        else {
            //验证失败，取消这次验证流程
            NSLog(@"SSL cert missmatch!");
            return NO;
        }
        
        
    }
    
    return NO;
    
}

-(BOOL)isJumeiWithHost:(NSString *)host{
    
    NSString *regex = @".*.jumei.com";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    BOOL isJumei = [predicate evaluateWithObject:host];
    return isJumei;
}

-(BOOL)isPicResWithURL:(NSString *)originUrlString{
    
    NSString *regex =  @".+(.JPEG|.jpeg|.JPG|.jpg|.GIF|.gif|.BMP|.bmp|.PNG|.png|.css|.CSS|.js|.JS)$";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    BOOL isPic = [predicate evaluateWithObject:originUrlString];
    return isPic;
}


@end
