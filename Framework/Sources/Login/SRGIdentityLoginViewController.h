//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(tvos(9.0)) API_UNAVAILABLE(ios)
@interface SRGIdentityLoginViewController : UIViewController

- (instancetype)initWithWebserviceURL:(NSURL *)webserviceURL
                           websiteURL:(NSURL *)websiteURL
                         emailAddress:(nullable NSString *)emailAddress
                           tokenBlock:(void (^)(NSString * _Nonnull sessionToken))tokenBlock
                       dismissalBlock:(void (^)(void))dismissalBlock;

@end

NS_ASSUME_NONNULL_END
