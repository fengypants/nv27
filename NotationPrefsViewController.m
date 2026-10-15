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
	[extensionButtons release];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}

- (void)awakeFromNib {
    didAwakeFromNib = YES;
    [allowedExtensionsTable setDataSource:self];
    [allowedTypesTable setDataSource:self];
    [allowedExtensionsTable setDelegate:self];
    [allowedTypesTable setDelegate:self];
	
	
	[self removeStorageFormatFootnote];
	[self removeSynchronizationTab];
	[self removeEncryptionControls];
	[self useStandardExtensionList];
	
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
		[self updateExtensionButtons];
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
		
		[allowedTypesTable reloadData];
		[allowedExtensionsTable reloadData];
		//tags stay OpenMeta tags, separate from Finder's; the old switch to Finder tags isn't offered
		[useFinderTaggingButton setHidden:YES];

    }
}

//drop the tab holding `view` from whichever tab view contains it (the compiled nib still has tabs for removed
//features, and outlets to their controls, which is why those ivars remain declared)
- (void)removeTabContainingView:(NSView*)view {
	//only the selected tab's view is inside the tab view, so look for it from a control on each tab
	NSTabView *tabView = nil;
	NSArray *controls = [NSArray arrayWithObjects:storageFormatPopupButton, enabledSyncButton, secureTextEntryButton, nil];
	for (NSView *control in controls) {
		NSView *ancestor = [control superview];
		while (ancestor && ![ancestor isKindOfClass:[NSTabView class]])
			ancestor = [ancestor superview];
		if ((tabView = (NSTabView*)ancestor)) break;
	}
	
	for (NSTabViewItem *item in [[[tabView tabViewItems] copy] autorelease]) {
		if ([view isDescendantOf:[item view]]) {
			[tabView removeTabViewItem:item];
			break;
		}
	}
	//a single remaining tab needs no tab strip
	if ([tabView numberOfTabViewItems] == 1) {
		[tabView selectTabViewItemAtIndex:0];
		[tabView setTabViewType:NSNoTabsNoBorder];
		[self closeGapAboveTabView:tabView];
	}
}

//without its tab strip the remaining tab's controls sit well below the top of this view; trim the empty space
//(the Settings window's Notes pane fits itself to this view's height, see -[PrefsWindowController databaseView])
- (void)closeGapAboveTabView:(NSTabView*)tabView {
	NSView *root = [tabView superview];
	NSView *content = [[tabView selectedTabViewItem] view];
	if (!root || !content || [root isFlipped]) return;
	
	CGFloat contentTop = -CGFLOAT_MAX, contentBottom = CGFLOAT_MAX;
	for (NSView *control in [content subviews]) {
		if (![control isHidden]) {
			NSRect frame = [content convertRect:[control frame] toView:root];
			contentTop = MAX(contentTop, NSMaxY(frame));
			contentBottom = MIN(contentBottom, NSMinY(frame));
		}
	}
	//likewise below: keep a standard 20pt margin under the lowest control
	CGFloat bottomTrim = contentBottom - 20.0;
	if (contentBottom != CGFLOAT_MAX && bottomTrim > 0.0) {
		[tabView setFrameOrigin:NSMakePoint(NSMinX([tabView frame]), NSMinY([tabView frame]) - bottomTrim)];
		contentTop -= bottomTrim;
	}
	for (NSView *sibling in [root subviews]) {
		if (sibling != tabView && ![sibling isHidden])
			contentTop = MAX(contentTop, NSMaxY([sibling frame]));
	}
	CGFloat newHeight = ceil(contentTop) + 4.0;
	if (contentTop == -CGFLOAT_MAX || newHeight >= NSHeight([root frame])) return;
	
	BOOL autoresizes = [root autoresizesSubviews];
	[root setAutoresizesSubviews:NO];
	[root setFrameSize:NSMakeSize(NSWidth([root frame]), newHeight)];
	[root setAutoresizesSubviews:autoresizes];
}

//Simplenote syncing, note encryption and Secure Text Entry were removed: drop the "Synchronization" and
//"Security" tabs (encryption and Secure Text Entry shared the latter)
- (void)removeSynchronizationTab {
	[self removeTabContainingView:enabledSyncButton];
}

