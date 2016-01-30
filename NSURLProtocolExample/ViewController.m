//
//  ViewController.m
//  NSURLProtocolExample
//
//  Created by lujb on 15/6/15.
//  Copyright (c) 2015年 lujb. All rights reserved.
//

#import "ViewController.h"
#import <AFNetworking/AFNetworking.h>
#import "DPDPlus.h"
#import "JMWebViewHTTPSValidation.h"
@interface ViewController ()<UITextFieldDelegate,NSURLConnectionDataDelegate,NSURLConnectionDelegate,UIWebViewDelegate>
{


}
@property (weak, nonatomic) IBOutlet UITextField *urlTextField;
@property (weak, nonatomic) IBOutlet UIButton *go;

@property (weak, nonatomic) IBOutlet UIWebView *webView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [DPDPlus registerDomains:@[@"mobi.jumei.com",@"baidu.com",@"sina.com",@"h5.jumei.com"]];

    self.webView.delegate = self;
    

}


- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request

 navigationType:(UIWebViewNavigationType)navigationType{

    
  BOOL isContinue =  [[JMWebViewHTTPSValidation sharedInstance]HTTPSValidationWithRequest:request andWebView:webView];
    
    if (!isContinue) {
        return NO;
    }
    return YES;
    
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)go:(id)sender {
    if ([self.urlTextField isFirstResponder]) {
        [self.urlTextField resignFirstResponder];
    }

    UIButton * button = sender;
    if (button.selected) {
        button.selected = NO;
        self.urlTextField.text = @"https://www.google.hk";
    }
    else{
        button.selected = YES;
        self.urlTextField.text = @"https://h5.jumei.com/activity/signin/index";
    }
    
    [self sendRequest];

}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    
    [self sendRequest];
    
    return YES;
}

#pragma mark - request

- (void) sendRequest {
    
    NSString *text = self.urlTextField.text;
    if (![text isEqualToString:@""]) {
        NSURL *url = [NSURL URLWithString:text];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [self.webView loadRequest:request];
    }
    
}
- (IBAction)afnetworkingGo:(id)sender {
    
    NSString * url;
    
    
    UIButton * button = sender;
    if (button.selected) {
        button.selected = NO;
        url = @"https://app-tongdao.liepin.com/a/t/sns/feed/pages.json";
    }
    else{
        button.selected = YES;
         url = @"https://mobi.jumei.com/api/v1/common/init?appfirstinstall=1&platform=android&is_first_open=1&source=meizu&client_v=3.459&site=bj";
    }
   
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    [manager GET:url parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *bookInfo = (NSDictionary*)responseObject;
        NSLog(@"url=%@",operation.request.URL);
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"request faile:%@",error);
    }];


}

@end
