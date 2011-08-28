//
//  ComposeBackEnd+GPGMail.m
//  GPGMail
//
//  Created by Lukas Pitschl on 31.07.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <OutgoingMessage.h>
#import <_OutgoingMessageBody.h>
#import <MessageBody.h>
#import <MimeBody.h>
#import <MimePart.h>
#import <MessageWriter.h>
#import <NSString-EmailAddressString.h>
#import <NSString-NSStringUtils.h>
#import <MutableMessageHeaders.h>
#import <ComposeBackEnd.h>
#import "CCLog.h"
#import "NSObject+LPDynamicIvars.h"
#import "NSString+GPGMail.h"
#import "GPGFlaggedHeaderValue.h"
#import "GPGMailBundle.h"
#import "ComposeBackEnd+GPGMail.h"

@implementation ComposeBackEnd_GPGMail

- (void)MASetEncryptIfPossible:(BOOL)encryptIfPossible {
    // This method is not only called, when the user clicks the encrypt button,
    // but also when a new message is loaded.
    // This causes the message to always be in a "has changed" state and sometimes
    // keeps existing as a draft, even after sending the message.
    // To prevent this GPGMail uses the entry point -[HeadersEditor securityControlChanged:]
    // which is triggered whenever the user clicks the encrypt button.
    // In that entry point a variable is set on the backend, shouldUpdateHasChanges.
    // Only if that variable is found, the has changes property of the backEnd is actually
    // updated.
    if([[GPGOptions sharedOptions] boolForKey:@"UseOpenPGPToSend"]) {
        if([self ivarExists:@"shouldUpdateHasChanges"] && ![(ComposeBackEnd *)self hasChanges]) {
            [(ComposeBackEnd *)self setHasChanges:YES];
            [self removeIvar:@"shouldUpdateHasChanges"];
        }
        [self setIvar:@"shouldEncrypt" value:[NSNumber numberWithBool:encryptIfPossible]];
    }
    [self MASetEncryptIfPossible:encryptIfPossible];
}

- (void)MASetSignIfPossible:(BOOL)signIfPossible {
    // See MASetEncryptIfPossible: why shouldUpdateHasChanges is checked. 
    if([[GPGOptions sharedOptions] boolForKey:@"UseOpenPGPToSend"]) {
        if([self ivarExists:@"shouldUpdateHasChanges"] && ![(ComposeBackEnd *)self hasChanges]) {
            [(ComposeBackEnd *)self setHasChanges:YES];
            [self removeIvar:@"shouldUpdateHasChanges"];
        }
        [self setIvar:@"shouldSign" value:[NSNumber numberWithBool:signIfPossible]];
    }
    [self MASetSignIfPossible:signIfPossible];
}

