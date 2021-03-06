/*
 *     Generated by class-dump 3.4 (64 bit).
 *
 *     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2012 by Steve Nygard.
 */

#import "NSObject.h"

@class ImportAssistant, NSArray, NSMutableArray, NSString;

@interface Importer : NSObject
{
    NSMutableArray *_importArray;
    BOOL _importCanceled;
    ImportAssistant *_delegate;
    NSArray *_importFields;
}

@property(copy, nonatomic) NSArray *importFields; // @synthesize importFields=_importFields;
@property(nonatomic) BOOL importCanceled; // @synthesize importCanceled=_importCanceled;
@property(retain, nonatomic) ImportAssistant *delegate; // @synthesize delegate=_delegate;
- (void).cxx_destruct;
- (id)importFinishedText;
- (void)sortImportArray;
- (unsigned long long)countOfEnabledItems;
- (void)insertObject:(id)arg1 inImportArrayAtIndex:(unsigned long long)arg2;
- (void)clearImportArray;
- (unsigned long long)countOfImportArray;
@property(readonly, copy, nonatomic) NSArray *importArray;
@property(readonly, copy, nonatomic) NSString *name;
- (id)init;

@end