- (void)removeEncryptionControls {
	[self removeTabContainingView:secureTextEntryButton];
	
	//notes are only stored as separate files, so the single-database choice is gone
	NSMenuItem *databaseItem = [[storageFormatPopupButton menu] itemWithTag:SingleDatabaseFormat];
	if (databaseItem)
		[[storageFormatPopupButton menu] removeItem:databaseItem];
}

//the compiled nib lays out two header-topped lists (extensions and old HFS file type codes) with loose buttons
//below; show one standard list instead: the extensions in a bordered list with +/- attached to its bottom edge
//and "Set as Default" in its contextual menu (the default extension is shown in bold). File type codes are
//something macOS no longer sets, so that list is hidden.
- (void)useStandardExtensionList {
	NSScrollView *extensionsScrollView = [allowedExtensionsTable enclosingScrollView];
	NSScrollView *typesScrollView = [allowedTypesTable enclosingScrollView];
	NSView *container = [extensionsScrollView superview];
	if (!extensionsScrollView || !container) return;
	
	for (NSView *view in [NSArray arrayWithObjects:typesScrollView, newTypeButton, removeTypeButton,
						  newExtensionButton, removeExtensionButton, makeDefaultExtensionButton, nil])
		[view setHidden:YES];
	
	[fileAttributesHelpText setStringValue:NSLocalizedString(@"Recognize files with these extensions:", @"label above the list of note file extensions")];
	
	NSRect listFrame = [extensionsScrollView frame];
	CGFloat left = [fileAttributesHelpText superview] == container ? NSMinX([fileAttributesHelpText frame]) + 2.0 : NSMinX(listFrame);
	CGFloat right = typesScrollView && [typesScrollView superview] == container ? NSMaxX([typesScrollView frame]) : NSMaxX(listFrame);
	listFrame = NSMakeRect(left, NSMinY(listFrame), right - left, NSHeight(listFrame));
	[extensionsScrollView setFrame:listFrame];
	[extensionsScrollView setBorderType:NSBezelBorder];
	[allowedExtensionsTable setHeaderView:nil];
	[allowedExtensionsTable setCornerView:nil];
	[allowedExtensionsTable setColumnAutoresizingStyle:NSTableViewUniformColumnAutoresizingStyle];
	[allowedExtensionsTable sizeLastColumnToFit];
	[extensionsScrollView tile];
	
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *defaultItem = [menu addItemWithTitle:NSLocalizedString(@"Set as Default", @"contextual menu item in the note file extensions list")
											  action:@selector(makeClickedExtensionDefault:) keyEquivalent:@""];
	[defaultItem setTarget:self];
	[allowedExtensionsTable setMenu:menu];
	
	extensionButtons = [[NSSegmentedControl alloc] initWithFrame:NSZeroRect];
	[extensionButtons setSegmentStyle:NSSegmentStyleSmallSquare];
	[extensionButtons setTrackingMode:NSSegmentSwitchTrackingMomentary];
	[extensionButtons setSegmentCount:2];
	[extensionButtons setImage:[NSImage imageWithSystemSymbolName:@"plus" accessibilityDescription:NSLocalizedString(@"Add", nil)] forSegment:0];
	[extensionButtons setImage:[NSImage imageWithSystemSymbolName:@"minus" accessibilityDescription:NSLocalizedString(@"Remove", nil)] forSegment:1];
	[extensionButtons setWidth:24.0 forSegment:0];
	[extensionButtons setWidth:24.0 forSegment:1];
	[extensionButtons setTarget:self];
	[extensionButtons setAction:@selector(clickedExtensionButtons:)];
	[extensionButtons sizeToFit];
	//attached to the list's bottom edge, sharing its border line
	NSRect buttonsFrame = [extensionButtons frame];
	buttonsFrame.origin.x = NSMinX(listFrame);
	buttonsFrame.origin.y = [container isFlipped] ? NSMaxY(listFrame) - 1.0 : NSMinY(listFrame) - NSHeight(buttonsFrame) + 1.0;
	[extensionButtons setFrame:buttonsFrame];
	[extensionButtons setAutoresizingMask:[extensionsScrollView autoresizingMask] & (NSViewMinYMargin | NSViewMaxYMargin)];
	[container addSubview:extensionButtons];
	[self updateExtensionButtons];
}

