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
#import "PrefsWindowController.h"
#import "PTKeyComboPanel.h"
#import "PTKeyCombo.h"
#import "NotationPrefsViewController.h"
#import "ExternalEditorListController.h"
#import "NSData_transformations.h"
#import "NSString_NV.h"
#import "NSFileManager_NV.h"
#import "NSBezierPath_NV.h"
#import "NotationPrefs.h"
#import "GlobalPrefs.h"
#include "BufferUtils.h"

#define SYSTEM_LIST_FONT_SIZE 12.0f

@implementation PrefsWindowController

- (id)init {
    if (self=[super init]) {
		prefsController = [GlobalPrefs defaultPrefs];
		fontPanelWasOpen = NO;
      // remove opacity slider from color pickers -bt
    [[NSColorPanel sharedColorPanel] setShowsAlpha:NO];
		[prefsController registerWithTarget:self forChangesInSettings:
		 @selector(resolveNoteBodyFontFromNotationPrefsFromSender:), 
//		 @selector(setCheckSpellingAsYouType:sender:), 
		 @selector(setConfirmNoteDeletion:sender:), nil];
    }
    return self;
}

- (void)showWindow:(id)sender {
	if (!window) {
		if (![NSBundle loadNibNamed:@"Preferences" owner:self])  {
			NSLog(@"Failed to load Preferences.nib");
			return;
		}
	}
	[checkSpellingButton setState:[prefsController checkSpellingAsYouType]];
	if (![window isVisible])
		[window center];
	
	[window makeKeyAndOrderFront:self];
    if (!NSApp.isActive) {
        [NSApp activateIgnoringOtherApps:YES];
    }
}

- (void)windowWillClose:(NSNotification *)aNotification {
	[prefsController performSelector:@selector(synchronize) withObject:nil afterDelay:0.0];
	
	[[NSFontPanel sharedFontPanel] close];
}
- (void)windowDidResignMain:(NSNotification *)aNotification {
	//hide the font panel--don't want to confuse people into thinking it will affect some other part of the program
	fontPanelWasOpen = [[NSFontPanel sharedFontPanel] isVisible];
	[[NSFontPanel sharedFontPanel] orderOut:nil];
}
- (void)windowDidBecomeMain:(NSNotification *)aNotification {
	if (fontPanelWasOpen) {
		[self changeBodyFont:self];
	}
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
	NSLog(@"I need an update: %@", [menu description]);
}

- (IBAction)setAppShortcut:(id)sender {
	[[PTKeyComboPanel sharedPanel] showSheetForHotkey:[prefsController appActivationHotKey] forWindow:window modalDelegate:self];
}

- (void)keyComboPanelEnded:(PTKeyComboPanel*)panel {
	PTKeyCombo *oldKeyCombo = [[prefsController appActivationKeyCombo] retain];
	[prefsController setAppActivationKeyCombo:[panel keyCombo] sender:self];
	
	[appShortcutField setStringValue:[[prefsController appActivationKeyCombo] description]];
		
	if (![prefsController registerAppActivationKeystrokeWithTarget:[NSApp delegate] selector:@selector(toggleNVActivation:)]) {
		[prefsController setAppActivationKeyCombo:oldKeyCombo sender:self];
		NSLog(@"reverting to old (hopefully working key combo");
	}
	
	[oldKeyCombo release];
}

