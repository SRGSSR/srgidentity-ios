//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "IdentityBaseTestCase.h"

@import libextobjc;
@import OHHTTPStubs;

static NSString *TestValidToken = @"0123456789";

static NSURL *TestWebserviceURL(void)
{
    return [NSURL URLWithString:@"https://api.srgssr.local"];
}

static NSURL *TestWebsiteURL(void)
{
    return [NSURL URLWithString:@"https://www.srgssr.local"];
}

#if TARGET_OS_IOS

@interface SRGIdentityService (Private)

- (BOOL)handleCallbackURL:(NSURL *)callbackURL;

@property (nonatomic, readonly, copy) NSString *identifier;

@end

static NSURL *TestLoginCallbackURL(SRGIdentityService *identityService, NSString *token)
{
    NSString *URLString = [NSString stringWithFormat:@"srgidentity-tests://%@?identity_service=%@&token=%@", TestWebserviceURL().host, identityService.identifier, token];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestLogoutCallbackURL(SRGIdentityService *identityService)
{
    NSString *URLString = [NSString stringWithFormat:@"srgidentity-tests://%@?identity_service=%@&action=log_out", TestWebserviceURL().host, identityService.identifier];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestAccountDeletedCallbackURL(SRGIdentityService *identityService)
{
    NSString *URLString = [NSString stringWithFormat:@"srgidentity-tests://%@?identity_service=%@&action=account_deleted", TestWebserviceURL().host, identityService.identifier];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestUnauthorizedCallbackURL(SRGIdentityService *identityService)
{
    NSString *URLString = [NSString stringWithFormat:@"srgidentity-tests://%@?identity_service=%@&action=unauthorized", TestWebserviceURL().host, identityService.identifier];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestIgnored1CallbackURL(SRGIdentityService *identityService)
{
    NSString *URLString = [NSString stringWithFormat:@"srgidentity-tests://%@?identity_service=%@&action=unknown", TestWebserviceURL().host, identityService.identifier];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestIgnored2CallbackURL(SRGIdentityService *identityService)
{
    NSString *URLString = [NSString stringWithFormat:@"myapp://%@?identity_service=%@", TestWebserviceURL().host, identityService.identifier];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestIgnored3CallbackURL()
{
    NSString *URLString = [NSString stringWithFormat:@"https://www.srgssr.ch"];
    return [NSURL URLWithString:URLString];
}

#else

@interface SRGIdentityService (Private)

- (BOOL)handleSessionToken:(NSString *)sessionToken;

@end

#endif

@interface IdentityServiceTestCase : IdentityBaseTestCase

@property (nonatomic) SRGIdentityService *identityService;

@end

@implementation IdentityServiceTestCase

#pragma mark Setup and teardown

- (void)setUp
{
    self.identityService = [[SRGIdentityService alloc] initWithWebserviceURL:TestWebserviceURL() websiteURL:TestWebsiteURL()];
    [self.identityService logout];
    
    [HTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqual:TestWebserviceURL().host];
    } withStubResponse:^HTTPStubsResponse *(NSURLRequest *request) {
        if ([request.URL.host isEqualToString:TestWebsiteURL().host]) {
            if ([request.URL.path containsString:@"login"]) {
                NSURLComponents *URLComponents = [[NSURLComponents alloc] initWithURL:request.URL resolvingAgainstBaseURL:NO];
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(NSURLQueryItem.new, name), @"redirect"];
                NSURLQueryItem *queryItem = [URLComponents.queryItems filteredArrayUsingPredicate:predicate].firstObject;
                
                NSURL *redirectURL = [NSURL URLWithString:queryItem.value];
                NSURLComponents *redirectURLComponents = [[NSURLComponents alloc] initWithURL:redirectURL resolvingAgainstBaseURL:NO];
                NSArray<NSURLQueryItem *> *queryItems = redirectURLComponents.queryItems ?: @[];
                queryItems = [queryItems arrayByAddingObject:[[NSURLQueryItem alloc] initWithName:@"token" value:TestValidToken]];
                redirectURLComponents.queryItems = queryItems;
                
                return [[HTTPStubsResponse responseWithData:[NSData data]
                                                 statusCode:302
                                                    headers:@{ @"Location" : redirectURLComponents.URL.absoluteString }] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
            }
        }
        else if ([request.URL.host isEqualToString:TestWebserviceURL().host]) {
            if ([request.URL.path containsString:@"logout"]) {
                return [[HTTPStubsResponse responseWithData:[NSData data]
                                                 statusCode:204
                                                    headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
            }
            else if ([request.URL.path containsString:@"userinfo"]) {
                NSString *validAuthorizationHeader = [NSString stringWithFormat:@"sessionToken %@", TestValidToken];
                if ([[request valueForHTTPHeaderField:@"Authorization"] isEqualToString:validAuthorizationHeader]) {
                    NSDictionary<NSString *, id> *account = @{ @"id" : @"1234",
                                                               @"publicUid" : @"4321",
                                                               @"login" : @"test@srgssr.ch",
                                                               @"displayName": @"Play SRG",
                                                               @"firstName": @"Play",
                                                               @"lastName": @"SRG",
                                                               @"gender": @"other",
                                                               @"birthdate": @"2001-01-01" };
                    return [[HTTPStubsResponse responseWithData:[NSJSONSerialization dataWithJSONObject:account options:0 error:NULL]
                                                     statusCode:200
                                                        headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
                }
                else {
                    return [[HTTPStubsResponse responseWithData:[NSData data]
                                                     statusCode:401
                                                        headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
                }
            }
        }
        
        // No match, return 404
        return [[HTTPStubsResponse responseWithData:[NSData data]
                                         statusCode:404
                                            headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
    }];
}

- (void)tearDown
{
    [self.identityService logout];
    self.identityService = nil;
    
    [HTTPStubs removeAllStubs];
}

#pragma mark Tests

- (void)testLogin
{
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
#if TARGET_OS_IOS
    BOOL hasHandledCallbackURL = [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    XCTAssertTrue(hasHandledCallbackURL);
#else
    [self.identityService handleSessionToken:TestValidToken];
#endif
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertTrue(self.identityService.loggedIn);
}

- (void)testLogout
{
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
#if TARGET_OS_IOS
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
#else
    [self.identityService handleSessionToken:TestValidToken];
#endif
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertFalse([notification.userInfo[SRGIdentityServiceUnauthorizedKey] boolValue]);
        return YES;
    }];
    
    XCTAssertTrue([self.identityService logout]);
    
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertFalse([self.identityService logout]);
}

- (void)testAccountUpdate
{
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
#if TARGET_OS_IOS
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
#else
    [self.identityService handleSessionToken:TestValidToken];
#endif
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    
    [self expectationForSingleNotification:SRGIdentityServiceDidUpdateAccountNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertNotNil(notification.userInfo[SRGIdentityServiceAccountKey]);
        XCTAssertNil(notification.userInfo[SRGIdentityServicePreviousAccountKey]);
        return YES;
    }];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNotNil(self.identityService.emailAddress);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    XCTAssertNotNil(self.identityService.account);
    
    XCTAssertTrue(self.identityService.loggedIn);
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertFalse([notification.userInfo[SRGIdentityServiceUnauthorizedKey] boolValue]);
        return YES;
    }];
    [self expectationForSingleNotification:SRGIdentityServiceDidUpdateAccountNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertNil(notification.userInfo[SRGIdentityServiceAccountKey]);
        XCTAssertNotNil(notification.userInfo[SRGIdentityServicePreviousAccountKey]);
        return YES;
    }];
    
    XCTAssertTrue([self.identityService logout]);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
}

- (void)testAutomaticLogoutWhenUnauthorized
{
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        return YES;
    }];
    
#if TARGET_OS_IOS
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, @"invalid_token")];
#else
    [self.identityService handleSessionToken:@"invalid_token"];
#endif
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, @"invalid_token");
    
    // Wait until account information is requested. The token is invalid, the user unauthorized and therefore logged out automatically
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([notification.userInfo[SRGIdentityServiceUnauthorizedKey] boolValue]);
        return YES;
    }];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
}

