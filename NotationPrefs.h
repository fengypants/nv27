//
//  NotationPrefs.h
//  Notation
//
//  Created by Zachary Schneirov on 4/1/06.

/*Copyright (c) 2010, Zachary Schneirov. All rights reserved.
  Redistribution and use in source and binary forms, with or without modification, are permitted 
  provided that the following conditions are met:
   - Redistributions of source code must retain the above copyright notice, this list of conditions 
     and the following disclaimer.
   - Redistributions in binary form must reproduce the above copyright notice, this list of 
	 conditions and the following disclaimer in the documentation and/or other materials provided with
     the distribution.
   - Neither the name of Notational Velocity nor the names of its contributors may be used to endorse 
     or promote products derived from this software without specific prior written permission. */


#import <Cocoa/Cocoa.h>
#import "NotationController.h"

/* this class is responsible for managing all preferences specific to a notational database,
such as file formats and secure text entry */

#define EPOC_ITERATION 4

enum { SingleDatabaseFormat = 0, PlainTextFormat, RTFTextFormat, HTMLFormat, WordDocFormat, WordXMLFormat };

extern NSString *NotationPrefsDidChangeNotification;

@interface NotationPrefs : NSObject {
	BOOL databaseIsEncrypted, secureTextEntry;
	
	NSColor *foregroundColor;
	NSFont *baseBodyFont;
	NSInteger notesStorageFormat;
	BOOL confirmFileDeletion;
	
	unsigned int chosenExtIndices[4];
    NSMutableArray *typeStrings[4], *pathExtensions[4];
    OSType *allowedTypes;
	
	NSMutableArray *seenDiskUUIDEntries;
	
	UInt32 epochIteration;
	BOOL firstTimeUsed;
	BOOL preferencesChanged;
	id delegate;
}

+ (int)appVersion;
+ (NSMutableArray*)defaultTypeStringsForFormat:(int)formatID;
+ (NSMutableArray*)defaultPathExtensionsForFormat:(int)formatID;
- (BOOL)preferencesChanged;
- (void)setForegroundTextColor:(NSColor*)aColor;
- (NSColor*)foregroundColor;
- (void)setBaseBodyFont:(NSFont*)aFont;
- (NSFont*)baseBodyFont;

- (NSInteger)notesStorageFormat;
- (BOOL)confirmFileDeletion;
- (BOOL)databaseIsEncrypted;
- (UInt32)epochIteration;
- (BOOL)firstTimeUsed;
- (BOOL)secureTextEntry;

- (void)setPreferencesAreStored;
- (NSData*)WALSessionKey;

- (void)setNotesStorageFormat:(NSInteger)formatID;
- (void)setConfirmsFileDeletion:(BOOL)value;
- (void)setSecureTextEntry:(BOOL)value;

- (NSUInteger)tableIndexOfDiskUUID:(CFUUIDRef)UUIDRef;

+ (NSString*)pathExtensionForFormat:(NSInteger)format;

//used to view tableviews
- (NSString*)typeStringAtIndex:(NSInteger)typeIndex;
- (NSString*)pathExtensionAtIndex:(NSInteger)pathIndex;
- (unsigned int)indexOfChosenPathExtension;
- (NSString*)chosenPathExtensionForFormat:(NSInteger)format;
- (NSInteger)typeStringsCount;
- (NSInteger)pathExtensionsCount;

//used to edit tableviews
- (void)addAllowedPathExtension:(NSString*)extension;
- (BOOL)removeAllowedPathExtensionAtIndex:(NSUInteger)extensionIndex;
- (BOOL)setChosenPathExtensionAtIndex:(NSUInteger)extensionIndex;
- (BOOL)addAllowedType:(NSString*)type;
- (void)removeAllowedTypeAtIndex:(NSUInteger)index;
- (BOOL)setExtension:(NSString*)newExtension atIndex:(unsigned int)oldIndex;
- (BOOL)setType:(NSString*)newType atIndex:(unsigned int)oldIndex;

- (BOOL)pathExtensionAllowed:(NSString*)anExtension forFormat:(NSInteger)formatID;

//actually used while searching for files
- (void)updateOSTypesArray;
- (BOOL)catalogEntryAllowed:(NoteCatalogEntry*)catEntry;

- (id)delegate;
- (void)setDelegate:(id)aDelegate;

@end

@interface NotationPrefs (DelegateMethods)

- (void)databaseSettingsChangedFromOldFormat:(NSInteger)oldFormat;

@end