- (IBAction)changeBodyFont:(id)sender {
	[[NSFontManager sharedFontManager] setSelectedFont:[prefsController noteBodyFont] isMultiple:NO];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

- (void)changeFont:(id)sender {
	NSFontManager *fontMan = [NSFontManager sharedFontManager];
	NSFont *panelFont = [fontMan convertFont:[fontMan selectedFont]];
	
	if (/*![fontMan fontNamed:[panelFont fontName] hasTraits:NSUnboldFontMask | NSUnitalicFontMask]*/
	([fontMan traitsOfFont:panelFont] & NSItalicFontMask) == NSItalicFontMask ||
	([fontMan traitsOfFont:panelFont] & NSBoldFontMask) == NSBoldFontMask) {
		//revert the font--using a bold or italic variant as the default could cause some notes to lose styles
	//	NSLog(@"traits: %u", [fontMan traitsOfFont:panelFont]); 
		
		[self performSelector:@selector(changeBodyFont:) withObject:sender afterDelay:0.0];
		NSBeep();
	} else {
		[prefsController setNoteBodyFont:panelFont sender:self];
	
		[self previewNoteBodyFont];
	}
}

- (NSUInteger)validModesForFontPanel:(NSFontPanel *)fontPanel {
	
	return NSFontPanelSizeModeMask | NSFontPanelCollectionModeMask;
}

- (void)previewNoteBodyFont {
	//the font's name and size, in the field's own (system) font, as font settings elsewhere in macOS show it
	NSFont *font = [prefsController noteBodyFont];
	NSString *fontNameAndSize = font ? [NSString stringWithFormat:@"%@ %g", [font displayName], [font pointSize]] : @"Unknown";
	[bodyTextFontField setStringValue:fontNameAndSize];
	[bodyTextFontField setToolTip:fontNameAndSize];
}

- (IBAction)changedBackgroundTextColorWell:(id)sender {
	[prefsController setBackgroundTextColor:[backgroundColorWell color] sender:self];
}
- (IBAction)changedForegroundTextColorWell:(id)sender {
	[prefsController setForegroundTextColor:[foregroundColorWell color] sender:self];
}
//the User Scheme's dark-mode colors
- (IBAction)changedForegroundTextColorWellDark:(id)sender {
	[prefsController setForegroundTextColorDark:[foregroundColorWellDark color] sender:self];
}
- (IBAction)changedBackgroundTextColorWellDark:(id)sender {
	[prefsController setBackgroundTextColorDark:[backgroundColorWellDark color] sender:self];
}
- (IBAction)changedSearchHighlightColorWell:(id)sender {
	[prefsController setSearchTermHighlightColor:[searchHighlightColorWell color] sender:self];
}
- (IBAction)changedHighlightSearchTerms:(id)sender {
	[prefsController setShouldHighlightSearchTerms:[highlightSearchTermsButton state] sender:self];
}
- (IBAction)changedStyledTextBehavior:(id)sender {
    [prefsController setPastePreservesStyle:[styledTextButton state] sender:self];
}
- (IBAction)changedAutoSuggestLinks:(id)sender {
    [prefsController setLinksAutoSuggested:[autoSuggestLinksButton state] sender:self];
}

- (IBAction)changedMakeURLsClickable:(id)sender {
	[prefsController setMakeURLsClickable:[makeURLsClickable state] sender:self];
}

- (IBAction)changedNoteDeletion:(id)sender {
	[prefsController setConfirmNoteDeletion:[confirmDeletionButton state] sender:self];
}

- (IBAction)changedNotesFolderLocation:(id)sender {
    NSLog(@"Changed notes folder menu");
}

- (IBAction)changedQuitBehavior:(id)sender {
    [prefsController setQuitWhenClosingWindow:[quitWhenClosingButton state] sender:self];
}

- (IBAction)changedSpellChecking:(id)sender {
    [prefsController setCheckSpellingAsYouType:[checkSpellingButton state] sender:self];
}


- (IBAction)changedTabBehavior:(id)sender {
    if (sender != self)
	[self performSelector:@selector(changedTabBehavior:) withObject:self afterDelay:0.0];
    else
	[prefsController setTabIndenting:[[tabKeyRadioMatrix cellAtRow:0 column:0] state] sender:self];
}

- (IBAction)changedExternalEditorsMenu:(id)sender {
  //not currently called as an action in practice
  [self _selectDefaultExternalEditor];
}

- (void)_selectDefaultExternalEditor {
  ExternalEditor *ed = [[ExternalEditorListController sharedInstance] defaultExternalEditor];
  NSInteger idx = ed ? [externalEditorMenuButton indexOfItemWithRepresentedObject:ed] : 0;
  if (idx > -1) {
    [externalEditorMenuButton selectItemAtIndex:idx];
  }
}

- (IBAction)changedTableText:(id)sender {
	if (sender == tableTextMenuButton) {
		if ([tableTextSizeField selectedTag] != 3) [tableTextSizeField setFloatValue:[prefsController tableFontSize]];
		[self performSelector:@selector(changedTableText:) withObject:nil afterDelay:0.0];
	} else {
		[window makeFirstResponder:window];
		float newFontSize = 0.0;
		switch ([tableTextMenuButton selectedTag]) {
			case 1:
				newFontSize = [NSFont smallSystemFontSize];
				break;
			case 2:
				newFontSize = /*[NSFont systemFontSize]*/ SYSTEM_LIST_FONT_SIZE;
				break;
			case 3:
				newFontSize = [tableTextSizeField floatValue];
		}
		[tableTextSizeField setHidden:([tableTextMenuButton selectedTag] != 3)];
		if (![tableTextSizeField isHidden])
			[tableTextSizeField selectText:sender];
		
		[prefsController setTableFontSize:newFontSize sender:self];
	}	
}

- (IBAction)changedTitleCompletion:(id)sender {
    [prefsController setAutoCompleteSearches:[completeNoteTitlesButton state] sender:self];
}

- (IBAction)changedSoftTabs:(id)sender {
	[prefsController setSoftTabs:[softTabsButton state] sender:self];
}

- (void)settingChangedForSelectorString:(NSString*)selectorString {
    if ([selectorString isEqualToString:SEL_STR(resolveNoteBodyFontFromNotationPrefsFromSender:)]) {
		[self previewNoteBodyFont];
//	} else if ([selectorString isEqualToString:SEL_STR(setCheckSpellingAsYouType:sender:)]) {
//		[checkSpellingButton setState:[prefsController checkSpellingAsYouType]];
	} else if ([selectorString isEqualToString:SEL_STR(setConfirmNoteDeletion:sender:)]) {
		[confirmDeletionButton setState:[prefsController confirmNoteDeletion]];
	}
}

- (NSMenu*)directorySelectionMenu {
    NSMenu *theMenu = [[[NSMenu alloc] initWithTitle:@"Note Directory Menu"] autorelease];
    
    FSRef targetRef = {{0}};
    NSString *name = [prefsController displayNameForDefaultDirectoryWithFSRef:&targetRef];
    if (!name)
		name = NSLocalizedString(@"<Directory unknown>", nil);
	
	NSImage *iconImage = nil;
	if (!IsZeros(&targetRef, sizeof(FSRef)) || [[prefsController aliasDataForDefaultDirectory] fsRefAsAlias:&targetRef])
	    iconImage = [NSImage smallIconForFSRef:&targetRef];
	
    NSMenuItem *theMenuItem = [[[NSMenuItem alloc] initWithTitle:name action:nil keyEquivalent:@""] autorelease];
    
    if (iconImage)
		[theMenuItem setImage:iconImage];
    
    [theMenu addItem:theMenuItem];
    
    [theMenu addItem:[NSMenuItem separatorItem]];
    
    theMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Other...", @"title of menu item for selecting a different notes folder")
											  action:@selector(changeDefaultDirectory) keyEquivalent:@""] autorelease];
    [theMenuItem setTarget:self];
    [theMenu addItem:theMenuItem];
    
    return theMenu;
}