- (id)MA_makeMessageWithContents:(WebComposeMessageContents *)contents isDraft:(BOOL)isDraft shouldSign:(BOOL)shouldSign shouldEncrypt:(BOOL)shouldEncrypt shouldSkipSignature:(BOOL)shouldSkipSignature shouldBePlainText:(BOOL)shouldBePlainText {
    if(![[GPGOptions sharedOptions] boolForKey:@"UseOpenPGPToSend"] ||
       [[GPGMailBundle sharedInstance] componentsMissing])
        return [self MA_makeMessageWithContents:contents isDraft:isDraft shouldSign:shouldSign shouldEncrypt:shouldEncrypt shouldSkipSignature:shouldSkipSignature shouldBePlainText:shouldBePlainText];
    
    // The encryption part is a little tricky that's why
    // Mail.app is gonna do the heavy lifting with our GPG encryption method
    // instead of the S/MIME one.
    // After that's done, we only have to extract the encrypted part.
    BOOL shouldPGPEncrypt = NO;
    BOOL shouldPGPSign = NO;
    if([[GPGOptions sharedOptions] boolForKey:@"UseOpenPGPToSend"]) {
        shouldPGPEncrypt = shouldEncrypt;
        shouldPGPSign = shouldSign;
    }
    // If this message is to be saved as draft, shouldEncrypt and shouldSign is always false.
    // That's why GPGMail takes the values store by clicking on the signed and encrypt icons.
    if(isDraft && [[GPGOptions sharedOptions] boolForKey:@"OptionallyEncryptDrafts"]) {
        shouldPGPSign = [[self getIvar:@"shouldSign"] boolValue];
        shouldPGPEncrypt = [[self getIvar:@"shouldEncrypt"] boolValue];
    }
    // At the moment for drafts signing and encrypting is disabled.
    // GPG not enabled, or neither encrypt nor sign are checked, let's get the shit out of here.
    DebugLog(@"%s: Should encrypt: %@", __PRETTY_FUNCTION__, shouldPGPEncrypt ? @"YES" : @"NO");
    DebugLog(@"%s: Should sign: %@", __PRETTY_FUNCTION__, shouldPGPSign ? @"YES" : @"NO");
    if(!shouldPGPEncrypt && !shouldPGPSign) {
        OutgoingMessage *outMessage = [self MA_makeMessageWithContents:contents isDraft:isDraft shouldSign:shouldSign shouldEncrypt:shouldEncrypt shouldSkipSignature:shouldSkipSignature shouldBePlainText:shouldBePlainText];
        return outMessage;
    }
    
    // Save the original headers.
    // If isDraft is set cleanHeaders are an NSDictionary they need to be a NSMutableDictionary
    // though, since Mail.app otherwise complains.
    // The isDraft flag is removed before calling the makeMessageWithContents method, otherwise
    // the encrypting and signing methods wouldn't be invoked.
    // Mail.app only wants NSMutableDictionary cleanHeaders if it's not a draft.
    // Since the isDraft flag is removed, Mail.app assumes it creates a normal message
    // to send out and therefore wants NSMutableDictionary clean headers.
    id copiedCleanHeaders = nil; 
    if(isDraft)
        copiedCleanHeaders = [[(ComposeBackEnd *)self cleanHeaders] mutableCopy];
    else
        copiedCleanHeaders = [[(ComposeBackEnd *)self cleanHeaders] copy];
        
    [self setIvar:@"originalCleanHeaders" value:copiedCleanHeaders];
    [copiedCleanHeaders release];
    // If isDraft is set the cleanHeaders are an NSDictionary instead of an NSMutableDictionary.
    // Using mutableCopy they are converted into an NSMutableDictionary.
    if(isDraft) {
        copiedCleanHeaders = [[(ComposeBackEnd *)self cleanHeaders] mutableCopy];
        [self setValue:copiedCleanHeaders forKey:@"_cleanHeaders"];
        [copiedCleanHeaders release];
    }
    // Inject the headers needed in newEncryptedPart and newSignedPart.
    [self _addGPGFlaggedHeaderValuesToHeaders:[(ComposeBackEnd *)self cleanHeaders] forEncrypting:shouldPGPEncrypt forSigning:shouldPGPSign];
    
    // Drafts store the messages with a very minor set of headers and mime types
    // not suitable for encrypted/signed messages. But fortunately, Mail.app doesn't
    // have a problem if a normal message is stored as draft, so GPGMail just needs
    // to disable the isDraft parameter, Mail.app will take care of the rest.
    OutgoingMessage *outgoingMessage = [self MA_makeMessageWithContents:contents isDraft:NO shouldSign:shouldPGPSign shouldEncrypt:shouldPGPEncrypt shouldSkipSignature:shouldSkipSignature shouldBePlainText:shouldBePlainText];
    
    // And restore the original headers.
    [(ComposeBackEnd *)self setValue:[self getIvar:@"originalCleanHeaders"] forKey:@"_cleanHeaders"];
    
    // Signing only results in an outgoing message which can be sent
    // out exactly as created by Mail.app. No need to further modify.
    // Only encrypted messages have to be adjusted.
    if(shouldPGPSign && !shouldPGPEncrypt) {
        return outgoingMessage;
    }
        
    DebugLog(@"[DEBUG] %s outgoingMessage: %@", __PRETTY_FUNCTION__, [NSString stringWithData:[outgoingMessage valueForKey:@"_rawData"] encoding:NSUTF8StringEncoding]);
    
    // Fetch the encrypted data from the body data.
    NSData *encryptedData = [((_OutgoingMessageBody *)[outgoingMessage messageBody]) rawData];
    
    // Check for preferences here, and set mime or plain version.
    Subdata *newBodyData = [self _newPGPBodyDataWithEncryptedData:encryptedData headers:[outgoingMessage headers] shouldBeMIME:YES];
    
    // AND NOW replace the current message body with the new gpg message body.
    // The subdata contains the range of the actual body excluding the headers
    // but references the entrie message (NSMutableData).
    [(_OutgoingMessageBody *)[outgoingMessage messageBody] setRawData:newBodyData];
    // _rawData instance variable has to hold the NSMutableData which
    // contains the data of the entire message including the header data.
    // Not sure why it's done this way, but HECK it works!
    [outgoingMessage setValue:[newBodyData valueForKey:@"_parentData"] forKey:@"_rawData"];
    [newBodyData release];
    
    return outgoingMessage;
}