- (NSPopUpButton*)storageFormatPopUp {
	return storageFormatPopupButton;
}

- (NSScrollView*)extensionsListView {
	return [allowedExtensionsTable enclosingScrollView];
}

- (NSSegmentedControl*)extensionButtons {
	return extensionButtons;
}

- (NSButton*)confirmFileDeletionCheckbox {
	return confirmFileDeletionButton;
}

- (void)updateExtensionButtons {
	[extensionButtons setEnabled:[newExtensionButton isEnabled] forSegment:0];
	[extensionButtons setEnabled:[removeExtensionButton isEnabled] forSegment:1];
}

- (void)clickedExtensionButtons:(id)sender {
	if ([sender selectedSegment] == 0)
		[self addedExtension:sender];
	else
		[self removedExtension:sender];
	[self updateExtensionButtons];
}

- (void)makeClickedExtensionDefault:(id)sender {
	NSInteger row = [allowedExtensionsTable clickedRow];
	if (row < 0) return;
	[allowedExtensionsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	[self makeDefaultExtension:sender];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	if ([menuItem action] == @selector(makeClickedExtensionDefault:))
		return [allowedExtensionsTable clickedRow] >= 0 && [allowedExtensionsTable isEnabled];
	return YES;
}

//the storage format menu marked the file formats with "*" for a footnote comparing them with the single-database
//format ("Using separate files allows Spotlight integration…"); notes are always files now, so drop both and close
//the space the footnote took
- (void)removeStorageFormatFootnote {
	for (NSMenuItem *item in [storageFormatPopupButton itemArray]) {
		NSString *title = [item title];
		NSString *trimmed = [title stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"* \u00a0"]];
		if ([trimmed length] && ![trimmed isEqualToString:title]) [item setTitle:trimmed];
	}
	[storageFormatPopupButton synchronizeTitleAndSelectedItem];
	
	NSView *container = [storageFormatPopupButton superview];
	NSTextField *footnote = nil;
	for (NSView *view in [container subviews]) {
		if ([view isKindOfClass:[NSTextField class]] && [[[(NSTextField*)view stringValue] stringByTrimmingCharactersInSet:
																[NSCharacterSet whitespaceAndNewlineCharacterSet]] hasPrefix:@"*"])
			footnote = (NSTextField*)view;
	}
	if (!footnote || [container isFlipped]) return;
	[footnote setHidden:YES];
	
	NSRect noteFrame = [footnote frame];
	CGFloat aboveBottom = CGFLOAT_MAX, belowTop = -CGFLOAT_MAX;
	NSMutableArray *above = [NSMutableArray array];
	for (NSView *view in [container subviews]) {
		if (view == footnote || [view isHidden]) continue;
		if (NSMinY([view frame]) >= NSMaxY(noteFrame) - 1.0) {
			[above addObject:view];
			aboveBottom = MIN(aboveBottom, NSMinY([view frame]));
		} else if (NSMaxY([view frame]) <= NSMinY(noteFrame) + 1.0) {
			belowTop = MAX(belowTop, NSMaxY([view frame]));
		}
	}
	CGFloat shift = aboveBottom - belowTop - 14.0;
	if (![above count] || belowTop == -CGFLOAT_MAX || shift <= 0.0) return;
	for (NSView *view in above)
		[view setFrameOrigin:NSMakePoint(NSMinX([view frame]), NSMinY([view frame]) - shift)];
}

- (void)setSeparateFileControlsState:(BOOL)separateFileControlsState {
	[newExtensionButton setEnabled:separateFileControlsState];
	[removeExtensionButton setEnabled:separateFileControlsState && [allowedExtensionsTable selectedRow] > -1];
	[makeDefaultExtensionButton setEnabled:separateFileControlsState && [allowedExtensionsTable selectedRow] > -1];
	[self updateExtensionButtons];
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

//still connected in the compiled nib; the control is no longer shown
- (IBAction)changedSecureTextEntry:(id)sender {
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
