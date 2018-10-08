//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Data provider error constants. More information is available from the `userInfo` associated with these errors.
 */
typedef NS_ENUM(NSInteger, SRGIdentityError) {
    /**
     *  The data which was received is invalid.
     */
    SRGIdentityErrorCodeInvalidData,
    
    /**
     *  The authentification process was canceled.
     */
    SRGAuthentificationCanceled,
    
    /**
     *  The authentification process didn't start.
     */
    SRGAuthentificationStartFailed
};

/**
 *  Common domain for data provider errors.
 */
OBJC_EXPORT NSString * const SRGIdentityErrorDomain;

NS_ASSUME_NONNULL_END