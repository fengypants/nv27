//
//  NotationPrefs.m
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

#import "AppController.h"
#import "NotationPrefs.h"
#import "GlobalPrefs.h"
#import "NSString_NV.h"
#import "NSCollection_utils.h"
#import "NotationPrefsViewController.h"
#import "NSData_transformations.h"
#import "NotationFileManager.h"
#import "DiskUUIDEntry.h"
#include <CoreServices/CoreServices.h>
#include <Security/Security.h>
#include <ApplicationServices/ApplicationServices.h>



NSString *NotationPrefsDidChangeNotification = @"NotationPrefsDidChangeNotification";

@implementation NotationPrefs

+ (int)appVersion {
	return [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] intValue];
}

- (id)init {
    if (self=[super init]) {
		allowedTypes = NULL;
		
		unsigned int i;
		for (i=0; i<4; i++) {
			typeStrings[i] = [[NotationPrefs defaultTypeStringsForFormat:i] retain];
			pathExtensions[i] = [[NotationPrefs defaultPathExtensionsForFormat:i] retain];
			chosenExtIndices[i] = 0;
		}
		
		confirmFileDeletion = YES;
		databaseIsEncrypted = NO;
		seenDiskUUIDEntries = [[NSMutableArray alloc] init];
		notesStorageFormat = PlainTextFormat; //nv27 stores notes only as separate files
		baseBodyFont = [[[GlobalPrefs defaultPrefs] noteBodyFont] retain];
		//foregroundColor = [[[GlobalPrefs defaultPrefs] foregroundTextColor] retain];
		foregroundColor = [[[NSApp delegate] foregrndColor]retain];
		epochIteration = 0;
		
		[self updateOSTypesArray];
		
		firstTimeUsed = preferencesChanged = YES;
		
        return self;
    }
    return nil;
}

