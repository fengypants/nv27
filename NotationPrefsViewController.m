//
//  NotationPrefsViewController.m
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


#import "GlobalPrefs.h"
#import "NotationPrefsViewController.h"
#import "NotationPrefs.h"
#import "NSString_NV.h"
#import "NSCollection_utils.h"
#import "NSFileManager_NV.h"
//#import "AppController.h"

@implementation FileKindListView 

- (BOOL)acceptsFirstResponder {
    
    if (storageFormatPopupButton)
		return ([storageFormatPopupButton selectedTag] != SingleDatabaseFormat);
	
    return YES;
}
@end


@implementation NotationPrefsViewController

- (NSView*)view {
    if (!view) {
		if (![NSBundle loadNibNamed:@"NotationPrefsView" owner:self])  {
			NSLog(@"Failed to load NotationPrefsView.nib");
			return nil;
		}
    }
    
    return view;
}

- (id)init {
    if (self=[super init]) {
        
		didAwakeFromNib = NO;
		notationPrefs = [[[GlobalPrefs defaultPrefs] notationPrefs] retain];
		
	
		[[GlobalPrefs defaultPrefs] registerForSettingChange:@selector(setNotationPrefs:sender:) withTarget:self];
    
        return self;
    }
	return nil;
}
- (void)dealloc {
	[notationPrefs release];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}

- (void)awakeFromNib {
    didAwakeFromNib = YES;
    [allowedExtensionsTable setDataSource:self];
    [allowedTypesTable setDataSource:self];
    [allowedExtensionsTable setDelegate:self];
    [allowedTypesTable setDelegate:self];
	
	
	[self removeSynchronizationTab];
	[self removeEncryptionControls];
	
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(initializeControls) name:NotationPrefsDidChangeNotification object:nil];

    [self initializeControls];
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
	return (notationPrefs && [notationPrefs notesStorageFormat]);
}
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex {
    return (notationPrefs && [notationPrefs notesStorageFormat]);
}
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	NSTableView *tv = [aNotification object];
	BOOL isRowSelected = (([tv selectedRow] > -1)&&([tv selectedRow]!=NSNotFound));
	
	if (tv == allowedExtensionsTable) {
		[removeExtensionButton setEnabled:isRowSelected];
		[makeDefaultExtensionButton setEnabled:isRowSelected];
	} else if (tv == allowedTypesTable) {
		[removeTypeButton setEnabled:isRowSelected];
	}
}

- (void)settingChangedForSelectorString:(NSString*)selectorString {
	
	
	if ([selectorString isEqualToString:SEL_STR(setNotationPrefs:sender:)]) {
		
		[notationPrefs release];
		notationPrefs = [[[GlobalPrefs defaultPrefs] notationPrefs] retain];
		
		if (didAwakeFromNib)
			[self initializeControls];
	}
}

- (void)initializeControls {
    //set up outlets to reflect new settings
    if (notationPrefs) {
		
		[self setSeparateFileControlsState:[notationPrefs notesStorageFormat]];
		[confirmFileDeletionButton setState:[notationPrefs confirmFileDeletion]];
		
		[secureTextEntryButton setState:[notationPrefs secureTextEntry]];
		
		[allowedTypesTable reloadData];
		[allowedExtensionsTable reloadData];
		//tags are stored as Finder tags by default; the button only converts from the older OpenMeta tags
		[useFinderTaggingButton setHidden:[[GlobalPrefs defaultPrefs] useFinderTags]];

    }
}

//Simplenote syncing was removed; the nib still contains its "Synchronization" tab (and outlets to its
//controls, which is why those ivars remain declared), so drop the tab from whichever tab view holds it
- (void)removeSynchronizationTab {
	NSView *ancestor = [enabledSyncButton superview];
	while (ancestor && ![ancestor isKindOfClass:[NSTabView class]])
		ancestor = [ancestor superview];
	NSTabView *tabView = (NSTabView*)ancestor;
	
	for (NSTabViewItem *item in [[[tabView tabViewItems] copy] autorelease]) {
		if ([enabledSyncButton isDescendantOf:[item view]]) {
			[tabView removeTabViewItem:item];
			break;
		}
	}
}

