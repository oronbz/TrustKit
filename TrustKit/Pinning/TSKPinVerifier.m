/*
 
 TSKPinVerifier.m
 TrustKit
 
 Copyright 2015 The TrustKit Project Authors
 Licensed under the MIT license, see associated LICENSE file for terms.
 See AUTHORS file for the list of project authors.
 
 */

#import "TSKPinVerifier.h"
#import "ssl_pin_verifier.h"
#import "TrustKit+Private.h"



@implementation TSKPinVerifier

+ (TSKPinValidationResult) verifyPinForTrust:(SecTrustRef)serverTrust andHostname:(NSString *)serverHostname
{
    if ([TrustKit wasTrustKitInitialized] == NO)
    {
        [NSException raise:@"TrustKit not initialized"
                    format:@"TrustKit has not been initialized with a pinning configuration"];
    }
    
    if (serverTrust == NULL)
    {
        return TSKPinValidationResultErrorInvalidParameters;
    }
    
    TSKPinValidationResult validationResult = TSKPinValidationResultFailed;
    NSDictionary *trustKitConfig = [TrustKit configuration];
    
    // Retrieve the pinning configuration for this specific domain, if there is one
    NSString *domainConfigKey = getPinningConfigurationKeyForDomain(serverHostname, trustKitConfig);
    if (domainConfigKey != nil)
    {
        CFRetain(serverTrust);
        
        // This domain is pinned: look for one the configured public key pins in the server's evaluated certificate chain
        NSDictionary *domainConfig = trustKitConfig[domainConfigKey];
        validationResult = verifyPublicKeyPin(serverTrust, serverHostname, domainConfig[kTSKPublicKeyAlgorithms], domainConfig[kTSKPublicKeyHashes]);
        
        
        if (validationResult != TSKPinValidationResultSuccess)
        {
            // Pin validation failed: send a pin failure report
            sendPinFailureReport_async(validationResult, serverTrust, serverHostname, domainConfigKey, domainConfig, ^void (void)
                                 {
                                     // Release the trust once the report has been sent
                                     CFRelease(serverTrust);
                                 });
        }
        else
        {
            // Pin validation was successful
            CFRelease(serverTrust);
        }
    }
    else
    {
        // The domain is not pinned: nothing to validate
        validationResult = TSKPinValidationResultDomainNotPinned;
    }
    return validationResult;
}

@end