- (id)initWithCoder:(NSCoder*)decoder {
    if ([super init]) {
		NSAssert([decoder allowsKeyedCoding], @"Keyed decoding only!");
		
		//if we're initializing from an archive, we've obviously been run at least once before
		firstTimeUsed = NO;
		
		preferencesChanged = NO;
		
		epochIteration = [decoder decodeInt32ForKey:VAR_STR(epochIteration)];
		notesStorageFormat = [decoder decodeIntForKey:VAR_STR(notesStorageFormat)];
		
		//note encryption is no longer supported; remember whether this database was encrypted by an earlier
		//version (as that version decided it) so that loading can stop instead of misreading the notes
		databaseIsEncrypted = [decoder decodeBoolForKey:@"doesEncryption"] &&
			[decoder decodeObjectForKey:@"verifierKey"] && [decoder decodeObjectForKey:@"masterSalt"];
		
		@try {
			baseBodyFont = [[decoder decodeObjectForKey:VAR_STR(baseBodyFont)] retain];
		} @catch (NSException *e) {
			NSLog(@"Error trying to unarchive default base body font (%@, %@)", [e name], [e reason]);
		}
		if (!baseBodyFont || ![baseBodyFont isKindOfClass:[NSFont class]]) {
			baseBodyFont = [[[GlobalPrefs defaultPrefs] noteBodyFont] retain];
			NSLog(@"setting base body to current default: %@", baseBodyFont);
			preferencesChanged = YES;
		}
		//foregroundColor does not receive the same treatment as basebodyfont; in the event of a discrepancy between global and per-db settings,
		//the former is applied to the notes in the database, while the latter is restored from the database itself
		@try {
			foregroundColor = [[decoder decodeObjectForKey:VAR_STR(foregroundColor)] retain];
		} @catch (NSException *e) {
			NSLog(@"Error trying to unarchive foreground text color (%@, %@)", [e name], [e reason]);
		}
		if (!foregroundColor || ![foregroundColor isKindOfClass:[NSColor class]]) {
			//foregroundColor = [[[GlobalPrefs defaultPrefs] foregroundTextColor] retain];
			
			foregroundColor = [[[NSApp delegate] foregrndColor]retain];
			preferencesChanged = YES;
		}
		
		confirmFileDeletion = [decoder decodeBoolForKey:VAR_STR(confirmFileDeletion)];
		
		unsigned int i;
		for (i=0; i<4; i++) {
			if (!(typeStrings[i] = [[decoder decodeObjectForKey:[VAR_STR(typeStrings) stringByAppendingFormat:@".%d",i]] retain]))
				typeStrings[i] = [[NotationPrefs defaultTypeStringsForFormat:i] retain];
			if (!(pathExtensions[i] = [[decoder decodeObjectForKey:[VAR_STR(pathExtensions) stringByAppendingFormat:@".%d",i]] retain]))
				pathExtensions[i] = [[NotationPrefs defaultPathExtensionsForFormat:i] retain];
			chosenExtIndices[i] = [decoder decodeIntForKey:[VAR_STR(chosenExtIndices) stringByAppendingFormat:@".%d",i]];
		}
		
		//nv27 recognizes Markdown (.md) files as notes instead of TaskPaper files; update lists saved by
		//nvALT or earlier nv27 builds once (after that, the list is the user's to edit)
		if (![decoder decodeBoolForKey:@"nv27PlainTextExtensionsUpdated"]) {
			NSMutableArray *extensions = [[pathExtensions[PlainTextFormat] mutableCopy] autorelease];
			[pathExtensions[PlainTextFormat] release];
			pathExtensions[PlainTextFormat] = [extensions retain];
			NSString *chosen = chosenExtIndices[PlainTextFormat] < [extensions count] ?
				[[[extensions objectAtIndex:chosenExtIndices[PlainTextFormat]] retain] autorelease] : nil;
			NSUInteger j;
			for (j = [extensions count]; j > 0; j--) {
				if ([[extensions objectAtIndex:j - 1] caseInsensitiveCompare:@"taskpaper"] == NSOrderedSame)
					[extensions removeObjectAtIndex:j - 1];
			}
			if (![extensions containsObject:@"md"])
				[extensions addObject:@"md"];
			NSUInteger chosenIndex = chosen ? [extensions indexOfObject:chosen] : NSNotFound;
			chosenExtIndices[PlainTextFormat] = chosenIndex == NSNotFound ? 0 : (unsigned int)chosenIndex;
			preferencesChanged = YES;
		}
		
		//databases from earlier versions may also contain "syncServiceAccounts" (Simplenote settings) and
		//keychain/key-derivation settings for encryption; they are ignored
		
		if (!(seenDiskUUIDEntries = [[decoder decodeObjectForKey:VAR_STR(seenDiskUUIDEntries)] retain]))
			seenDiskUUIDEntries = [[NSMutableArray alloc] init];
		
		[self updateOSTypesArray];
    }
	
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
	NSAssert([coder allowsKeyedCoding], @"Keyed encoding only!");
	
	/* epochIteration:
	 0: .Blor files
	 1: First NSArchiver (was unused--maps to 0)
	 2: First NSKeyedArchiver
	 3: First syncServicesMD and date created/modified syncing to files
	 4: tracking of file size and attribute mod dates, font foreground colors, openmeta labels
	 */
	[coder encodeInt32:EPOC_ITERATION forKey:VAR_STR(epochIteration)];
	
	[coder encodeInteger:notesStorageFormat forKey:VAR_STR(notesStorageFormat)];
	
	[coder encodeBool:confirmFileDeletion forKey:VAR_STR(confirmFileDeletion)];
	[coder encodeObject:baseBodyFont forKey:VAR_STR(baseBodyFont)];
	[coder encodeObject:foregroundColor forKey:VAR_STR(foregroundColor)];
	
	unsigned int i;
	for (i=0; i<4; i++) {	
		[coder encodeObject:typeStrings[i] forKey:[VAR_STR(typeStrings) stringByAppendingFormat:@".%d",i]];
		[coder encodeObject:pathExtensions[i] forKey:[VAR_STR(pathExtensions) stringByAppendingFormat:@".%d",i]];
		[coder encodeInt:chosenExtIndices[i] forKey:[VAR_STR(chosenExtIndices) stringByAppendingFormat:@".%d",i]];
	}
	[coder encodeBool:YES forKey:@"nv27PlainTextExtensionsUpdated"];
	
	[coder encodeObject:seenDiskUUIDEntries forKey:VAR_STR(seenDiskUUIDEntries)];
}