- (void)changeDefaultDirectory {
	FSRef notesDirectoryRef;
	NSData *aliasData = nil;
	NSString *directoryPath = nil;

	if ([self getNewNotesRefFromOpenPanel:&notesDirectoryRef returnedPath:&directoryPath]) {
		
		//make sure we're not choosing the same folder as what we started with, because:
		//-[NotationController initWithAliasData:] might attempt to initialize journaling, which will already be in use
		FSRef currentNotesDirectoryRef;
		[[prefsController aliasDataForDefaultDirectory] fsRefAsAlias:&currentNotesDirectoryRef];
		if (FSCompareFSRefs(&notesDirectoryRef, &currentNotesDirectoryRef) != noErr) {
			
			if ((aliasData = [NSData aliasDataForFSRef:&notesDirectoryRef])) {
				[prefsController setAliasDataForDefaultDirectory:aliasData sender:self];
			}
		} else {
			NSLog(@"This folder is already chosen!");
		}
		
	}

	[folderLocationsMenuButton setMenu:[self directorySelectionMenu]];

	if ([folderLocationsMenuButton numberOfItems] > 0)
		[folderLocationsMenuButton selectItemAtIndex:0];
}

- (IBAction)changedRTL:(id)sender {
	[prefsController setRTL:[rtlButton state] sender:self];
	[[NSApp delegate] updateRTL];
}

- (BOOL)getNewNotesRefFromOpenPanel:(FSRef*)notesDirectoryRef returnedPath:(NSString**)path {
    NSString *startingDirectory = nil;
	
    if (!notesDirectoryRef) {
		NSLog(@"notesDirectoryRef is NULL!");
		return NO;
    }
    
    FSRef currentNotesDirectoryRef;
    //resolve alias to fsref; get path from fsref
    if ([[prefsController aliasDataForDefaultDirectory] fsRefAsAlias:&currentNotesDirectoryRef]) {
		NSString *resolvedPath = [[NSFileManager defaultManager] pathWithFSRef:&currentNotesDirectoryRef];
		if (resolvedPath) startingDirectory = resolvedPath;
    }
    
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanCreateDirectories:YES];
    [openPanel setCanChooseFiles:NO];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setResolvesAliases:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setTreatsFilePackagesAsDirectories:NO];
    [openPanel setTitle:NSLocalizedString(@"Select a folder",@"title of open panel for selecting a notes folder")];
    [openPanel setPrompt:NSLocalizedString(@"Select", @"title of open panel button to select a folder")];
    [openPanel setMessage:NSLocalizedString(@"Select the folder that Notational Velocity should use for reading and storing notes.",nil)];
    [openPanel setDirectoryURL:[NSURL fileURLWithPath:startingDirectory]];
    [openPanel setAllowedFileTypes:nil];
    if ([openPanel runModal]==NSFileHandlingPanelOKButton) {
        
		CFStringRef filename = (CFStringRef)[[openPanel URL]path];
		if (!filename)
			return NO;
		
		if (path)
			*path = [[[[openPanel URL]path] copy] autorelease];
		
		//yes, I know that navigation services uses uses FSRefs, but NSSavePanel saves us much more work
		CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, filename, kCFURLPOSIXPathStyle, true);
		[(id)url autorelease];
		if (!url || !CFURLGetFSRef(url, notesDirectoryRef))
			return NO;
		
		return YES;
    }
    
    return NO;
}

- (NotationPrefsViewController*)notationPrefsViewController {
	if (!notationPrefsViewController) {
		notationPrefsViewController = [[NotationPrefsViewController alloc] init];
	}
	return notationPrefsViewController;
}

- (NSView*)databaseView {
    if (![notationPrefsView subviews] || ![[notationPrefsView subviews] count]) {
		[notationPrefsView addSubview:[[self notationPrefsViewController] view]];
		[self layOutNotesPane];
	}
	
    return databaseView;
}

- (void)addToolbarItemWithName:(NSString*)name {
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:name];
	
	NSString *localizedTitle = [[NSBundle mainBundle] localizedStringForKey:name value:@"" table:nil];
    [item setPaletteLabel:localizedTitle];
    [item setLabel:localizedTitle];
    //[item setToolTip:@"General settings: appearance and behavior"];
    //standard SF Symbols for each settings pane
    NSDictionary *symbolNames = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"gearshape", @"General", @"note.text", @"Notes",
                                 @"pencil.line", @"Editing", @"textformat", @"Fonts & Colors", nil];
    [item setImage:[NSImage imageWithSystemSymbolName:[symbolNames objectForKey:name] accessibilityDescription:localizedTitle]];
    [item setTarget:self];
    [item setAction:@selector(switchViews:)];
    [items setObject:item forKey:name];
    [item release];
}

- (void)awakeFromNib {
	
	[window setDelegate:self];
	
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changedTableText:)
												 name:NSControlTextDidEndEditingNotification object:tableTextSizeField];
    
    [tabKeyRadioMatrix setState:[prefsController tabKeyIndents] atRow:0 column:0];
    [tabKeyRadioMatrix setState:![prefsController tabKeyIndents] atRow:1 column:0];
    
    float fontSize = [prefsController tableFontSize];
    int fontButtonIndex = 3;
    if (fontSize == [NSFont smallSystemFontSize]) fontButtonIndex = 0;
    else if (fontSize == /*[NSFont systemFontSize]*/ SYSTEM_LIST_FONT_SIZE) fontButtonIndex = 1;
    [tableTextMenuButton selectItemAtIndex:fontButtonIndex];
    [tableTextSizeField setFloatValue:fontSize];
    [tableTextSizeField setHidden:(fontButtonIndex != 3)];
    
    [externalEditorMenuButton setMenu:[[ExternalEditorListController sharedInstance] addEditorPrefsMenu]];
    [self _selectDefaultExternalEditor];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changedExternalEditorsMenu:) 
                           name:ExternalEditorsChangedNotification object:nil];
    
    [completeNoteTitlesButton setState:[prefsController autoCompleteSearches]];
