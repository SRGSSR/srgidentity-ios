Getting started
===============

This getting started guide discusses all concepts required to use the SRG Identity library.

## Service instantiation

At its core, the SRG Identity library reduces to a single identity service class, `SRGIdentityService`, which you instantiate for a given (Peach) identity provider URL, for example:

```objective-c
NSURL *URL = ...;
SRGIdentityService *identityService = [[SRGIdentityService alloc] initWithProviderURL:URL];
```

You can have several identity services in an application, though most applications should require only one. To make it easier to access the main identity service of an application, the `SRGIdentityService ` class provides a class property to set and retrieved it as shared instance:

```objective-c
SRGIdentityService.currentIdentityService = [[SRGIdentityService alloc] initWithProviderURL:URL];
```

For simplicity, this getting started guide assumes that a shared service has been set. If you cannot use the shared instance, store the services you instantiated somewhere and provide access to them in some way.

## Login

To allow for a user to login, call the `-loginWithEmailAddress:` instance method:

```objective-c
[SRGIdentityService.currentIdentityService loginWithEmailAddress:nil];
```

This presents a sandboxed Safari browser, in which the user can supply her credentials or open an account. A user remains logged in until she logs out.

## Token

Once a user has successfully logged in, a corresponding session token is available in the keychain. Use the `SRGIdentityService.currentIdentityService.sessionToken` property when you need it.

### Logout

To logout the current user, simply call `-logout`;

```objective-c
[SRGIdentityService.currentIdentityService logout];
```

Only a single user can be logged in at any time. If you want for a new user to be able to log in, you must logout any existing user first.