//note encryption was removed; its controls share the nib's "Security" tab with Secure Text Entry, so hide
//them (their outlets stay declared because the compiled nib connects them) and move the Secure Text Entry
//row (its checkbox plus the labels beside and beneath it) to the top of the tab
- (void)removeEncryptionControls {
	NSView *securityView = [secureTextEntryButton superview];
	if (!securityView) return;
	
	NSRect entryFrame = [secureTextEntryButton frame];
	NSArray *encryptionControls = [NSArray arrayWithObjects:enableEncryptionButton, changePasswordButton, passwordSettingsMatrix,
								   keyLengthStepper, keyLengthField, removeFromKeychainButton, nil];
	CGFloat topEdge = 0.0, keptTopEdge = 0.0;
	NSMutableArray *keptViews = [NSMutableArray array];
	
	for (NSView *subview in [securityView subviews]) {
		NSRect frame = [subview frame];
		topEdge = MAX(topEdge, NSMaxY(frame));
		
		BOOL inSecureEntryRow = NSMidY(frame) >= NSMinY(entryFrame) - 40.0 && NSMidY(frame) <= NSMaxY(entryFrame) + 10.0;
		if (subview == secureTextEntryButton || (inSecureEntryRow && ![encryptionControls containsObject:subview])) {
			[keptViews addObject:subview];
			keptTopEdge = MAX(keptTopEdge, NSMaxY(frame));
		} else {
			[subview setHidden:YES];
		}
	}
	
	CGFloat offset = topEdge - keptTopEdge;
	if ([securityView isFlipped]) offset = -offset;
	for (NSView *subview in keptViews) {
		[subview setFrameOrigin:NSMakePoint(NSMinX([subview frame]), NSMinY([subview frame]) + offset)];
	}
	
	//notes are only stored as separate files, so the single-database choice is gone
	NSMenuItem *databaseItem = [[storageFormatPopupButton menu] itemWithTag:SingleDatabaseFormat];
	if (databaseItem)
		[[storageFormatPopupButton menu] removeItem:databaseItem];
}

