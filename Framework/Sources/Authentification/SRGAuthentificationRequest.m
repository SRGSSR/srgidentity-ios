//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//


#import "SRGAuthentificationRequest.h"

#import "SRGIdentityLogger.h"

#import <libextobjc/libextobjc.h>

@interface SRGAuthentificationRequest ()

@property(nonatomic) NSURL *serviceURL;
@property(nonatomic) NSString *emailAddress;
@property(nonatomic) NSString *uuid;
@end

@implementation SRGAuthentificationRequest

#pragma mark Object lifecycle

- (instancetype)initWithServiceURL:(NSURL *)serviceURL emailAddress:(NSString *)emailAddress
{
    if (self = [super init])
    {
        self.serviceURL = serviceURL;
        self.emailAddress = emailAddress;
        self.uuid = [[NSUUID UUID] UUIDString];
    }
    return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithServiceURL:[NSURL new] emailAddress:nil];
}

#pragma mark Getters

- (NSString *)redirectScheme
{
    static NSString *s_redirectScheme;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        NSArray *bundleURLTypes = NSBundle.mainBundle.infoDictionary[@"CFBundleURLTypes"];
        if (bundleURLTypes.count > 0) {
            NSArray<NSString *> *bundleURLSchemes = bundleURLTypes.firstObject[@"CFBundleURLSchemes"];
            s_redirectScheme = bundleURLSchemes.firstObject;
        }
        
        if (! s_redirectScheme) {
            SRGIdentityLogError(@"authentification", @"No URL scheme declared in your application Info.plist file under the "
                                "'CFBundleURLTypes' key. The application must at least contains one item with one scheme "
                                "to allow a correct authentification workflow. Take care to have an unique URL scheme.");
        }
    });
    return s_redirectScheme;
}

- (NSURL *)redirectURL
{
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:self.serviceURL resolvingAgainstBaseURL:YES];
    NSArray<NSURLQueryItem *> *queryItems = URLComponents.queryItems ?: @[];
    URLComponents.queryItems = [queryItems arrayByAddingObject:[[NSURLQueryItem alloc] initWithName:@"client" value:self.uuid]];
    URLComponents.scheme = self.redirectScheme;
    return URLComponents.URL;
}

- (NSURL *)URL
{
    NSURL *URL = [NSURL URLWithString:@"responsive/login" relativeToURL:self.serviceURL];
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:YES];
    NSArray<NSURLQueryItem *> *queryItems = @[[[NSURLQueryItem alloc] initWithName:@"withcode" value:@"true"],
                                              [[NSURLQueryItem alloc] initWithName:@"redirect" value:self.redirectURL.absoluteString]];
    if (self.emailAddress) {
        NSURLQueryItem *emailQueryItem = [[NSURLQueryItem alloc] initWithName:@"email" value:self.emailAddress];
        queryItems = [queryItems arrayByAddingObject:emailQueryItem];
    }
    URLComponents.queryItems = queryItems;
    
    return URLComponents.URL;
}

- (BOOL)shouldHandleReponseURL:(NSURL *)URL
{
    BOOL sameUuid = NO;
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(NSURLQueryItem.new, name), @"client"];
    NSURLQueryItem *queryItem = [URLComponents.queryItems filteredArrayUsingPredicate:predicate].firstObject;
    if (queryItem) {
        sameUuid = [self.uuid isEqualToString:queryItem.value];
    }
    
    NSURL *standardizedURL = [URL standardizedURL];
    NSURL *standardizedRedirectURL = [self.redirectURL standardizedURL];
    
    return sameUuid &&
    [standardizedURL.scheme isEqualToString:standardizedRedirectURL.scheme] &&
    [standardizedURL.host isEqualToString:standardizedRedirectURL.host] &&
    [standardizedURL.path isEqual:standardizedRedirectURL.path];
}

@end
