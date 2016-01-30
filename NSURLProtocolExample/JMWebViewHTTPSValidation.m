//
//  JMWebViewHTTPSValidation.m
//  NSURLProtocolExample
//
//  Created by admin on 16/1/22.
//  Copyright © 2016年 lujb. All rights reserved.
//

#import "JMWebViewHTTPSValidation.h"
#import <objc/runtime.h>

//@interface NSURLRequest (CustomURLRequest)
//- (BOOL)getAuthenticated;
//- (void)setAuthenticated:(BOOL)authenticated;
//@end
//
//
//
//@implementation NSURLRequest (CustomURLRequest)
//static void * AuthenticatedKey = (void *)@"AuthenticatedKey";
//- (BOOL)getAuthenticated
//{
//    return [objc_getAssociatedObject(self, AuthenticatedKey)boolValue];
//}
//
//- (void)setAuthenticated:(BOOL)authenticated
//{
//    objc_setAssociatedObject(self, AuthenticatedKey, @(authenticated), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
//}
//
//@end



#import <libkern/OSAtomic.h>

@interface JMWebViewHTTPSValidation()

@property (strong ,nonatomic) NSMutableArray * trustedCerts;
@property (strong ,nonatomic) UIWebView * webView;
@property NSURLResponse *response;
@property NSURLConnection *connection;
@property NSMutableSet *whiteList;
@property NSMutableData *data;
@property OSSpinLock lock;
@property NSURLRequest *FailedRequest;
@end


@implementation JMWebViewHTTPSValidation




+(instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    static JMWebViewHTTPSValidation *instance = nil;
    dispatch_once(&onceToken, ^{
        instance = [JMWebViewHTTPSValidation new];
    });
    return instance;
}


- (instancetype)init
{
    self = [super init];
    if (self) {

           NSMutableArray * certsFile = [NSMutableArray arrayWithObjects: @"jumei", nil];
            
            self.trustedCerts = [NSMutableArray array];
            
            for (NSString *file in certsFile) {
                
                NSString *fpath = [[NSBundle mainBundle] pathForResource:file ofType:@"cer"];
                
                NSData * cerData = [NSData dataWithContentsOfFile:fpath];
                
                SecCertificateRef certificate = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)(cerData));

                [self.trustedCerts addObject:CFBridgingRelease(certificate)];
                
            }

        _whiteList = [[NSMutableSet alloc] initWithCapacity:0];
        _data = [[NSMutableData alloc] init];
        
    }
    return self;
}


- (BOOL)HTTPSValidationWithRequest:(NSURLRequest *)request andWebView:(UIWebView *)webView{
    _webView = webView;
    NSURL *requestURL =[request URL];
    NSLog(@"this is web url : %@",requestURL);
    
    
    NSURL *url = [request URL];
    NSString *schema = [[url scheme] lowercaseString];
    NSString *host = [url host];
    
    NSString *regex = @"[A-Z0-9a-z._%+-]+.jumei.com";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    BOOL isJumei = [predicate evaluateWithObject:host];
    
    NSString* scheme = [[request URL] scheme];
    if ([scheme isEqualToString:@"https"]&&isJumei) {
        //如果是https:的话，那么就用NSURLConnection来重发请求。从而在请求的过程当中吧要请求的URL做信任处理。
        
        [self _lock];
        BOOL result = [_whiteList containsObject:[request URL]];
        [self _unlock];
        if (!result) {
            _FailedRequest = request;
            _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
            [_webView stopLoading];
        }
        return result;
    }
    
    return YES;
}

//- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
//    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
//        [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
//    }
//    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
//}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [self _lock];
    [_whiteList addObject:[_FailedRequest URL]];
    [self _unlock];
    _FailedRequest = nil;
    _response = response;
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSString *str = [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding];
    [_webView loadHTMLString:str baseURL:[_response URL]];
    [_data setLength:0];
    _response = nil;
}
- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}
//NSURLConnection的委托方法，
- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
        [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
    
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
    
}

- (void)_lock {
    OSSpinLockLock(&_lock);
}

- (void)_unlock {
    OSSpinLockUnlock(&_lock);
}





//#pragma mark ------ NSURLConnectionDataDelegate
//-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)pResponse {
////    [self.failedRequest setAuthenticated:YES];
//    self.authenticated = YES;
//    [connection cancel];
//    　　 //验证通过，继续执行之前被拦截下来的请求
//    [self.webView loadRequest:self.failedRequest];
//}
//
//
#pragma mark ------ NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge{
    NSLog(@"Check ssl cert.");
    
    //获取trust object
    SecTrustRef trust = challenge.protectionSpace.serverTrust;
    
    //验证域名
    NSString * domain =@"*.jumei.com";
    NSMutableArray *policies = [NSMutableArray array];
    
    [policies addObject:(__bridge_transfer id)SecPolicyCreateSSL(true, (__bridge CFStringRef)domain)];
    
    SecTrustSetPolicies(trust, (__bridge CFArrayRef)policies);
    
    
    SecTrustResultType result;
    
    
    //这里将之前导入的证书设置成下面验证的Trust Object的anchor certificate
    SecTrustSetAnchorCertificates(trust, (__bridge CFArrayRef)self.trustedCerts);
    
    
    //SecTrustEvaluate会查找前面SecTrustSetAnchorCertificates设置的证书或者系统默认提供的证书，对trust进行验证
    OSStatus status = SecTrustEvaluate(trust, &result);
    if (status == errSecSuccess &&
        (result == kSecTrustResultProceed ||
         result == kSecTrustResultUnspecified)) {
            //验证成功，生成NSURLCredential凭证cred，告知challenge的sender使用这个凭证来继续连接
            NSURLCredential *cred = [NSURLCredential credentialForTrust:trust];
            [challenge.sender useCredential:cred forAuthenticationChallenge:challenge];
            NSLog(@"SSL cert match!");
        }
    else {
        //验证失败，取消这次验证流程
        [challenge.sender cancelAuthenticationChallenge:challenge];
        NSLog(@"SSL cert missmatch!");
    }
    
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}





@end