//    [checkSpellingButton setState:[prefsController checkSpellingAsYouType]];
    [confirmDeletionButton setState:[prefsController confirmNoteDeletion]];
    [quitWhenClosingButton setState:[prefsController quitWhenClosingWindow]];
    [styledTextButton setState:[prefsController pastePreservesStyle]];
    [autoSuggestLinksButton setState:[prefsController linksAutoSuggested]];
	[softTabsButton setState:[prefsController softTabs]];
	[makeURLsClickable setState:[prefsController URLsAreClickable]];
    [rtlButton setState:[prefsController rtl]];
    [self previewNoteBodyFont];
	[appShortcutField setStringValue:[[prefsController appActivationKeyCombo] description]];
	[searchHighlightColorWell setColor:[prefsController searchTermHighlightColorRaw:YES]];
	[highlightSearchTermsButton setState:[prefsController highlightSearchTerms]];
	[foregroundColorWell setColor:[prefsController foregroundTextColor]];
	[backgroundColorWell setColor:[prefsController backgroundTextColor]];
	[foregroundColorWellDark setColor:[prefsController foregroundTextColorDark]];
	[backgroundColorWellDark setColor:[prefsController backgroundTextColorDark]];
    //maximum note body width: a whole number of points within the stepper's range
    NSNumberFormatter *widthFormatter = [[[NSNumberFormatter alloc] init] autorelease];
    [widthFormatter setNumberStyle:NSNumberFormatterNoStyle];
    [widthFormatter setMinimum:[NSNumber numberWithDouble:[maxWidthStepper minValue]]];
    [widthFormatter setMaximum:[NSNumber numberWithDouble:[maxWidthStepper maxValue]]];
    [maxWidthField setFormatter:widthFormatter];
    [maxWidthField setDoubleValue:[prefsController maxNoteBodyWidth]];
    [maxWidthStepper setDoubleValue:[prefsController maxNoteBodyWidth]];
    [appearancePopUp selectItemAtIndex:MIN(MAX([[NSUserDefaults standardUserDefaults] integerForKey:@"AppAppearance"], 0), 2)];
    [altRowsButton setState:[prefsController alternatingRows]];
    [showGridButton setState:[prefsController showGrid]];
    [autoPairButton setState:[prefsController useAutoPairing]];
    items = [[NSMutableDictionary alloc] init];
    
    [self addToolbarItemWithName:@"General"];
    [self addToolbarItemWithName:@"Notes"];	
    [self addToolbarItemWithName:@"Editing"];
	[self addToolbarItemWithName:@"Fonts & Colors"];
		
    toolbar = [[NSToolbar alloc] initWithIdentifier:@"preferencePanes"];
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:NO];
    [toolbar setAutosavesConfiguration:NO]; 
    [window setToolbar:toolbar];
    [toolbar release];  //setToolbar retains the toolbar we pass, so release the one we used.
	//the standard Settings-window toolbar: centered pane icons with labels and a selection highlight
	[window setToolbarStyle:NSWindowToolbarStylePreference];
	
	[window setShowsToolbarButton:NO];
	[self layOutGeneralPane];
	[self layOutEditingPane];
	[self layOutFontsColorsPane];
    [self switchViews:nil];  //select last selected pane by default
    
}


- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
    return [items objectForKey:itemIdentifier];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)theToolbar {
    return [self toolbarDefaultItemIdentifiers:theToolbar];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)theToolbar {
    return [NSArray arrayWithObjects:@"General", @"Notes", @"Editing", @"Fonts & Colors", nil];
}

- (NSArray *)toolbarSelectableItemIdentifiers: (NSToolbar *)toolbar {
    //make all of them selectable. This puts that little grey outline thing around an item when you select it.
    return [items allKeys];
}

- (void)switchViews:(NSToolbarItem *)item {
    NSString *sender = nil;
	
    if (item == nil) {
        sender = [prefsController lastSelectedPreferencesPane];
        [toolbar setSelectedItemIdentifier:sender];
    } else {
        sender = [item itemIdentifier];
		[prefsController setLastSelectedPreferencesPane:sender sender:self];
    }
	
    NSView *prefsView = nil;
	
    [window setTitle:[[NSBundle mainBundle] localizedStringForKey:sender value:@"" table:nil]];
	
    if ([sender isEqualToString:@"General"]){
         prefsView = generalView;
    } else if([sender isEqualToString:@"Notes"]) {
        prefsView = [self databaseView];
    } else if([sender isEqualToString:@"Editing"]) {
        prefsView = editingView;
    } else if([sender isEqualToString:@"Fonts & Colors"]) {
        prefsView = fontsColorsView;
	} else {
		NSLog(@"unknown sender: %@", sender);
	}
    
    if (prefsView == databaseView)
		[folderLocationsMenuButton setMenu:[self directorySelectionMenu]];
	
	NSAssert(prefsView != nil, @"switching to a nil prefs view!");
	[self matchPaneWidths];
    
	[[NSFontPanel sharedFontPanel] close];
	
	//fix this math to convert between window and view coordinates for resolution independence
	
	float userSpaceScaleFactor = [window userSpaceScaleFactor];
	
    //to stop flicker, we make a temp blank view.
	
	NSRect windowContentFrame = ScaleRectWithFactor([[window contentView] frame], userSpaceScaleFactor);
    NSView *tempView = [[NSView alloc] initWithFrame:[[window contentView] frame]];
    [window setContentView:tempView];
    [tempView release];
    
    NSRect newFrame = [window frame];
	NSRect viewFrameForWindow = ScaleRectWithFactor([prefsView frame], userSpaceScaleFactor);
    newFrame.size.height = viewFrameForWindow.size.height + ([window frame].size.height - windowContentFrame.size.height);
    newFrame.size.width = viewFrameForWindow.size.width;
    newFrame.origin.y += (windowContentFrame.size.height - viewFrameForWindow.size.height);
    	
    [window setShowsResizeIndicator:YES];
    [window setFrame:newFrame display:YES animate:YES];

    [window setContentView:prefsView];
}