- (void)testUnverifiedReportedUnauthorization
{
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        return YES;
    }];
    
#if TARGET_OS_IOS
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
#else
    [self.identityService handleSessionToken:TestValidToken];
#endif
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    id logoutObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityServiceUserDidLogoutNotification object:self.identityService queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No logout is expected");
    }];
    
    [self expectationForSingleNotification:SRGIdentityServiceDidUpdateAccountNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        return YES;
    }];
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    [self.identityService reportUnauthorization];
    
    [self waitForExpectationsWithTimeout:5. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:logoutObserver];
    }];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
}

- (void)testMultipleUnverifiedReportedUnauthorizations
{
    // A first account update is performed after login. Wait for it
    [self expectationForSingleNotification:SRGIdentityServiceDidUpdateAccountNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        return YES;
    }];
    
#if TARGET_OS_IOS
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
#else
    [self.identityService handleSessionToken:TestValidToken];
#endif
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    __block NSInteger numberOfUpdates = 0;
    id accountUpdateObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityServiceDidUpdateAccountNotification object:self.identityService queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        ++numberOfUpdates;
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    // Unverified reported unauthorizations lead to an account update. Expect at most 1
    [self.identityService reportUnauthorization];
    [self.identityService reportUnauthorization];
    [self.identityService reportUnauthorization];
    [self.identityService reportUnauthorization];
    [self.identityService reportUnauthorization];
    
    [self waitForExpectationsWithTimeout:5. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:accountUpdateObserver];
    }];
    
    XCTAssertEqual(numberOfUpdates, 1);
}

