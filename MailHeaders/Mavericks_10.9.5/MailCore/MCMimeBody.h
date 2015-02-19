/*
 *     Generated by class-dump 3.4 (64 bit).
 *
 *     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2012 by Steve Nygard.
 */

#import <MailCore/MCMessageBody.h>

@class MCMimePart, NSData;

@interface MCMimeBody : MCMessageBody
{
    MCMimePart *_topLevelPart;
    NSData *_bodyData;
}

+ (id)newMimeBoundary;
+ (id)versionString;
+ (void)initialize;
- (void)flushCachedData;
- (void)setBodyData:(id)arg1;
- (id)bodyData;
- (id)dataForMimePart:(id)arg1;
- (id)parsedMessageWithContext:(id)arg1;
- (id)parsedMessage;
- (id)webArchive;
- (id)textHtmlPart;
- (id)preferredBodyPart;
- (BOOL)isTextPlain;
- (BOOL)isMultipartRelated;
- (BOOL)isRich;
- (BOOL)isHTML;
- (id)attachmentFilenames;
- (id)attachmentsWithContext:(id)arg1;
- (id)attachments;
- (unsigned int)numberOfAttachmentsSigned:(char *)arg1 encrypted:(char *)arg2 numberOfTNEFAttachments:(unsigned int *)arg3;
- (BOOL)hasAttachments;
- (void)decodeIfNecessary;
- (void)decodeIfNecessaryWithContext:(id)arg1;
- (BOOL)_isPossiblySignedOrEncrypted;
- (void)calculateNumberOfAttachmentsIfNeeded;
- (id)partWithNumber:(id)arg1;
- (id)mimeSubtype;
- (id)mimeType;
- (BOOL)isSignedByMe;
- (id)attachmentPartsEnumerator;
- (id)allPartsEnumerator;
- (void)setTopLevelPart:(id)arg1;
- (id)topLevelPart;
- (void)dealloc;
- (id)attributedString;
- (void)renderString:(id)arg1;
- (void)renderStringForJunk:(id)arg1;

@end
