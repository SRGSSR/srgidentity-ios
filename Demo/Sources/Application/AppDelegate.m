//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "AppDelegate.h"

#import "DemosViewController.h"

#import <SRGIdentity/SRGIdentity.h>

@implementation AppDelegate

#pragma mark UIApplicationDelegate protocol

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    SRGIdentityService.currentIdentityService = [[SRGIdentityService alloc] initWithProviderURL:[NSURL URLWithString:@"https://id.rts.ch"]];
    
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    [self.window makeKeyAndVisible];
    
    DemosViewController *demosViewController = [[DemosViewController alloc] init];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:demosViewController];
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<NSString *, id> *)options
{
    if ([SRGIdentityService.currentIdentityService handleCallbackURL:url]) {
        return YES;
    }
    
    return NO;
}

@end