#pragma mark - form layout

//each pane is laid out as a standard macOS settings form: a column of right-aligned labels and a column of controls,
//built in a grid view from the pane's existing controls (their actions, bindings and outlets are unchanged);
//whatever of the old layout isn't reused (its labels) is hidden

#define FORM_MARGIN 20.0
#define FORM_HELP_WIDTH 250.0
#define FORM_CHECKBOX_INDENT 20.0
#define FORM_MIN_PANE_WIDTH 420.0

typedef enum { FormAlignBaseline = 0, FormAlignCenter, FormAlignTop } FormRowAlignment;

//a row: a label (or nil to continue the group above), its content, the space above it and how the label lines up
static NSDictionary *FormRow(NSString *label, NSView *content, CGFloat spaceAbove, FormRowAlignment alignment) {
	return [NSDictionary dictionaryWithObjectsAndKeys:label ? (id)label : (id)[NSNull null], @"label", content, @"content",
			[NSNumber numberWithDouble:spaceAbove], @"space", [NSNumber numberWithInt:alignment], @"align", nil];
}

static void FormFixSize(NSView *view, CGFloat width, CGFloat height) {
	[view setTranslatesAutoresizingMaskIntoConstraints:NO];
	if (width > 0.0) [[[view widthAnchor] constraintEqualToConstant:width] setActive:YES];
	if (height > 0.0) [[[view heightAnchor] constraintEqualToConstant:height] setActive:YES];
}

