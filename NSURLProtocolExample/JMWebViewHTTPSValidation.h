//
//  JMWebViewHTTPSValidation.h
//  NSURLProtocolExample
//
//  Created by admin on 16/1/22.
//  Copyright © 2016年 lujb. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface JMWebViewHTTPSValidation : NSObject
+(instancetype)sharedInstance;
- (BOOL)HTTPSValidationWithRequest:(NSURLRequest *)request andWebView:(UIWebView *)webView;
@end