- (void)testReportedUnauthorizationWhenLoggedOut
{
    XCTAssertFalse(self.identityService.loggedIn);
    XCTAssertNil(self.identityService.sessionToken);
    
    id loginObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityServiceUserDidLoginNotification object:self.identityService queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No login is expected");
    }];
    id accountUpdateObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityServiceDidUpdateAccountNotification object:self.identityService queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No account update is expected");
    }];
    id logoutObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityServiceUserDidLogoutNotification object:self.identityService queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No logout is expected");
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    [self.identityService reportUnauthorization];
    
    [self waitForExpectationsWithTimeout:5. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:loginObserver];
        [NSNotificationCenter.defaultCenter removeObserver:accountUpdateObserver];
        [NSNotificationCenter.defaultCenter removeObserver:logoutObserver];
    }];
    
    XCTAssertFalse(self.identityService.loggedIn);
    XCTAssertNil(self.identityService.sessionToken);
}

#if TARGET_OS_IOS

- (void)testLogoutHandleCallbackURL
{
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertFalse([notification.userInfo[SRGIdentityServiceUnauthorizedKey] boolValue]);
        return YES;
    }];
    
    BOOL hasHandledCallbackURL = [self.identityService handleCallbackURL:TestLogoutCallbackURL(self.identityService)];
    XCTAssertTrue(hasHandledCallbackURL);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
}

- (void)testAccountDeletedHandleCallbackURL
{
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertFalse([notification.userInfo[SRGIdentityServiceUnauthorizedKey] boolValue]);
        XCTAssertTrue([notification.userInfo[SRGIdentityServiceDeletedKey] boolValue]);
        return YES;
    }];
    
    BOOL hasHandledCallbackURL = [self.identityService handleCallbackURL:TestAccountDeletedCallbackURL(self.identityService)];
    XCTAssertTrue(hasHandledCallbackURL);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
}

- (void)testUnauthorizedHandleCallbackURL
{
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLogoutNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertTrue([notification.userInfo[SRGIdentityServiceUnauthorizedKey] boolValue]);
        return YES;
    }];
    
    BOOL hasHandledCallbackURL = [self.identityService handleCallbackURL:TestUnauthorizedCallbackURL(self.identityService)];
    XCTAssertTrue(hasHandledCallbackURL);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
}

- (void)testIgnoredHandleCallbackURL
{
    XCTAssertNil(self.identityService.emailAddress);
    XCTAssertNil(self.identityService.sessionToken);
    XCTAssertNil(self.identityService.account);
    
    XCTAssertFalse(self.identityService.loggedIn);
    
    [self expectationForSingleNotification:SRGIdentityServiceUserDidLoginNotification object:self.identityService handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityService handleCallbackURL:TestLoginCallbackURL(self.identityService, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    id logoutObserver = [NSNotificationCenter.defaultCenter addObserverForName:SRGIdentityServiceUserDidLogoutNotification object:self.identityService queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No logout is expected");
    }];
    
    BOOL hasHandledCallbackURL1 = [self.identityService handleCallbackURL:TestIgnored1CallbackURL(self.identityService)];
    XCTAssertFalse(hasHandledCallbackURL1);
    BOOL hasHandledCallbackURL2 = [self.identityService handleCallbackURL:TestIgnored2CallbackURL(self.identityService)];
    XCTAssertFalse(hasHandledCallbackURL2);
    BOOL hasHandledCallbackURL3 = [self.identityService handleCallbackURL:TestIgnored3CallbackURL()];
    XCTAssertFalse(hasHandledCallbackURL3);
    
    [self waitForExpectationsWithTimeout:5. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:logoutObserver];
    }];
    
    XCTAssertTrue(self.identityService.loggedIn);
    XCTAssertEqualObjects(self.identityService.sessionToken, TestValidToken);
}

#endif

@end