- (void)dealloc {
    
    unsigned int i;
    for (i=0; i<4; i++) {
	[typeStrings[i] release];
	[pathExtensions[i] release];
    }
    if (allowedTypes)
	free(allowedTypes);
	
	[seenDiskUUIDEntries release];
	[baseBodyFont release];
	[foregroundColor release];
    
    [super dealloc];
}

+ (NSMutableArray*)defaultTypeStringsForFormat:(int)formatID {
    switch (formatID) {
	case SingleDatabaseFormat:
	    return [NSMutableArray arrayWithCapacity:0];
	case PlainTextFormat: 
	    return [NSMutableArray arrayWithObjects:[(id)UTCreateStringForOSType(TEXT_TYPE_ID) autorelease], 
			[(id)UTCreateStringForOSType(UTXT_TYPE_ID) autorelease], nil];
	case RTFTextFormat: 
	    return [NSMutableArray arrayWithObjects:[(id)UTCreateStringForOSType(RTF_TYPE_ID) autorelease], nil];
	case HTMLFormat:
	    return [NSMutableArray arrayWithObjects:[(id)UTCreateStringForOSType(HTML_TYPE_ID) autorelease], nil];
	case WordDocFormat:
		return [NSMutableArray arrayWithObjects:[(id)UTCreateStringForOSType(WORD_DOC_TYPE_ID) autorelease], nil];
	default:
	    NSLog(@"Unknown format ID: %d", formatID);
    }
    
    return [NSMutableArray arrayWithCapacity:0];
}

+ (NSMutableArray*)defaultPathExtensionsForFormat:(int)formatID {
    switch (formatID) {
	case SingleDatabaseFormat:
	    return [NSMutableArray arrayWithCapacity:0];
	case PlainTextFormat: 
	    return [NSMutableArray arrayWithObjects:@"txt", @"text", @"utf8", @"md", nil];
	case RTFTextFormat: 
	    return [NSMutableArray arrayWithObjects:@"rtf", nil];
	case HTMLFormat:
	    return [NSMutableArray arrayWithObjects:@"html", @"htm", nil];
	case WordDocFormat:
		return [NSMutableArray arrayWithObjects:@"doc", nil];
	case WordXMLFormat:
		return [NSMutableArray arrayWithObjects:@"docx", nil];
	default:
	    NSLog(@"Unknown format ID: %d", formatID);
    }
    
    return [NSMutableArray arrayWithCapacity:0];
}

- (BOOL)preferencesChanged {
	return preferencesChanged;
}

- (NSInteger)notesStorageFormat {
	return notesStorageFormat;
}
- (BOOL)confirmFileDeletion {
    return confirmFileDeletion;
}

- (BOOL)databaseIsEncrypted {
	return databaseIsEncrypted;
}

- (void)setPreferencesAreStored {
	preferencesChanged = NO;
}

- (UInt32)epochIteration {
	return epochIteration;
}

- (BOOL)firstTimeUsed {
	return firstTimeUsed;
}

- (void)setForegroundTextColor:(NSColor*)aColor {
	[foregroundColor autorelease];
	foregroundColor = [aColor retain];
	
	preferencesChanged = YES;
}

- (NSColor*)foregroundColor {
	return foregroundColor;
}

- (void)setBaseBodyFont:(NSFont*)aFont {
	[baseBodyFont autorelease];
	baseBodyFont = [aFont retain];
		
	preferencesChanged = YES;
}

- (NSFont*)baseBodyFont {
	
	return baseBodyFont;
}

- (NSData*)WALSessionKey {
	//the write-ahead log is always stored encrypted; unencrypted databases (now the only kind) use this fixed key,
	//which keeps journals written by earlier versions recoverable
	#define CONST_WAL_KEY "This is a 32 byte temporary key"
	return [NSData dataWithBytesNoCopy:CONST_WAL_KEY length:sizeof(CONST_WAL_KEY) freeWhenDone:NO];
}