//explanatory text: small, secondary, wrapping to the control column
static NSTextField *FormHelp(NSTextField *field, NSString *text) {
	if (!field) field = [NSTextField wrappingLabelWithString:text];
	else if (text) [field setStringValue:text];
	[field setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[field setTextColor:[NSColor secondaryLabelColor]];
	[field setSelectable:NO];
	[[field cell] setWraps:YES];
	[field setPreferredMaxLayoutWidth:FORM_HELP_WIDTH];
	[field setTranslatesAutoresizingMaskIntoConstraints:NO];
	[[[field widthAnchor] constraintLessThanOrEqualToConstant:FORM_HELP_WIDTH] setActive:YES];
	return field;
}

//help text under a checkbox lines up with the checkbox's title
static NSView *FormIndented(NSView *view) {
	NSStackView *stack = [NSStackView stackViewWithViews:[NSArray arrayWithObject:view]];
	[stack setEdgeInsets:NSEdgeInsetsMake(0, FORM_CHECKBOX_INDENT, 0, 0)];
	return stack;
}

static NSStackView *FormHStack(NSArray *views) {
	NSStackView *stack = [NSStackView stackViewWithViews:views];
	[stack setOrientation:NSUserInterfaceLayoutOrientationHorizontal];
	[stack setAlignment:NSLayoutAttributeCenterY];
	[stack setSpacing:8.0];
	return stack;
}

static NSTextField *FormSmallLabel(NSString *text, CGFloat width) {
	NSTextField *label = [NSTextField labelWithString:text];
	[label setAlignment:NSTextAlignmentCenter];
	[label setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[label setTextColor:[NSColor secondaryLabelColor]];
	if (width > 0.0) FormFixSize(label, width, 0.0);
	return label;
}

//a checkbox with its title on the right, as checkboxes normally are (some had a label-style title on the left)
static NSButton *FormCheckbox(NSButton *button, NSString *title) {
	if (title) [button setTitle:title];
	[button setImagePosition:NSImageLeading];
	[button setAlignment:NSTextAlignmentNatural];
	return button;
}

static id FormControlWithAction(NSView *pane, SEL action) {
	for (NSView *view in [pane subviews])
		if ([view isKindOfClass:[NSControl class]] && [(NSControl*)view action] == action) return view;
	return nil;
}

//the pane's multi-line explanatory texts, top to bottom
static NSArray *FormHelpFields(NSView *pane) {
	NSMutableArray *fields = [NSMutableArray array];
	for (NSView *view in [pane subviews])
		if ([view isKindOfClass:[NSTextField class]] && ![(NSTextField*)view isEditable] && ![(NSTextField*)view isBezeled] && NSHeight([view frame]) >= 26.0)
			[fields addObject:view];
	[fields sortUsingComparator:^NSComparisonResult(NSView *a, NSView *b) {
		return NSMinY([a frame]) > NSMinY([b frame]) ? NSOrderedAscending : NSOrderedDescending;
	}];
	return fields;
}

- (void)layOutPane:(NSView*)pane rows:(NSArray*)rows {
	NSMutableArray *cells = [NSMutableArray arrayWithCapacity:[rows count]];
	for (NSDictionary *row in rows) {
		id label = [row objectForKey:@"label"];
		NSView *labelView = label == [NSNull null] ? [NSGridCell emptyContentView] : [NSTextField labelWithString:label];
		[cells addObject:[NSArray arrayWithObjects:labelView, [row objectForKey:@"content"], nil]];
	}
	NSGridView *grid = [NSGridView gridViewWithViews:cells];
	[grid setRowSpacing:8.0];
	[grid setColumnSpacing:8.0];
	[grid setRowAlignment:NSGridRowAlignmentFirstBaseline];
	[[grid columnAtIndex:0] setXPlacement:NSGridCellPlacementTrailing];
	[[grid columnAtIndex:1] setXPlacement:NSGridCellPlacementLeading];
	for (NSUInteger i = 0; i < [rows count]; i++) {
		NSDictionary *row = [rows objectAtIndex:i];
		NSGridRow *gridRow = [grid rowAtIndex:i];
		[gridRow setTopPadding:[[row objectForKey:@"space"] doubleValue]];
		switch ([[row objectForKey:@"align"] intValue]) {
			case FormAlignCenter: [gridRow setRowAlignment:NSGridRowAlignmentNone]; [gridRow setYPlacement:NSGridCellPlacementCenter]; break;
			case FormAlignTop: [gridRow setRowAlignment:NSGridRowAlignmentNone]; [gridRow setYPlacement:NSGridCellPlacementTop]; break;
			default: break;
		}
	}
	
	//the old layout's leftovers (its labels) stay in the pane, hidden: some are still referenced
	for (NSView *view in [pane subviews]) [view setHidden:YES];
	
	[grid setTranslatesAutoresizingMaskIntoConstraints:NO];
	[pane addSubview:grid];
	NSSize fit = [grid fittingSize];
	[pane setFrameSize:NSMakeSize(MAX(FORM_MIN_PANE_WIDTH, ceil(fit.width) + 2.0 * FORM_MARGIN), ceil(fit.height) + 2.0 * FORM_MARGIN)];
	[[[grid centerXAnchor] constraintEqualToAnchor:[pane centerXAnchor]] setActive:YES];
	[[[grid topAnchor] constraintEqualToAnchor:[pane topAnchor] constant:FORM_MARGIN] setActive:YES];
}

- (void)layOutGeneralPane {
	NSButton *setHotkeyButton = FormControlWithAction(generalView, @selector(setAppShortcut:));
	NSButton *menuBarButton = FormControlWithAction(generalView, @selector(toggleStatusItem:));
	NSTextField *autoSelectHelp = [FormHelpFields(generalView) firstObject];
	FormFixSize(appShortcutField, 120.0, 0.0);
	FormFixSize(tableTextSizeField, 44.0, 0.0);
	[togDockButton setTitle:NSLocalizedString(@"Dock", @"Settings: show the app icon in the Dock")];
	[menuBarButton setTitle:NSLocalizedString(@"Menu bar", @"Settings: show the app icon in the menu bar")];
	
	NSMutableArray *rows = [NSMutableArray array];
	[rows addObject:FormRow(NSLocalizedString(@"Appearance:", nil), appearancePopUp, 0, FormAlignBaseline)];
	[rows addObject:FormRow(NSLocalizedString(@"List text size:", nil), FormHStack([NSArray arrayWithObjects:tableTextMenuButton, tableTextSizeField, nil]), 0, FormAlignCenter)];
	[rows addObject:FormRow(NSLocalizedString(@"Hotkey:", @"Settings: the hotkey that brings nv27 to the front"),
							FormHStack([NSArray arrayWithObjects:appShortcutField, setHotkeyButton, nil]), 12, FormAlignCenter)];
	[rows addObject:FormRow(nil, FormHelp(nil, NSLocalizedString(@"Brings nv27 to the front from any app.", nil)), 0, FormAlignBaseline)];
	[rows addObject:FormRow(NSLocalizedString(@"Behavior:", nil), completeNoteTitlesButton, 12, FormAlignBaseline)];
	if (autoSelectHelp) [rows addObject:FormRow(nil, FormIndented(FormHelp(autoSelectHelp, nil)), 0, FormAlignBaseline)];
	[rows addObject:FormRow(nil, confirmDeletionButton, 0, FormAlignBaseline)];
	[rows addObject:FormRow(nil, quitWhenClosingButton, 0, FormAlignBaseline)];
	[rows addObject:FormRow(NSLocalizedString(@"Show icon in:", @"Settings: where the app icon appears (Dock, menu bar)"), togDockButton, 12, FormAlignBaseline)];
	if (menuBarButton) [rows addObject:FormRow(nil, menuBarButton, 0, FormAlignBaseline)];
	[self layOutPane:generalView rows:rows];
}

- (void)layOutEditingPane {
	NSArray *helpFields = FormHelpFields(editingView);
	[tabKeyRadioMatrix sizeToCells];
	FormFixSize(tabKeyRadioMatrix, NSWidth([tabKeyRadioMatrix frame]), NSHeight([tabKeyRadioMatrix frame]));
	FormCheckbox(autoPairButton, NSLocalizedString(@"Match opening characters with closing characters", @"Settings: auto-pairing checkbox"));
	
	NSMutableArray *rows = [NSMutableArray array];
	[rows addObject:FormRow(NSLocalizedString(@"Styled text:", nil), styledTextButton, 0, FormAlignBaseline)];
	[rows addObject:FormRow(NSLocalizedString(@"Spelling:", nil), checkSpellingButton, 0, FormAlignBaseline)];
	[rows addObject:FormRow(NSLocalizedString(@"Tab key:", nil), tabKeyRadioMatrix, 12, FormAlignTop)];
	if ([helpFields count]) [rows addObject:FormRow(nil, FormIndented(FormHelp([helpFields objectAtIndex:0], nil)), 0, FormAlignBaseline)];
	[rows addObject:FormRow(nil, softTabsButton, 0, FormAlignBaseline)];
	[rows addObject:FormRow(NSLocalizedString(@"Links:", nil), makeURLsClickable, 12, FormAlignBaseline)];
	[rows addObject:FormRow(nil, autoSuggestLinksButton, 0, FormAlignBaseline)];
	[rows addObject:FormRow(NSLocalizedString(@"Auto-pair:", nil), autoPairButton, 12, FormAlignBaseline)];
	[rows addObject:FormRow(nil, FormIndented(FormHelp(nil, NSLocalizedString(@"For example, typing a left bracket also adds a right bracket.", nil))), 0, FormAlignBaseline)];
	[rows addObject:FormRow(NSLocalizedString(@"Direction:", nil), rtlButton, 12, FormAlignBaseline)];
	[rows addObject:FormRow(NSLocalizedString(@"External editor:", nil), externalEditorMenuButton, 12, FormAlignBaseline)];
	[self layOutPane:editingView rows:rows];
}

- (void)layOutFontsColorsPane {
	NSButton *selectFontButton = FormControlWithAction(fontsColorsView, @selector(changeBodyFont:));
	NSButton *keepWidthButton = FormControlWithAction(fontsColorsView, @selector(toggleKeepsTextWidthInWindow:));
	FormFixSize(bodyTextFontField, 180.0, 0.0);
	FormFixSize(maxWidthField, 52.0, 0.0);
	for (NSColorWell *well in [NSArray arrayWithObjects:searchHighlightColorWell, foregroundColorWell, foregroundColorWellDark, backgroundColorWell, backgroundColorWellDark, nil])
		FormFixSize(well, 52.0, 24.0);
	FormCheckbox(highlightSearchTermsButton, NSLocalizedString(@"Highlight in notes", @"Settings: highlight search terms in the note text"));
	FormCheckbox(showGridButton, NSLocalizedString(@"Always show grid lines", nil));
	FormCheckbox(altRowsButton, NSLocalizedString(@"Alternating row colors", nil));
	FormCheckbox(keepWidthButton, NSLocalizedString(@"Keep note text width readable", nil));
	
	NSMutableArray *rows = [NSMutableArray array];
	[rows addObject:FormRow(NSLocalizedString(@"Note font:", nil), FormHStack([NSArray arrayWithObjects:bodyTextFontField, selectFontButton, nil]), 0, FormAlignCenter)];
	[rows addObject:FormRow(NSLocalizedString(@"Search terms:", nil), FormHStack([NSArray arrayWithObjects:highlightSearchTermsButton, searchHighlightColorWell, nil]), 12, FormAlignCenter)];
	[rows addObject:FormRow(nil, FormHStack([NSArray arrayWithObjects:FormSmallLabel(NSLocalizedString(@"Light", @"Settings: light-mode color column"), 52.0),
											 FormSmallLabel(NSLocalizedString(@"Dark", @"Settings: dark-mode color column"), 52.0), nil]), 12, FormAlignCenter)];
	[rows addObject:FormRow(NSLocalizedString(@"Text color:", nil), FormHStack([NSArray arrayWithObjects:foregroundColorWell, foregroundColorWellDark, nil]), 0, FormAlignCenter)];
	[rows addObject:FormRow(NSLocalizedString(@"Background:", nil), FormHStack([NSArray arrayWithObjects:backgroundColorWell, backgroundColorWellDark, nil]), 0, FormAlignCenter)];
	[rows addObject:FormRow(nil, FormHelp(nil, NSLocalizedString(@"Used by the User Scheme (⌥⌘3).", nil)), 0, FormAlignBaseline)];
	[rows addObject:FormRow(NSLocalizedString(@"Notes list:", nil), showGridButton, 12, FormAlignBaseline)];
	[rows addObject:FormRow(nil, altRowsButton, 0, FormAlignBaseline)];
	[rows addObject:FormRow(NSLocalizedString(@"Note width:", nil), keepWidthButton, 12, FormAlignBaseline)];
	[rows addObject:FormRow(nil, FormIndented(FormHStack([NSArray arrayWithObjects:[NSTextField labelWithString:NSLocalizedString(@"Maximum:", @"Settings: maximum note width")],
																   maxWidthField, maxWidthStepper, [NSTextField labelWithString:@"px"], nil])), 0, FormAlignCenter)];
	[self layOutPane:fontsColorsView rows:rows];
}

- (void)layOutNotesPane {
	NotationPrefsViewController *notesController = [self notationPrefsViewController];
	NSScrollView *list = [notesController extensionsListView];
	NSSegmentedControl *listButtons = [notesController extensionButtons];
	
	//the extensions list with its +/- buttons attached to its bottom edge
	CGFloat listWidth = 180.0, listHeight = 96.0, buttonsHeight = NSHeight([listButtons frame]);
	NSView *listBox = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, listWidth, listHeight + buttonsHeight - 1.0)] autorelease];
	[list setAutoresizingMask:NSViewNotSizable];
	[listButtons setAutoresizingMask:NSViewNotSizable];
	[list setFrame:NSMakeRect(0, buttonsHeight - 1.0, listWidth, listHeight)];
	[listButtons setFrameOrigin:NSZeroPoint];
	[listBox addSubview:list];
	[listBox addSubview:listButtons];
	FormFixSize(listBox, listWidth, listHeight + buttonsHeight - 1.0);
	[[[folderLocationsMenuButton widthAnchor] constraintGreaterThanOrEqualToConstant:180.0] setActive:YES];
	
	NSMutableArray *rows = [NSMutableArray array];
	[rows addObject:FormRow(NSLocalizedString(@"Notes folder:", nil), folderLocationsMenuButton, 0, FormAlignBaseline)];
	[rows addObject:FormRow(NSLocalizedString(@"Store notes as:", nil), [notesController storageFormatPopUp], 0, FormAlignBaseline)];
	[rows addObject:FormRow(NSLocalizedString(@"File extensions:", nil), listBox, 12, FormAlignTop)];
	[rows addObject:FormRow(nil, FormHelp(nil, NSLocalizedString(@"Files with these extensions are read as notes. Right-click one to make it the default for new notes.", nil)), 0, FormAlignBaseline)];
	[rows addObject:FormRow(nil, [notesController confirmFileDeletionCheckbox], 12, FormAlignBaseline)];
	[self layOutPane:databaseView rows:rows];
}


