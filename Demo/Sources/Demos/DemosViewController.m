//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "DemosViewController.h"

#import "AppDelegate.h"
#import "Resources.h"

@import SRGIdentity;

static NSString * const LastLoggedInEmailAddress = @"LastLoggedInEmailAddress";

@interface DemosViewController ()

@property (nonatomic, weak) IBOutlet UILabel *displayNameLabel;
@property (nonatomic, weak) IBOutlet UIButton *accountButton;

@end

@implementation DemosViewController

#pragma mark Object lifecycle

- (instancetype)init
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:ResourceNameForUIClass(self.class) bundle:nil];
    return [storyboard instantiateInitialViewController];
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userDidLogin:)
                                                 name:SRGIdentityServiceUserDidLoginNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didUpdateAccount:)
                                                 name:SRGIdentityServiceDidUpdateAccountNotification
                                               object:nil];
    
    [self reloadData];
}

#pragma mark Getters and setters

- (NSString *)title
{
    return NSLocalizedString(@"SRG Identity demo", nil);
}

#pragma mark UI

- (void)reloadData
{
    SRGIdentityService *identityService = SRGIdentityService.currentIdentityService;
    
    if (identityService.loggedIn) {
        self.displayNameLabel.text = identityService.account.displayName ?: identityService.emailAddress ?: @"-";
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Logout", nil)
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(logout:)];
    }
    else {
        self.displayNameLabel.text = NSLocalizedString(@"Not logged in", nil);
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Login", nil)
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(login:)];
    }
    
    self.accountButton.hidden = ! identityService.loggedIn;
}

#pragma mark Actions

#if TARGET_OS_IOS

- (IBAction)showAccount:(id)sender
{
    [SRGIdentityService.currentIdentityService showAccountView];
}

#endif

- (void)login:(id)sender
{
    NSString *lastEmailAddress = [NSUserDefaults.standardUserDefaults stringForKey:LastLoggedInEmailAddress];
    [SRGIdentityService.currentIdentityService loginWithEmailAddress:lastEmailAddress];
}

- (void)logout:(id)sender
{
    [SRGIdentityService.currentIdentityService logout];
}

#pragma mark Notifications

- (void)userDidLogin:(NSNotification *)notification
{
    [self reloadData];
}

- (void)didUpdateAccount:(NSNotification *)notification
{
    [self reloadData];
    
    NSString *emailAddress = SRGIdentityService.currentIdentityService.emailAddress;;
    if (emailAddress) {
        [NSUserDefaults.standardUserDefaults setObject:emailAddress forKey:LastLoggedInEmailAddress];
        [NSUserDefaults.standardUserDefaults synchronize];
    }
}

@end