- (void)setNotesStorageFormat:(NSInteger)formatID {
	if (formatID != notesStorageFormat) {
		NSInteger oldFormat = notesStorageFormat;
		notesStorageFormat = formatID;	
		preferencesChanged = YES;
		
		[self updateOSTypesArray];
		
		if ([delegate respondsToSelector:@selector(databaseSettingsChangedFromOldFormat:)])
			[delegate databaseSettingsChangedFromOldFormat:oldFormat];
		
		//should notationprefs need to do this?
		if ([delegate respondsToSelector:@selector(flushEverything)])
			[delegate flushEverything];
	}
}

- (void)setConfirmsFileDeletion:(BOOL)value {
    confirmFileDeletion = value;
    preferencesChanged = YES;
}

- (NSUInteger)tableIndexOfDiskUUID:(CFUUIDRef)UUIDRef {
	//if this UUID doesn't yet exist, then add it and return the last index
	
	DiskUUIDEntry *diskEntry = [[[DiskUUIDEntry alloc] initWithUUIDRef:UUIDRef] autorelease];
	
	NSUInteger idx = [seenDiskUUIDEntries indexOfObject: diskEntry];
	if (NSNotFound != idx) {
		[[seenDiskUUIDEntries objectAtIndex:idx] see];
		return idx;
	}
	
	NSLog(@"saw new disk UUID: %@ (other disks are: %@)", diskEntry, seenDiskUUIDEntries);
	[seenDiskUUIDEntries addObject:diskEntry];
	
	preferencesChanged = YES;
	
	return [seenDiskUUIDEntries count] - 1;
}

+ (NSString*)pathExtensionForFormat:(NSInteger)format {
    switch (format) {
	case SingleDatabaseFormat:
	case PlainTextFormat:
	    
	    return @"txt";
	case RTFTextFormat:
	    
	    return @"rtf";
	case HTMLFormat:
	    
	    return @"html";
	case WordDocFormat:
		
		return @"doc";
	case WordXMLFormat:
		
		return @"docx";
	default:
	    NSLog(@"storage format ID is unknown: %ld", format);
    }
    
    return @"";
}

//for our nstableview data source
- (NSInteger)typeStringsCount {
	if (typeStrings[notesStorageFormat])
		return (NSInteger)[typeStrings[notesStorageFormat] count];
	
	return 0;
}
- (NSInteger)pathExtensionsCount {
	if (pathExtensions[notesStorageFormat])
	    return (NSInteger)[pathExtensions[notesStorageFormat] count];
	
	return 0;
}

- (NSString*)typeStringAtIndex:(NSInteger)typeIndex {

    return [typeStrings[notesStorageFormat] objectAtIndex:typeIndex];
}
- (NSString*)pathExtensionAtIndex:(NSInteger)pathIndex {
    return [pathExtensions[notesStorageFormat] objectAtIndex:pathIndex];
}
- (unsigned int)indexOfChosenPathExtension {
	return chosenExtIndices[notesStorageFormat];
}
- (NSString*)chosenPathExtensionForFormat:(NSInteger)format {
	if (chosenExtIndices[format] >= [pathExtensions[format] count])
		return [NotationPrefs pathExtensionForFormat:format];
	
	return [pathExtensions[format] objectAtIndex:chosenExtIndices[format]];
}

- (void)updateOSTypesArray {
    if (!typeStrings[notesStorageFormat])
	return;
    
    unsigned int i, newSize = sizeof(OSType) * [typeStrings[notesStorageFormat] count];
    allowedTypes = (OSType*)realloc(allowedTypes, newSize);
	
    for (i=0; i<[typeStrings[notesStorageFormat] count]; i++)
		allowedTypes[i] = UTGetOSTypeFromString((CFStringRef)[typeStrings[notesStorageFormat] objectAtIndex:i]);
}

- (void)addAllowedPathExtension:(NSString*)extension {
    
    NSString *actualExt = [extension stringAsSafePathExtension];
	[pathExtensions[notesStorageFormat] addObject:actualExt];
	
	preferencesChanged = YES;
}