//all panes share the widest one's width (Fonts & Colors), so switching panes changes only the window's height,
//as in the system's own settings windows; each narrower pane's content stays centered in the extra space
- (void)matchPaneWidths {
	NSArray *panes = [NSArray arrayWithObjects:generalView, [self databaseView], editingView, fontsColorsView, nil];
	CGFloat width = 0.0;
	for (NSView *pane in panes) width = MAX(width, NSWidth([pane frame]));
	for (NSView *pane in panes) {
		CGFloat delta = width - NSWidth([pane frame]);
		if (delta < 1.0) continue;
		BOOL autoresizes = [pane autoresizesSubviews];
		[pane setAutoresizesSubviews:NO];
		[pane setFrameSize:NSMakeSize(width, NSHeight([pane frame]))];
		for (NSView *subview in [pane subviews])
			if ([subview translatesAutoresizingMaskIntoConstraints]) [subview setFrameOrigin:NSMakePoint(round(NSMinX([subview frame]) + delta / 2.0), NSMinY([subview frame]))];
		[pane setAutoresizesSubviews:autoresizes];
	}
}

NSRect ScaleRectWithFactor(NSRect rect, float factor) {
	NSRect newRect = rect;
	newRect.size.width *= factor;
	newRect.size.height *= factor;
	newRect.origin.x *= factor;
	newRect.origin.y *= factor;
	
	//these may still need to be rounded up
	
	return newRect;
}