- (void)_addGPGFlaggedHeaderValuesToHeaders:(NSMutableDictionary *)headers forEncrypting:(BOOL)forEncrypting forSigning:(BOOL)forSigning {
    // To decide whether S/MIME or PGP operations should be performed on
    // the message, different headers have to be flagged.
    //
    // For signing:
    // * flag the "from" value
    // 
    // For encrypting:
    // * temporarily add the flagged sender ("from") to the bcc recipients list,
    //   to encrypt for self, so each message can also be decrypted by the sender.
    //   (the "from" value is not inlucded in the recipients list passed to the encryption
    //    method)
    if(forSigning) {
        [headers setObject:[[headers valueForKey:@"from"] flaggedValueWithKey:@"from"] forKey:@"from"];
    }
    if(forEncrypting) {
        // Save the original bcc recipients, to restore later.
        [self setIvar:@"originalBCCRecipients" value:[headers valueForKey:@"bcc"]];
        NSMutableArray *newBCCList = [NSMutableArray array];
        // Flag BCCs as bcc, so we can use hidden-recipient.
        NSArray *bccRecipients = [headers valueForKey:@"bcc"];
        for(NSString *bcc in bccRecipients)
            [newBCCList addObject:[bcc flaggedValueWithKey:@"bcc"]];
        
        [newBCCList addObject:[[headers valueForKey:@"from"] flaggedValueWithKey:@"from"]];
        [headers setValue:newBCCList forKey:@"bcc"];
    }
}

- (Subdata *)_newPGPBodyDataWithEncryptedData:(NSData *)encryptedData headers:(MutableMessageHeaders *)headers shouldBeMIME:(BOOL)shouldBeMIME {
    // Now on to creating a new body and replacing the old one. 
    NSString *boundary = (NSString *)[MimeBody newMimeBoundary];
    NSData *topData;
    NSData *versionData;
    MimePart *topPart;
    MimePart *versionPart;
    MimePart *dataPart;
    if(!shouldBeMIME) {
        topPart = [[MimePart alloc] init];
        [topPart setType:@"text"];
        [topPart setSubtype:@"plain"];
        topPart.contentTransferEncoding = @"8bit";
        [topPart setBodyParameter:@"utf8" forKey:@"charset"];
        topData = encryptedData;
    }
    else {
        // 1. Create the top level part.
        topPart = [[MimePart alloc] init];
        [topPart setType:@"multipart"];
        [topPart setSubtype:@"encrypted"];
        [topPart setBodyParameter:@"application/pgp-encrypted" forKey:@"protocol"];
        // It's extremely important to set the boundaries for the parts
        // that need them, otherwise the body data will not be properly generated
        // by appendDataForMimePart.
        [topPart setBodyParameter:boundary forKey:@"boundary"];
        topPart.contentTransferEncoding = @"7bit";
        // 2. Create the first subpart - the version.
        versionPart = [[MimePart alloc] init];
        [versionPart setType:@"application"];
        [versionPart setSubtype:@"pgp-encrypted"];
        [versionPart setContentDescription:@"PGP/MIME Versions Identification"];
        versionPart.contentTransferEncoding = @"7bit";
        // 3. Create the pgp data subpart.
        dataPart = [[MimePart alloc] init];
        [dataPart setType:@"application"];
        [dataPart setSubtype:@"octet-stream"];
        [dataPart setBodyParameter:@"PGP.asc" forKey:@"name"];
        dataPart.contentTransferEncoding = @"7bit";
        [dataPart setDisposition:@"inline"];
        [dataPart setDispositionParameter:@"PGP.asc" forKey:@"filename"];
        [dataPart setContentDescription:@"Message encrypted with OpenPGP using GPGMail"];
        // 4. Append both parts to the top level part.
        [topPart addSubpart:versionPart];
        [topPart addSubpart:dataPart];
        
        // Again Mail.app will do the heavy lifting for us, only thing we need to do
        // is create a map of mime parts and body data.
        // The problem with that is, mime part can't be used a as a key with
        // a normal NSDictionary, since that wants to copy all keys.
        // So instad we use a CFDictionary which only retains keys.
        versionData = [@"Version: 1\r\n" dataUsingEncoding:NSASCIIStringEncoding];
        topData = [@"This is an OpenPGP/MIME encrypted message (RFC 2440 and 3156)" dataUsingEncoding:NSASCIIStringEncoding];
    }
    
    CFMutableDictionaryRef partBodyMapRef = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    CFDictionaryAddValue(partBodyMapRef, topPart, topData);
    if(shouldBeMIME) {
        CFDictionaryAddValue(partBodyMapRef, versionPart, versionData);
        CFDictionaryAddValue(partBodyMapRef, dataPart, encryptedData);
    }
    
    NSMutableDictionary *partBodyMap = (NSMutableDictionary *)partBodyMapRef;
    // The body is done, now on to updating the headers since we'll use the original headers
    // but have to change the top part headers.
    // And also add our own special GPGMail header.
    // Create the new top part headers.
    NSMutableData *contentTypeData = [[NSMutableData alloc] initWithLength:0];
    [contentTypeData appendData:[[NSString stringWithFormat:@"%@/%@;", [topPart type], [topPart subtype]] dataUsingEncoding:NSASCIIStringEncoding]];
    for(id key in [topPart bodyParameterKeys])
        [contentTypeData appendData:[[NSString stringWithFormat:@"\n\t%@=\"%@\";", key, [topPart bodyParameterForKey:key]] dataUsingEncoding:NSASCIIStringEncoding]];
    [headers setHeader:contentTypeData forKey:@"content-type"];
    [contentTypeData release];
    [headers setHeader:[GPGMailBundle agentHeader] forKey:@"x-pgp-agent"];
    [headers setHeader:@"7bit" forKey:@"content-transfer-encoding"];
    [headers removeHeaderForKey:@"content-disposition"];
    [headers removeHeaderForKey:@"from "];	
	
	// Set the original bcc recipients.
    NSArray *originalBCCRecipients = (NSArray *)[self getIvar:@"originalBCCRecipients"];
    if([originalBCCRecipients count])
        [headers setHeader:originalBCCRecipients forKey:@"bcc"];
	else
        [headers removeHeaderForKey:@"bcc"];
    // Create the actualy body data.
    NSData *headerData = [headers encodedHeadersIncludingFromSpace:NO];
    NSMutableData *bodyData = [[NSMutableData alloc] init];
    // First add the header data.
    [bodyData appendData:headerData];
    // Now the mime parts.
    MessageWriter *messageWriter = [[MessageWriter alloc] init];
    [messageWriter appendDataForMimePart:topPart toData:bodyData withPartData:partBodyMap];
    [messageWriter release];
    if(shouldBeMIME) {
        [versionPart release];
        [dataPart release];
    }
    [topPart release];
    CFRelease(partBodyMapRef);
    [boundary release];
    // Contains the range, which separates the mail headers
    // from the actual mime content.
    // JUST FOR INFO: messageDataIncludingFromSpace: returns an instance of NSMutableData, so basically
    // it might be the same as _rawData. But we don't need that, so, that's alright.
    NSRange contentRange = NSMakeRange([headerData length], 
                                       ([bodyData length] - [headerData length]));
    Subdata *contentSubdata = [[Subdata alloc] initWithParent:bodyData range:contentRange];
    [bodyData release];
    return contentSubdata;
}