- (void)setSeparateFileControlsState:(BOOL)separateFileControlsState {
	[newExtensionButton setEnabled:separateFileControlsState];
	[removeExtensionButton setEnabled:separateFileControlsState && [allowedExtensionsTable selectedRow] > -1];
	[makeDefaultExtensionButton setEnabled:separateFileControlsState && [allowedExtensionsTable selectedRow] > -1];
	[newTypeButton setEnabled:separateFileControlsState];
	[removeTypeButton setEnabled:separateFileControlsState && [allowedTypesTable selectedRow] > -1];
	
	[allowedTypesTable setEnabled:separateFileControlsState];
	[allowedExtensionsTable setEnabled:separateFileControlsState];
	
	[confirmFileDeletionButton setEnabled:separateFileControlsState];
	
	[storageFormatPopupButton selectItemWithTag:[notationPrefs notesStorageFormat]];
	
	[fileAttributesHelpText setTextColor: separateFileControlsState ? [NSColor controlTextColor] : [NSColor grayColor]];	
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject 
   forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {

	if (aTableView == allowedExtensionsTable) {
		if (![notationPrefs setExtension:anObject atIndex:(unsigned int)rowIndex])
			[self removedExtension:self];
	} else if (aTableView == allowedTypesTable) {
		if (![notationPrefs setType:anObject atIndex:(unsigned int)rowIndex])
			[self removedType:self];
	}
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {

	if (aTableView == allowedExtensionsTable) {
		NSString *extension = [notationPrefs pathExtensionAtIndex:rowIndex];
		
		if ([notationPrefs indexOfChosenPathExtension] == (unsigned int)rowIndex) {
			return [[[NSAttributedString alloc] initWithString:extension attributes:
					[NSDictionary dictionaryWithObjectsAndKeys:
					 [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName, nil]] autorelease];
		}
		return extension;
			
	} else if (aTableView == allowedTypesTable) {
		
		return [notationPrefs typeStringAtIndex:rowIndex];
	}
	return 0;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
	if (aTableView == allowedExtensionsTable)
		return [notationPrefs pathExtensionsCount];
	else if (aTableView == allowedTypesTable)
		return [notationPrefs typeStringsCount];
	
	return 0;
}

- (IBAction)addedExtension:(id)sender {
    [notationPrefs addAllowedPathExtension:@""];
	[allowedExtensionsTable reloadData];
	
	[allowedExtensionsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:[notationPrefs pathExtensionsCount]-1] byExtendingSelection:NO];
	[allowedExtensionsTable editColumn:0 row:[notationPrefs pathExtensionsCount]-1 withEvent:nil select:YES];
}

- (IBAction)addedType:(id)sender {
    [notationPrefs addAllowedType:@""];
	[allowedTypesTable reloadData];
	
	[allowedTypesTable selectRowIndexes:[NSIndexSet indexSetWithIndex:[notationPrefs typeStringsCount]-1] byExtendingSelection:NO];
	[allowedTypesTable editColumn:0 row:[notationPrefs typeStringsCount]-1 withEvent:nil select:YES];

}

- (IBAction)changedFileDeletionWarningSettings:(id)sender {
    [notationPrefs setConfirmsFileDeletion:[confirmFileDeletionButton state]];
}

- (NSInteger)notesStorageFormatInProgress {
	return notesStorageFormatInProgress;
}

- (void)notesStorageFormatDidChange {
	notesStorageFormatInProgress = [notationPrefs notesStorageFormat];
	[self setSeparateFileControlsState:notesStorageFormatInProgress];
	
    [allowedExtensionsTable reloadData];
    [allowedTypesTable reloadData];
}

- (IBAction)changedFileStorageFormat:(id)sender {
	//notes are always stored as separate files (plain text, rich text or HTML); just switch the file format
	notesStorageFormatInProgress = [storageFormatPopupButton selectedTag];
	[notationPrefs setNotesStorageFormat:notesStorageFormatInProgress];
	[self notesStorageFormatDidChange];
	
	//notes are files, so they can always be opened in an external editor
	[[NSUserDefaults standardUserDefaults] setObject:@"Default" forKey:@"TextEditor"];
}

- (IBAction)changedSecureTextEntry:(id)sender {
	[notationPrefs setSecureTextEntry:[secureTextEntryButton state]];
}

- (IBAction)makeDefaultExtension:(id)sender {
	[[allowedExtensionsTable window] makeFirstResponder:allowedExtensionsTable];
	
	NSUInteger selectedRow = (NSUInteger)[allowedExtensionsTable selectedRow];
	if (selectedRow != NSNotFound)
		[notationPrefs setChosenPathExtensionAtIndex:selectedRow];
	
	[allowedExtensionsTable reloadData];	
}

- (IBAction)removedExtension:(id)sender {
	[allowedExtensionsTable abortEditing];
	
	NSUInteger selectedRow = (NSUInteger)[allowedExtensionsTable selectedRow];
	if (selectedRow != NSNotFound)
		if (![notationPrefs removeAllowedPathExtensionAtIndex:selectedRow]) NSBeep();
	
	[allowedExtensionsTable reloadData];
}

- (IBAction)removedType:(id)sender {
	[allowedTypesTable abortEditing];
	
	NSUInteger selectedRow =(NSUInteger)[allowedTypesTable selectedRow];
	if (selectedRow !=NSNotFound)
		[notationPrefs removeAllowedTypeAtIndex:selectedRow];
	
	[allowedTypesTable reloadData];
}

- (IBAction)switchToFinderTags:(id)sender{
    if (IsMavericksOrLater) {
        NSAlert *tagWarning=[NSAlert new];
        [tagWarning setMessageText:NSLocalizedString(@"This will permanently convert all your nvALT tags to Finder tags, and use Finder tags from here on out.", @"Finder tag warning message text")];
        [tagWarning setInformativeText:NSLocalizedString(@"This cannot be undone.", @"Finder tag warning informative text")];
        [tagWarning addButtonWithTitle:NSLocalizedString(@"Do It", @"name of delete button")];
        [tagWarning addButtonWithTitle:NSLocalizedString(@"Cancel", @"name of cancel button")];
        [tagWarning beginSheetModalForWindow:[view window] completionHandler:^(NSModalResponse returnCode) {
            if (returnCode == NSAlertFirstButtonReturn) {
                [[GlobalPrefs defaultPrefs]setUseFinderTags:sender];
            }
        }];
        [tagWarning release];
    }
}

@end