//elasticwork

//the "Show Dock icon" checkbox (its value is bound to the ShowDockIcon default); without a Dock icon the menu bar
//icon is the way back to nv27, so it is turned on (and its checkbox disabled) while the Dock icon is hidden
- (IBAction)toggleHideDockIcon:(id)sender{
    NSUserDefaults *stdDefaults=[NSUserDefaults standardUserDefaults];
    BOOL showIt=[sender state]==NSControlStateValueOn;
    [stdDefaults setBool:showIt forKey:@"ShowDockIcon"];
    if (!showIt)
        [stdDefaults setBool:YES forKey:@"StatusBarItem"]; //the app controller adds the menu bar icon if it's missing
	[[NSNotificationCenter defaultCenter]postNotificationName:@"AppShouldToggleDockIcon" object:[NSNumber numberWithBool:showIt]];
}

//Automatic (follow the system), Light or Dark
- (IBAction)changedAppearance:(id)sender{
    [[NSUserDefaults standardUserDefaults] setInteger:[sender indexOfSelectedItem] forKey:@"AppAppearance"];
    [(AppController *)[NSApp delegate] applyAppearancePreference];
}

- (IBAction)toggleStatusItem:(id)sender{
//    NSUserDefaults *stdDefaults=[NSUserDefaults standardUserDefaults];
//    BOOL showIt=[stdDefaults boolForKey:@"StatusBarItem"];
//    if (showIt) {
//        [stdDefaults setBool:NO forKey:@"StatusBarItem"];
//        //        [togDockLabel setStringValue:@"This will immediately restart NV"];
//    }else{
//        [stdDefaults setBool:YES forKey:@"StatusBarItem"];
//    }
//    [stdDefaults synchronize];
	[[NSNotificationCenter defaultCenter]postNotificationName:@"AppShouldToggleStatusItem" object:nil];
}


- (IBAction)toggleKeepsTextWidthInWindow:(id)sender{
   
    [prefsController setManagesTextWidthInWindow:[sender state] sender:self];
//		[[NSApp delegate] setMaxNoteBodyWidth];
}

- (IBAction)setMaxWidth:(id)sender{
	//from either the field or its stepper; keep the two in step
	CGFloat dbWidth = MIN(MAX([sender floatValue], [maxWidthStepper minValue]), [maxWidthStepper maxValue]);
	dbWidth = dbWidth - fmod(dbWidth,2.0);
	[maxWidthField setDoubleValue:dbWidth];
	[maxWidthStepper setDoubleValue:dbWidth];
	[prefsController setMaxNoteBodyWidth:dbWidth sender:self];
//	[[NSApp delegate] setMaxNoteBodyWidth];
}

- (IBAction)changedAltRows:(id)sender {
	[prefsController setAlternatingRows:[altRowsButton state] sender:self];
    [[NSApp delegate] refreshNotesList];
}

- (IBAction)changedAutoPairing:(id)sender{
	[prefsController setUseAutoPairing:[autoPairButton state]];
    //  [[NSApp delegate] refreshNotesList];
}

- (IBAction)changedShowGrid:(id)sender {
	[prefsController setShowGrid:[showGridButton state] sender:self];
    [[NSApp delegate] refreshNotesList];
}

@end