- (BOOL)removeAllowedPathExtensionAtIndex:(NSUInteger)extensionIndex {

	if ([pathExtensions[notesStorageFormat] count] > 1 && extensionIndex < [pathExtensions[notesStorageFormat] count]) {
		[pathExtensions[notesStorageFormat] removeObjectAtIndex:extensionIndex];
		
		if (chosenExtIndices[notesStorageFormat] >= [pathExtensions[notesStorageFormat] count])
			chosenExtIndices[notesStorageFormat] = 0;
		
		preferencesChanged = YES;
		return YES;
	}
	return NO;
}
- (BOOL)setChosenPathExtensionAtIndex:(NSUInteger)extensionIndex {
	if ([pathExtensions[notesStorageFormat] count] > extensionIndex &&
		[[pathExtensions[notesStorageFormat] objectAtIndex:extensionIndex] length]) {
		chosenExtIndices[notesStorageFormat] = extensionIndex;
		
		preferencesChanged = YES;
		return YES;
	}
	return NO;
}

- (BOOL)addAllowedType:(NSString*)type {
    
	if (type) {
		[typeStrings[notesStorageFormat] addObject:[type fourCharTypeString]];
		[self updateOSTypesArray];
		
		preferencesChanged = YES;
		return YES;
	}
	return NO;
}

- (void)removeAllowedTypeAtIndex:(NSUInteger)typeIndex {
	[typeStrings[notesStorageFormat] removeObjectAtIndex:typeIndex];
	[self updateOSTypesArray];
	
	preferencesChanged = YES;
}

- (BOOL)setExtension:(NSString*)newExtension atIndex:(unsigned int)oldIndex {
	
    if (oldIndex < [pathExtensions[notesStorageFormat] count]) {
		
		if ([newExtension length] > 0) { 
			[pathExtensions[notesStorageFormat] replaceObjectAtIndex:oldIndex withObject:[newExtension stringAsSafePathExtension]];
			
			preferencesChanged = YES;
		} else if (![(NSString*)[pathExtensions[notesStorageFormat] objectAtIndex:oldIndex] length]) {
			return NO;
		}
    }
	
	return YES;
}

- (BOOL)setType:(NSString*)newType atIndex:(unsigned int)oldIndex {
	
    if (oldIndex < [typeStrings[notesStorageFormat] count]) {
		
		if ([newType length] > 0) {
			[typeStrings[notesStorageFormat] replaceObjectAtIndex:oldIndex withObject:[newType fourCharTypeString]];
			[self updateOSTypesArray];
				
			preferencesChanged = YES;
				
			return YES;
		}
		if (!UTGetOSTypeFromString((CFStringRef)[typeStrings[notesStorageFormat] objectAtIndex:oldIndex])) {
			return NO;
		}
    }
	
	return YES;
}

- (BOOL)pathExtensionAllowed:(NSString*)anExtension forFormat:(NSInteger)formatID {
	NSUInteger i;
    for (i=0; i<[pathExtensions[formatID] count]; i++) {
		if ([anExtension compare:[pathExtensions[formatID] objectAtIndex:i] 
						 options:NSCaseInsensitiveSearch] == NSOrderedSame) {
			return YES;
		}
    }
	return NO;
}

- (BOOL)catalogEntryAllowed:(NoteCatalogEntry*)catEntry {
    NSString *filename = (NSString*)catEntry->filename;
	
	if (![filename length])
		return NO;
	
	//ignore hidden files and our own database-related files (e.g. if by chance they are given a TEXT file type)
	if ([filename characterAtIndex:0] == '.') {
		return NO;
	}
	if ([filename isEqualToString:NotesDatabaseFileName]) {
		return NO;
	}
	if ([filename isEqualToString:@"Interim Note-Changes"]) {
		return NO;
	}
	
	if ([self pathExtensionAllowed:[filename pathExtension] forFormat:notesStorageFormat])
		return YES;
    
	NSUInteger i;
    for (i=0; i<[typeStrings[notesStorageFormat] count]; i++) {
		if (catEntry->fileType == allowedTypes[i]) {
			return YES;
		}
    }
    
    return NO;
    
}

- (id)delegate {
	return delegate;
}

- (void)setDelegate:(id)aDelegate {
	delegate = aDelegate;
}


@end