- (BOOL)MACanEncryptForRecipients:(NSArray *)recipients sender:(NSString *)sender {
    // If gpg is not enabled, call the original method.
    if(![[GPGOptions sharedOptions] boolForKey:@"UseOpenPGPToSend"])
        return [self MACanEncryptForRecipients:recipients sender:sender];
    // Otherwise check the gpg keys.
    // Loop through all the addresses and check if we can encrypt for them.
    // If no recipients are set, encrypt is false.
    if(![recipients count])
        return NO;
    NSMutableArray *mutableRecipients = [recipients mutableCopy];
    NSMutableArray *nonEligibleRecipients = [NSMutableArray array];
    [mutableRecipients addObject:[sender gpgNormalizedEmail]];
    
    for(NSString *address in mutableRecipients) {
        if(![[GPGMailBundle sharedInstance] canEncryptMessagesToAddress:[address gpgNormalizedEmail]])
            [nonEligibleRecipients addObject:address];
    }
    DebugLog(@"Non eligible recipients: %@", nonEligibleRecipients);
    BOOL canEncrypt = [nonEligibleRecipients count] == 0;
    [mutableRecipients release];
    
    return canEncrypt;
}

- (BOOL)MACanSignFromAddress:(NSString *)address {
    // If gpg is not enabled, call the original method.
    if(![[GPGOptions sharedOptions] boolForKey:@"UseOpenPGPToSend"])
        return [self MACanSignFromAddress:address];
    // Otherwise check the gpg keys.
    BOOL canSign = [[GPGMailBundle sharedInstance] canSignMessagesFromAddress:[address uncommentedAddress]];
    return canSign;
}

- (id)MARecipientsThatHaveNoKeyForEncryption {
    // If gpg is not enabled, call the original method.
    if(![[GPGOptions sharedOptions] boolForKey:@"UseOpenPGPToSend"])
        return [self MARecipientsThatHaveNoKeyForEncryption];
    
    NSMutableArray *nonEligibleRecipients = [NSMutableArray array];
    for(NSString *recipient in [((ComposeBackEnd *)self) allRecipients]) {
        if(![[GPGMailBundle sharedInstance] canSignMessagesFromAddress:[recipient uncommentedAddress]])
            [nonEligibleRecipients addObject:[recipient uncommentedAddress]];
    }
    
    return nonEligibleRecipients;
}

@end