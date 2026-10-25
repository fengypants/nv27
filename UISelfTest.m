//
//  UISelfTest.m
//  Notation
//
//  Debug-build-only diagnostics, run when the NV27_UI_SELFTEST environment variable is set (CI does this).
//  After launch it reports which view receives clicks in the note editor, simulates clicks to check that the
//  editor takes keyboard focus, prints the window layout, and prints a base64 PNG snapshot of the window.
//

#if DEBUG

#import "AppController.h"
#import "LinkingEditor.h"
#import "NotesTableView.h"
#import "DualField.h"
#import "NoteObject.h"
#import "ShortcutsWindowController.h"
#import "PTKeyComboPanel.h"
#import "BookmarksController.h"
#import "GlobalPrefs.h"
#import "NotationController.h"
#import "NotationFileManager.h"
#import "NotationPrefs.h"
#import "AttributedPlainText.h"
#import "TagEditingManager.h"
#import <objc/runtime.h>
#include <stdio.h>
#include <errno.h>

static BOOL selfTestTracingFocus = NO;

//while the click checks run, report where focus is moved to the search field from (with a backtrace), and where
//the note selection is cleared from; that's what the focus bug looks like
@interface NSWindow (UISelfTestTracing)
@end
@implementation NSWindow (UISelfTestTracing)
- (BOOL)nv27_selfTestMakeFirstResponder:(NSResponder*)responder {
	if (selfTestTracingFocus) {
		fprintf(stdout, "SELFTEST makeFirstResponder:%s (window %s, key=%d) from:\n", [NSStringFromClass([responder class]) UTF8String],
				[NSStringFromClass([self class]) UTF8String], [self isKeyWindow]);
		for (NSString *frame in [[NSThread callStackSymbols] subarrayWithRange:NSMakeRange(1, MIN((NSUInteger)18, [[NSThread callStackSymbols] count] - 1))])
			fprintf(stdout, "SELFTEST   %s\n", [frame UTF8String]);
		fflush(stdout);
	}
	return [self nv27_selfTestMakeFirstResponder:responder];
}
@end

@interface NSTableView (UISelfTestTracing)
@end
@implementation NSTableView (UISelfTestTracing)
- (void)nv27_selfTestDeselectAll:(id)sender {
	if (selfTestTracingFocus && [self isKindOfClass:[NotesTableView class]] && [self numberOfSelectedRows]) {
		fprintf(stdout, "SELFTEST notes list deselectAll from:\n");
		for (NSString *frame in [[NSThread callStackSymbols] subarrayWithRange:NSMakeRange(1, MIN((NSUInteger)14, [[NSThread callStackSymbols] count] - 1))])
			fprintf(stdout, "SELFTEST   %s\n", [frame UTF8String]);
		fflush(stdout);
	}
	[self nv27_selfTestDeselectAll:sender];
}
@end

static void SelfTestLog(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);
static void SelfTestLog(NSString *format, ...) {
	va_list args;
	va_start(args, format);
	NSString *line = [[[NSString alloc] initWithFormat:format arguments:args] autorelease];
	va_end(args);
	fprintf(stdout, "SELFTEST %s\n", [line UTF8String]);
	fflush(stdout);
}

static NSString *ViewChain(NSView *view) {
	NSMutableArray *names = [NSMutableArray array];
	for (; view; view = [view superview])
		[names addObject:NSStringFromClass([view class])];
	return [names componentsJoinedByString:@" < "];
}

static NSString *ResponderName(NSResponder *responder) {
	return responder ? [NSString stringWithFormat:@"%@ %p", NSStringFromClass([responder class]), responder] : @"(nil)";
}

@interface AppController (UISelfTest)
@end

@implementation AppController (UISelfTest)

+ (void)load {
	if (!getenv("NV27_UI_SELFTEST"))
		return;
	method_exchangeImplementations(class_getInstanceMethod([NSWindow class], @selector(makeFirstResponder:)),
								   class_getInstanceMethod([NSWindow class], @selector(nv27_selfTestMakeFirstResponder:)));
	method_exchangeImplementations(class_getInstanceMethod([NSTableView class], @selector(deselectAll:)),
								   class_getInstanceMethod([NSTableView class], @selector(nv27_selfTestDeselectAll:)));
	[[NSNotificationCenter defaultCenter] addObserverForName:NSApplicationDidFinishLaunchingNotification object:nil
													   queue:nil usingBlock:^(NSNotification *note) {
		[[NSApp delegate] performSelector:@selector(_selfTestPrepare) withObject:nil afterDelay:4.0];
	}];
}

- (void)_selfTestPrepare {
	[NSApp activateIgnoringOtherApps:YES];
	[window makeKeyAndOrderFront:nil];
	[window makeKeyWindow];
	if (!currentNote && [notesTableView numberOfRows] > 0)
		[notesTableView selectRowAndScroll:0];

	SelfTestLog(@"state: key=%d visible=%d windowFrame=%@ notes=%ld currentNote=%@ editorHidden=%d firstResponder=%@",
				[window isKeyWindow], [window isVisible], NSStringFromRect([window frame]), (long)[notesTableView numberOfRows],
				currentNote ? titleOfNote(currentNote) : @"(none)", [textView isHidden], ResponderName([window firstResponder]));
	//the notes a new notes folder starts with, line by line
	for (NSInteger i = 0; i < [notesTableView numberOfRows]; i++) {
		NoteObject *note = [notationController noteObjectAtFilteredIndex:i];
		SelfTestLog(@"note \"%@\":", titleOfNote(note));
		for (NSString *line in [[[note contentString] string] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]])
			SelfTestLog(@"  | %@", line);
	}
	[self _selfTestBookmarks];
	[self performSelector:@selector(_selfTestClicks) withObject:nil afterDelay:1.0];
}

//bookmarking a selected note with nothing typed in the search field saved the bookmark without its note's UUID,
//and loading that saved entry raised an exception partway through the next launch (no main window): a bookmark
//made that way must keep its UUID, and unreadable saved entries must be skipped
- (void)_selfTestBookmarks {
	@try {
		NoteBookmark *bookmark = [[[NoteBookmark alloc] initWithNoteObject:currentNote searchString:nil] autorelease];
		NSDictionary *saved = [bookmark dictionaryRep];
		NSArray *stored = [NSArray arrayWithObjects:[NSDictionary dictionary], saved, @"not a bookmark", nil];
		BookmarksController *loaded = [[[BookmarksController alloc] initWithBookmarks:stored] autorelease];
		SelfTestLog(@"bookmarks: saved without search text keeps UUID=%d; loading 3 stored entries (1 empty, 1 junk) kept %lu, no exception",
					[[saved objectForKey:@"NoteUUIDString"] length] > 0, (unsigned long)[[loaded dictionaryReps] count]);
	} @catch (NSException *exception) {
		SelfTestLog(@"bookmarks: EXCEPTION %@: %@", [exception name], [exception reason]);
	}
}

- (NSPoint)_selfTestPointInEditorAtFraction:(NSPoint)fraction {
	NSScrollView *scrollView = [textView enclosingScrollView];
	NSRect r = [scrollView convertRect:[scrollView bounds] toView:nil];
	return NSMakePoint(NSMinX(r) + fraction.x * NSWidth(r), NSMinY(r) + fraction.y * NSHeight(r));
}

- (void)_selfTestClickAtWindowPoint:(NSPoint)point label:(NSString*)label {
	NSTimeInterval now = [[NSProcessInfo processInfo] systemUptime];
	NSEvent *down = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:point modifierFlags:0 timestamp:now
								   windowNumber:[window windowNumber] context:nil eventNumber:1 clickCount:1 pressure:1.0];
	NSEvent *up = [NSEvent mouseEventWithType:NSEventTypeLeftMouseUp location:point modifierFlags:0 timestamp:now + 0.05
								 windowNumber:[window windowNumber] context:nil eventNumber:2 clickCount:1 pressure:0.0];
	NSResponder *before = [window firstResponder];
	//deliver it the way real clicks arrive (through NSApplication); the text view runs a tracking loop on
	//mouse-down that ends when it dequeues the mouse-up
	[NSApp postEvent:up atStart:NO];
	[NSApp sendEvent:down];
	SelfTestLog(@"click %@ at %@ (windowKey=%d): firstResponder before=%@ after=%@ editorFocused=%d", label, NSStringFromPoint(point),
				[window isKeyWindow], ResponderName(before), ResponderName([window firstResponder]), [window firstResponder] == textView);
	//anything that moves focus back later (delayed performs, notifications) shows up after the run loop runs
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
	SelfTestLog(@"click %@: 0.5s later firstResponder=%@ editorFocused=%d", label, ResponderName([window firstResponder]),
				[window firstResponder] == textView);
	
	//type a character the way the keyboard would, to confirm the click left the note editable
	NSString *before2 = [[[textView string] copy] autorelease];
	NSEvent *key = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:now + 0.6
								windowNumber:[window windowNumber] context:nil characters:@"Z" charactersIgnoringModifiers:@"Z" isARepeat:NO keyCode:6];
	[NSApp sendEvent:key];
	SelfTestLog(@"click %@: typing 'Z' changed the note=%d (search field now \"%@\")", label,
				![[textView string] isEqualToString:before2], [field stringValue]);
	if (![[textView string] isEqualToString:before2]) [[textView undoManager] undo];
}

- (void)_selfTestClicks {
	//simulated clicks only reach the editor in the key window; give activation a few tries (CI runners can be slow)
	for (int attempt = 0; attempt < 6 && ![window isKeyWindow]; attempt++) {
		[NSApp activateIgnoringOtherApps:YES];
		[window makeKeyAndOrderFront:nil];
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
	}
	SelfTestLog(@"window key before clicks=%d", [window isKeyWindow]);
	[window makeFirstResponder:textView];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
	NSView *frameView = [[window contentView] superview];
	NSScrollView *scrollView = [textView enclosingScrollView];

	SelfTestLog(@"editor scrollView=%@ frameInWindow=%@ frameInSuperview=%@ superview=%@ verticalScrollerFrame=%@ clipFrame=%@ textViewFrame=%@",
				NSStringFromClass([scrollView class]), NSStringFromRect([scrollView convertRect:[scrollView bounds] toView:nil]),
				NSStringFromRect([scrollView frame]), NSStringFromClass([[scrollView superview] class]),
				NSStringFromRect([[scrollView verticalScroller] frame]), NSStringFromRect([[scrollView contentView] frame]),
				NSStringFromRect([textView frame]));
	SelfTestLog(@"search field=%@ frameInWindow=%@ chain=%@ toolbarVisible=%d", NSStringFromClass([field class]),
				NSStringFromRect([field convertRect:[field bounds] toView:nil]), ViewChain(field), [[window toolbar] isVisible]);

	CGFloat fractions[] = {0.1, 0.5, 0.9};
	for (int i = 0; i < 3; i++) {
		for (int j = 0; j < 3; j++) {
			NSPoint p = [self _selfTestPointInEditorAtFraction:NSMakePoint(fractions[i], fractions[j])];
			NSView *hit = [frameView hitTest:[frameView convertPoint:p fromView:nil]];
			SelfTestLog(@"hitTest editor (%.1f,%.1f) %@ -> %@", fractions[i], fractions[j], NSStringFromPoint(p), ViewChain(hit));
		}
	}

	NSPoint center = [self _selfTestPointInEditorAtFraction:NSMakePoint(0.5, 0.5)];
	[window makeFirstResponder:notesTableView];
	selfTestTracingFocus = YES;
	[self _selfTestClickAtWindowPoint:center label:@"editor center, from notes list"];
	selfTestTracingFocus = NO;
	[window makeFirstResponder:field];
	[self _selfTestClickAtWindowPoint:center label:@"editor center, from search field"];
	[window makeFirstResponder:field];
	[self _selfTestClickAtWindowPoint:[self _selfTestPointInEditorAtFraction:NSMakePoint(0.2, 0.85)] label:@"editor upper left, from search field"];

	[self performSelector:@selector(_selfTestSnapshot) withObject:nil afterDelay:0.5];
}

static void PrintSnapshotOfWindow(NSWindow *aWindow, NSString *tag) {
	NSView *frameView = [[aWindow contentView] superview];
	NSBitmapImageRep *rep = [frameView bitmapImageRepForCachingDisplayInRect:[frameView bounds]];
	[frameView cacheDisplayInRect:[frameView bounds] toBitmapImageRep:rep];
	NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:[NSDictionary dictionary]];
	NSString *base64 = [png base64EncodedStringWithOptions:0];
	SelfTestLog(@"snapshot %@ (%@): %ldx%ld px, %lu bytes", tag, [aWindow title], (long)[rep pixelsWide], (long)[rep pixelsHigh], (unsigned long)[png length]);
	for (NSUInteger i = 0; i < [base64 length]; i += 4000) {
		fprintf(stdout, "SELFTEST-PNG-%s %s\n", [tag UTF8String], [[base64 substringWithRange:NSMakeRange(i, MIN(4000, [base64 length] - i))] UTF8String]);
	}
	fflush(stdout);
}

- (void)_selfTestSnapshot {
	SelfTestLog(@"search field frameInWindow=%@ notes header=%@", NSStringFromRect([field convertRect:[field bounds] toView:nil]),
				NSStringFromRect([[notesTableView headerView] convertRect:[[notesTableView headerView] bounds] toView:nil]));
	PrintSnapshotOfWindow(window, @"main");
	//the "back to search" button that replaces the pencil while hovering over it
	[(DualFieldCell*)[field cell] setShowsSnapbackButton:YES];
	[field display];
	PrintSnapshotOfWindow(window, @"main-snapback");
	[(DualFieldCell*)[field cell] setShowsSnapbackButton:NO];
	
	//the side-by-side ("horizontal") layout, then back
	[self switchViewLayout:nil];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
	[window display];
	PrintSnapshotOfWindow(window, @"main-horizontal");
	[self switchViewLayout:nil];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
	
	//the same window in Dark Mode (the B/W scheme switches to its dark variant), then back to the system setting
	[NSApp setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
	[window display];
	SelfTestLog(@"dark mode: appearanceIsDark=%d tableBackground=%@ editorBackground=%@ field drawsBackground=%d background=%@ bezeled=%d",
				[self appearanceIsDark], [notesTableView backgroundColor], [textView backgroundColor], [field drawsBackground],
				[field backgroundColor], [field isBezeled]);
	PrintSnapshotOfWindow(window, @"main-dark");
	//the Low Contrast scheme, dark then light, then back to B/W
	[self setLCColorScheme:nil];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
	[window display];
	PrintSnapshotOfWindow(window, @"main-lc-dark");
	[NSApp setAppearance:nil];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
	[window display];
	PrintSnapshotOfWindow(window, @"main-lc");
	[self setBWColorScheme:nil];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
	
	[self showPreferencesWindow:nil];
	[self performSelector:@selector(_selfTestSnapshotSettings) withObject:nil afterDelay:1.5];
}

- (NSWindow*)_selfTestSettingsWindow {
	for (NSWindow *aWindow in [NSApp windows]) {
		if (aWindow != window && [aWindow isVisible] && [aWindow toolbar])
			return aWindow;
	}
	return nil;
}

- (void)_selfTestSnapshotSettings {
	NSWindow *settingsWindow = [self _selfTestSettingsWindow];
	if (settingsWindow) PrintSnapshotOfWindow(settingsWindow, @"settings");
	//then each of the other panes, switching the way a toolbar click does
	NSArray *panes = [NSArray arrayWithObjects:@"Notes", @"Editing", @"Fonts & Colors", nil];
	for (NSString *pane in panes) {
		for (NSToolbarItem *item in [[settingsWindow toolbar] items]) {
			if ([[item itemIdentifier] isEqualToString:pane]) {
				[[settingsWindow toolbar] setSelectedItemIdentifier:pane];
				[prefsWindowController performSelector:@selector(switchViews:) withObject:item];
				[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
				PrintSnapshotOfWindow(settingsWindow, [@"settings-" stringByAppendingString:[[[pane lowercaseString] componentsSeparatedByString:@" "] objectAtIndex:0]]);
			}
		}
	}
	[settingsWindow orderOut:nil];
	
	//the hotkey panel (its icon is an SF Symbol) and the Bookmarks window
	NSWindow *hotkeyPanel = [[PTKeyComboPanel sharedPanel] window];
	[hotkeyPanel display];
	PrintSnapshotOfWindow(hotkeyPanel, @"hotkey");
	[[prefsController bookmarksController] showBookmarks:nil];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
	for (NSWindow *aWindow in [NSApp windows]) {
		if (aWindow != window && [aWindow isVisible] && [aWindow isKindOfClass:[NSPanel class]] && [[aWindow frameAutosaveName] isEqualToString:@"bookmarksWindow"]) {
			PrintSnapshotOfWindow(aWindow, @"bookmarks");
			[aWindow orderOut:nil];
		}
	}
	
	//the About panel, and how wide candidate lines for its first credits line are next to its text area
	[self showAboutPanel:nil];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
	for (NSWindow *aWindow in [NSApp windows]) {
		if (aWindow == window || ![aWindow isVisible] || [aWindow toolbar]) continue;
		NSMutableArray *stack = [NSMutableArray arrayWithObject:[aWindow contentView]];
		while ([stack count]) {
			NSView *view = [stack lastObject]; [stack removeLastObject];
			[stack addObjectsFromArray:[view subviews]];
			if ([view isKindOfClass:[NSTextView class]]) {
				NSTextView *tv = (NSTextView*)view;
				CGFloat available = [[tv textContainer] size].width - 2 * [[tv textContainer] lineFragmentPadding];
				NSDictionary *attrs = [NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]] forKey:NSFontAttributeName];
				for (NSString *line in [NSArray arrayWithObjects:@"A simplified nvALT for Apple silicon.", nil])
					SelfTestLog(@"about line \"%@\": %.1f pt wide, text area %.1f pt (fits=%d)", line,
								[line sizeWithAttributes:attrs].width, available, [line sizeWithAttributes:attrs].width <= available);
			}
		}
		PrintSnapshotOfWindow(aWindow, @"about");
		[aWindow orderOut:nil];
	}
	
	[window makeKeyAndOrderFront:nil];
	[self togglePreview:nil];
	[self performSelector:@selector(_selfTestSnapshotPreview) withObject:nil afterDelay:2.0];
}

- (void)_selfTestSnapshotPreview {
	for (NSWindow *aWindow in [NSApp windows]) {
		if (aWindow != window && [aWindow isVisible] && ![aWindow toolbar] && NSWidth([aWindow frame]) > 200)
			PrintSnapshotOfWindow(aWindow, @"preview");
	}

	//Help › Keyboard Shortcuts, opened through its menu item, at the top and the end, in light and dark
	NSMenuItem *shortcutsItem = nil;
	for (NSMenuItem *topItem in [[NSApp mainMenu] itemArray])
		for (NSMenuItem *item in [[topItem submenu] itemArray])
			if ([item action] == @selector(showHelpDocument:) && [item tag] == 1) shortcutsItem = item;
	SelfTestLog(@"keyboard shortcuts menu item: %@", [shortcutsItem title]);
	[NSApp sendAction:[shortcutsItem action] to:[shortcutsItem target] from:shortcutsItem];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
	NSWindow *shortcutsWindow = [[ShortcutsWindowController sharedController] window];
	NSTextView *shortcutsText = (NSTextView*)[[(NSScrollView*)[shortcutsWindow contentView] documentView] retain];
	SelfTestLog(@"keyboard shortcuts window: visible=%d title=\"%@\" characters=%lu", [shortcutsWindow isVisible], [shortcutsWindow title],
				(unsigned long)[[shortcutsText string] length]);
	PrintSnapshotOfWindow(shortcutsWindow, @"shortcuts");
	[self _selfTestSnapshotShortcutsText:shortcutsText containing:@"fn↑" tag:@"shortcuts-paging"];
	[shortcutsText scrollRangeToVisible:NSMakeRange([[shortcutsText string] length], 0)];
	[shortcutsWindow display];
	PrintSnapshotOfWindow(shortcutsWindow, @"shortcuts-end");
	[shortcutsText scrollRangeToVisible:NSMakeRange(0, 0)];
	[NSApp setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
	[shortcutsWindow display];
	PrintSnapshotOfWindow(shortcutsWindow, @"shortcuts-dark");
	[NSApp setAppearance:nil];
	//each translation, top and end (the keys column widens for longer key names)
	for (NSString *localization in [NSArray arrayWithObjects:@"de", @"fr", @"it", @"pt-PT", @"zh", nil]) {
		[[ShortcutsWindowController sharedController] performSelector:@selector(_selfTestShowLocalization:) withObject:localization];
		[shortcutsText scrollRangeToVisible:NSMakeRange(0, 0)];
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
		[shortcutsWindow display];
		SelfTestLog(@"keyboard shortcuts %@: characters=%lu", localization, (unsigned long)[[shortcutsText string] length]);
		PrintSnapshotOfWindow(shortcutsWindow, [@"shortcuts-" stringByAppendingString:localization]);
		if ([localization isEqualToString:@"zh"])
			[self _selfTestSnapshotShortcutsText:shortcutsText containing:@"fn↑" tag:@"shortcuts-zh-paging"];
		[shortcutsText scrollRangeToVisible:NSMakeRange([[shortcutsText string] length], 0)];
		[shortcutsWindow display];
		PrintSnapshotOfWindow(shortcutsWindow, [NSString stringWithFormat:@"shortcuts-%@-end", localization]);
	}
	[shortcutsText release];
	[shortcutsWindow orderOut:nil];
	[self _selfTestUpstreamFixes];
	[self _selfTestListKeys];
	[self _selfTestArrowFromSearch];
	[self _selfTestListsAndMarkdown];
	SelfTestLog(@"done");
	exit(0);
}

//a key press delivered the way the keyboard's are: queued, then taken off the queue and sent, so it's the app's
//current event while it's handled
- (void)_selfTestPostKey:(unichar)key keyCode:(unsigned short)keyCode flags:(NSEventModifierFlags)flags {
	NSString *chars = [NSString stringWithCharacters:&key length:1];
	[NSApp postEvent:[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:flags
									 timestamp:[[NSProcessInfo processInfo] systemUptime] windowNumber:[window windowNumber] context:nil
									characters:chars charactersIgnoringModifiers:chars isARepeat:NO keyCode:keyCode] atStart:NO];
	NSEvent *event;
	while ((event = [NSApp nextEventMatchingMask:NSEventMaskAny untilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]
										   inMode:NSDefaultRunLoopMode dequeue:YES]))
		[NSApp sendEvent:event];
	SelfTestSpin(0.3);
}

- (NSString*)_selfTestSelectionDescription {
	NSInteger row = [notesTableView selectedRow];
	NSString *focus = [window firstResponder] == notesTableView ? @"list" : [field currentEditor] ? @"search field" : NSStringFromClass([[window firstResponder] class]);
	return row < 0 ? [NSString stringWithFormat:@"none selected, focus in %@", focus] :
		[NSString stringWithFormat:@"row %ld \"%@\", focus in %@", (long)row, titleOfNote([notationController noteObjectAtFilteredIndex:row]), focus];
}

//the down arrow in the search field goes into the notes list: to the note the search selected, or the first
- (void)_selfTestArrowFromSearch {
	selfTestStage = "down arrow from the search field";
	const NSEventModifierFlags arrowFlags = NSEventModifierFlagFunction | NSEventModifierFlagNumericPad;
	[window makeKeyAndOrderFront:nil];
	[self searchForString:@""];
	SelfTestSpin(0.5);
	for (NSInteger i = 0; i < [notesTableView numberOfRows]; i++)
		SelfTestLog(@"arrow from search: list row %ld \"%@\"", (long)i, titleOfNote([notationController noteObjectAtFilteredIndex:i]));
	
	//1: typing a note's whole title selects it; the down arrow goes to it in the list, then on to the next
	[notesTableView deselectAll:nil];
	[window makeFirstResponder:field];
	NSString *firstTitle = titleOfNote([notationController noteObjectAtFilteredIndex:0]);
	[[field currentEditor] insertText:firstTitle];
	SelfTestSpin(0.5);
	NSString *afterTyping = [self _selfTestSelectionDescription];
	[self _selfTestPostKey:NSDownArrowFunctionKey keyCode:125 flags:arrowFlags];
	NSString *afterFirst = [self _selfTestSelectionDescription];
	[self _selfTestPostKey:NSDownArrowFunctionKey keyCode:125 flags:arrowFlags];
	SelfTestLog(@"arrow from search: typed \"%@\" -> %@; down arrow -> %@; again -> %@", firstTitle, afterTyping, afterFirst,
				[self _selfTestSelectionDescription]);
	[window display];
	PrintSnapshotOfWindow(window, @"list-from-search");
	
	//1b: typing the start of a title selects that note, which can sort below notes mentioning the text in their body
	[self searchForString:@""];
	SelfTestSpin(0.3);
	[notesTableView deselectAll:nil];
	[window makeFirstResponder:field];
	[[field currentEditor] insertText:@"Exc"];
	SelfTestSpin(0.5);
	afterTyping = [self _selfTestSelectionDescription];
	NSMutableArray *listed = [NSMutableArray array];
	for (NSInteger i = 0; i < [notesTableView numberOfRows]; i++) [listed addObject:titleOfNote([notationController noteObjectAtFilteredIndex:i])];
	[self _selfTestPostKey:NSDownArrowFunctionKey keyCode:125 flags:arrowFlags];
	afterFirst = [self _selfTestSelectionDescription];
	[self _selfTestPostKey:NSDownArrowFunctionKey keyCode:125 flags:arrowFlags];
	SelfTestLog(@"arrow from search: typed \"Exc\" (list: %@) -> %@; down arrow -> %@; again -> %@", [listed componentsJoinedByString:@" | "],
				afterTyping, afterFirst, [self _selfTestSelectionDescription]);
	
	//2: nothing selected: the down arrow goes to the first note
	[self searchForString:@""];
	SelfTestSpin(0.3);
	[notesTableView deselectAll:nil];
	[window makeFirstResponder:field];
	SelfTestSpin(0.3);
	NSString *before = [self _selfTestSelectionDescription];
	[self _selfTestPostKey:NSDownArrowFunctionKey keyCode:125 flags:arrowFlags];
	afterFirst = [self _selfTestSelectionDescription];
	[self _selfTestPostKey:NSDownArrowFunctionKey keyCode:125 flags:arrowFlags];
	SelfTestLog(@"arrow from search: %@; down arrow -> %@; again -> %@", before, afterFirst, [self _selfTestSelectionDescription]);
	
	//3: typing in the list still goes to the search field
	[self _selfTestPostKey:'h' keyCode:4 flags:0];
	SelfTestLog(@"arrow from search: typing 'h' in the list -> search field \"%@\", %@", [field stringValue], [self _selfTestSelectionDescription]);
	selfTestStage = "";
}

static NSString *SelfTestVisibleNewlines(NSString *text) {
	return [text stringByReplacingOccurrencesOfString:@"\n" withString:@"⏎"];
}

//Return on an empty list item ends the list; ⌘B/⌘I/⌘Y add Markdown with Markdown completion on, the default
- (void)_selfTestListsAndMarkdown {
	selfTestStage = "lists and Markdown shortcuts";
	NSAttributedString *body = [[[NSAttributedString alloc] initWithString:@"" attributes:[prefsController noteBodyAttributes]] autorelease];
	NoteObject *note = [[[NoteObject alloc] initWithNoteBody:body title:@"List and Markdown test" delegate:notationController
													  format:[notationController currentNoteStorageFormat] labels:nil] autorelease];
	[notationController addNewNote:note];
	[self searchForString:@""];
	SelfTestSpin(0.3);
	NSInteger row = [self _selfTestRowOfNote:note];
	[notesTableView selectRowAndScroll:row];
	SelfTestSpin(0.3);
	[window makeFirstResponder:textView];
	SelfTestLog(@"lists: Markdown completion on by default=%d, list bullets on=%d", [[NSUserDefaults standardUserDefaults] boolForKey:@"UsesMarkdownCompletions"],
				[prefsController autoFormatsListBullets]);
	//with Markdown completion off, a plain text note can't keep bold, italic or strikethrough: those are unavailable
	{
		[textView setSelectedRange:NSMakeRange(0, [[textView string] length])];
		[textView insertText:@"a word here"];
		NSMutableArray *states = [NSMutableArray array];
		for (NSString *action in [NSArray arrayWithObjects:@"bold:", @"italic:", @"strikethroughNV:", @"defaultStyle:", nil]) {
			NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:action action:NSSelectorFromString(action) keyEquivalent:@""] autorelease];
			[states addObject:[NSString stringWithFormat:@"%@ %@", action, [textView validateMenuItem:item] ? @"enabled" : @"disabled"]];
		}
		[textView setSelectedRange:NSMakeRange(2, 4)];
		[textView bold:nil];
		[textView italic:nil];
		[textView strikethroughNV:nil];
		NSDictionary *attrs = [[textView textStorage] attributesAtIndex:3 effectiveRange:NULL];
		NSFont *font = [attrs objectForKey:NSFontAttributeName];
		SelfTestLog(@"styles: plain text note (format %ld), Markdown completion off: %@; after bold, italic, strikethrough \"%@\" bold=%d italic=%d struck=%d",
					(long)storageFormatOfNote(note), [states componentsJoinedByString:@", "], [textView string],
					([[NSFontManager sharedFontManager] traitsOfFont:font] & NSBoldFontMask) != 0 || [attrs objectForKey:NSStrokeWidthAttributeName] != nil,
					([[NSFontManager sharedFontManager] traitsOfFont:font] & NSItalicFontMask) != 0 || [attrs objectForKey:NSObliquenessAttributeName] != nil,
					[attrs objectForKey:NSStrikethroughStyleAttributeName] != nil);
	}
	
	//pasting styled text: plain into a plain text note; Paste with Styles (⇧⌘V) brings basic styles as Markdown there,
	//and as styles in a Rich Text note
	{
		NSMutableAttributedString *clip = [[[NSMutableAttributedString alloc] initWithString:@"Hello bold and italic and struck and link."
																				  attributes:@{NSFontAttributeName: [NSFont fontWithName:@"Helvetica" size:13]}] autorelease];
		[clip addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Helvetica-Bold" size:13] range:NSMakeRange(6, 4)];
		[clip addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Helvetica-Oblique" size:13] range:NSMakeRange(15, 6)];
		[clip addAttribute:NSStrikethroughStyleAttributeName value:[NSNumber numberWithInt:NSUnderlineStyleSingle] range:NSMakeRange(26, 6)];
		[clip addAttribute:NSLinkAttributeName value:[NSURL URLWithString:@"https://example.com/"] range:NSMakeRange(37, 4)];
		NSData *rtf = [clip RTFFromRange:NSMakeRange(0, [clip length]) documentAttributes:@{NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType}];
		NSPasteboard *pboard = [NSPasteboard generalPasteboard];
		void (^putClip)(void) = ^{
			[pboard clearContents];
			[pboard setData:rtf forType:NSPasteboardTypeRTF];
			[pboard setString:[clip string] forType:NSPasteboardTypeString];
		};
		BOOL (^anyStyle)(void) = ^BOOL{
			__block BOOL styled = NO;
			[[textView textStorage] enumerateAttributesInRange:NSMakeRange(0, [[textView string] length]) options:0 usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
				NSFontTraitMask traits = [[NSFontManager sharedFontManager] traitsOfFont:[attrs objectForKey:NSFontAttributeName]];
				if ((traits & (NSBoldFontMask|NSItalicFontMask)) || [attrs objectForKey:NSStrikethroughStyleAttributeName]) { styled = YES; *stop = YES; }
			}];
			return styled;
		};
		BOOL preserves = [prefsController pastePreservesStyle];
		for (int setting = 0; setting < 2; setting++) {
			[prefsController setPastePreservesStyle:setting sender:self];
			[textView setSelectedRange:NSMakeRange(0, [[textView string] length])];
			[textView insertText:@""];
			putClip();
			[textView paste:nil];
			SelfTestLog(@"paste: plain text note, \"Copy basic styles\" %@: ⌘V -> \"%@\" styled=%d", setting ? @"on" : @"off", [textView string], anyStyle());
		}
		[prefsController setPastePreservesStyle:NO sender:self];
		[textView setSelectedRange:NSMakeRange(0, [[textView string] length])];
		[textView insertText:@""];
		putClip();
		[textView pasteWithStyles:nil];
		SelfTestLog(@"paste: plain text note, Paste with Styles -> \"%@\" styled=%d", [textView string], anyStyle());
		//the ⇧⌘V key in the note: Paste with Styles, not a new note
		[textView setSelectedRange:NSMakeRange(0, [[textView string] length])];
		[textView insertText:@""];
		putClip();
		NSInteger rowsBefore = [notesTableView numberOfRows];
		[self _selfTestPostKey:'V' keyCode:9 flags:NSEventModifierFlagCommand | NSEventModifierFlagShift];
		SelfTestLog(@"paste: ⇧⌘V in the note -> \"%@\", notes %ld -> %ld", [textView string], (long)rowsBefore, (long)[notesTableView numberOfRows]);
		//which ⇧⌘V menu item is active where
		NSMenuItem *styledItem = nil, *newNoteItem = nil;
		for (NSMenuItem *topItem in [[NSApp mainMenu] itemArray])
			for (NSMenuItem *item in [[topItem submenu] itemArray]) {
				if ([item action] == @selector(pasteWithStyles:)) styledItem = item;
				if ([item action] == @selector(paste:) && [item target] == notesTableView) newNoteItem = item;
			}
		[window makeFirstResponder:textView];
		BOOL newNoteInEditor = [notesTableView validateMenuItem:newNoteItem], styledInEditor = [textView validateMenuItem:styledItem];
		[window makeFirstResponder:notesTableView];
		BOOL newNoteInList = [notesTableView validateMenuItem:newNoteItem];
		[window makeFirstResponder:textView];
		SelfTestLog(@"paste: menu \"%@\" (%@%@) enabled in note=%d; \"%@\" (%@%@) enabled in note=%d, in list=%d", [styledItem title],
					([styledItem keyEquivalentModifierMask] & NSEventModifierFlagShift) || [[styledItem keyEquivalent] isEqualToString:@"V"] ? @"⇧⌘" : @"⌘",
					[[styledItem keyEquivalent] uppercaseString], styledInEditor, [newNoteItem title],
					[[newNoteItem keyEquivalent] isEqualToString:@"V"] ? @"⇧⌘" : @"⌘", [[newNoteItem keyEquivalent] uppercaseString], newNoteInEditor, newNoteInList);
		
		//a Rich Text note: ⌘V follows "Copy basic styles"; Paste with Styles keeps them either way
		NSAttributedString *rtfBody = [[[NSAttributedString alloc] initWithString:@"" attributes:[prefsController noteBodyAttributes]] autorelease];
		NoteObject *rtfNote = [[[NoteObject alloc] initWithNoteBody:rtfBody title:@"Rich Text paste test" delegate:notationController format:RTFTextFormat labels:nil] autorelease];
		[notationController addNewNote:rtfNote];
		[self searchForString:@""];
		SelfTestSpin(0.3);
		[notesTableView selectRowAndScroll:[self _selfTestRowOfNote:rtfNote]];
		SelfTestSpin(0.3);
		[window makeFirstResponder:textView];
		for (int setting = 0; setting < 3; setting++) {
			[prefsController setPastePreservesStyle:setting == 1 sender:self];
			[textView setSelectedRange:NSMakeRange(0, [[textView string] length])];
			[textView insertText:@""];
			putClip();
			if (setting < 2) [textView paste:nil]; else [textView pasteWithStyles:nil];
			SelfTestLog(@"paste: Rich Text note (format %ld), %@ -> \"%@\" styled=%d", (long)storageFormatOfNote(rtfNote),
						setting == 0 ? @"⌘V with Copy basic styles off" : setting == 1 ? @"⌘V with it on" : @"Paste with Styles with it off",
						[textView string], anyStyle());
		}
		[prefsController setPastePreservesStyle:preserves sender:self];
		[notationController removeNote:rtfNote];
		SelfTestSpin(0.3);
		[notesTableView selectRowAndScroll:[self _selfTestRowOfNote:note]];
		SelfTestSpin(0.3);
		[window makeFirstResponder:textView];
	}
	
	//the Markdown checks below need it on, as ⇧⌘M would set it
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"UsesMarkdownCompletions"];
	{
		NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:@"bold" action:@selector(bold:) keyEquivalent:@""] autorelease];
		SelfTestLog(@"styles: Markdown completion on: bold: %@", [textView validateMenuItem:item] ? @"enabled" : @"disabled");
	}
	
	//each case: what's typed (Return as ⏎), then the note's text
	NSArray *cases = [NSArray arrayWithObjects:@"- one⏎⏎after", @"* one⏎⏎after", @"1. one⏎⏎after", @"2) one⏎⏎after", @"  - indented⏎⏎after",
					  @"- one⏎two⏎⏎after", @"---⏎after", @"1.⏎after", @"- ⏎after", nil];
	for (NSString *typed in cases) {
		[textView setSelectedRange:NSMakeRange(0, [[textView string] length])];
		[textView insertText:@""];
		NSArray *pieces = [typed componentsSeparatedByString:@"⏎"];
		for (NSUInteger i = 0; i < [pieces count]; i++) {
			if (i > 0) [textView insertNewline:nil];
			if ([[pieces objectAtIndex:i] length]) [textView insertText:[pieces objectAtIndex:i]];
		}
		SelfTestLog(@"lists: typed \"%@\" -> \"%@\"", typed, SelfTestVisibleNewlines([textView string]));
	}
	//undo takes the ended list back
	[textView setSelectedRange:NSMakeRange(0, [[textView string] length])];
	[textView insertText:@"- one"];
	[textView insertNewline:nil];
	NSString *continued = [[[textView string] copy] autorelease];
	[textView insertNewline:nil];
	NSString *ended = [[[textView string] copy] autorelease];
	[[textView undoManager] undo];
	SelfTestLog(@"lists: \"%@\" then Return -> \"%@\", undo -> \"%@\"", SelfTestVisibleNewlines(continued), SelfTestVisibleNewlines(ended),
				SelfTestVisibleNewlines([textView string]));
	
	//⌘B, ⌘I, ⌘Y on a selected word
	for (NSString *action in [NSArray arrayWithObjects:@"bold:", @"italic:", @"strikethroughNV:", nil]) {
		[textView setSelectedRange:NSMakeRange(0, [[textView string] length])];
		[textView insertText:@"a word here"];
		[textView setSelectedRange:NSMakeRange(2, 4)];
		[NSApp sendAction:NSSelectorFromString(action) to:textView from:nil];
		SelfTestLog(@"markdown: %@ on \"word\" -> \"%@\"", action, [textView string]);
	}
	
	//Tab and Shift-Tab make Markdown links after [text], but leave [[wiki links]] alone
	struct { NSString *text; NSUInteger cursor; BOOL backtab; } linkCases[] = {
		{@"see [nv27]", 10, NO}, {@"see [nv27]", 10, YES}, {@"see [[Note]]", 12, NO}, {@"see [[Note]]", 12, YES}, {@"see [[Note]] ", 13, NO},
		{@"see [[Note]]", 9, NO}, {@"see [[Note]]", 9, YES}, {@"[1]", 3, NO}};
	for (size_t i = 0; i < sizeof(linkCases) / sizeof(linkCases[0]); i++) {
		[window makeFirstResponder:textView];
		[textView setSelectedRange:NSMakeRange(0, [[textView string] length])];
		[textView insertText:linkCases[i].text];
		[textView setSelectedRange:NSMakeRange(linkCases[i].cursor, 0)];
		if (linkCases[i].backtab) [textView insertBacktab:nil]; else [textView insertTab:nil];
		SelfTestLog(@"markdown links: \"%@\" with the cursor at %lu, %@ -> \"%@\" (selected \"%@\")", linkCases[i].text, (unsigned long)linkCases[i].cursor,
					linkCases[i].backtab ? @"Shift-Tab" : @"Tab", [textView string],
					[[textView string] substringWithRange:[textView selectedRange]]);
	}
	[window makeFirstResponder:textView];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"UsesMarkdownCompletions"];
	[notationController synchronizeNoteChanges:nil];
	SelfTestSpin(0.3);
	[notationController removeNote:note];
	SelfTestSpin(0.3);
	selfTestStage = "";
}

//the part of the Keyboard Shortcuts window around a given string, scrolled to the top of the window
- (void)_selfTestSnapshotShortcutsText:(NSTextView*)shortcutsText containing:(NSString*)needle tag:(NSString*)tag {
	NSRange found = [[shortcutsText string] rangeOfString:needle];
	SelfTestLog(@"keyboard shortcuts: \"%@\" found=%d", needle, found.location != NSNotFound);
	if (found.location == NSNotFound) return;
	NSRect glyphRect = [[shortcutsText layoutManager] boundingRectForGlyphRange:
						[[shortcutsText layoutManager] glyphRangeForCharacterRange:found actualCharacterRange:NULL] inTextContainer:[shortcutsText textContainer]];
	[shortcutsText scrollPoint:NSMakePoint(0, MAX((CGFloat)0, NSMinY(glyphRect) - 120))];
	[[shortcutsText window] display];
	PrintSnapshotOfWindow([shortcutsText window], tag);
	[shortcutsText scrollRangeToVisible:NSMakeRange(0, 0)];
}

//checks for bugs fixed in Notational Velocity 2.5.1 and for the reports in its issue tracker that nv27 might share;
//a watchdog reports a hang (rather than CI just timing out) and says which check it was in
static const char * volatile selfTestStage = "";

static void SelfTestSpin(NSTimeInterval seconds) {
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

- (NSInteger)_selfTestRowOfNote:(NoteObject*)note {
	for (NSInteger i = 0; i < [notesTableView numberOfRows]; i++)
		if ([notationController noteObjectAtFilteredIndex:i] == note) return i;
	return -1;
}

- (NSArray*)_selfTestTemporaryFilesInNotesFolder {
	NSRegularExpression *tempName = [NSRegularExpression regularExpressionWithPattern:@"^(\\.[0-9]+-[0-9]+-[0-9]+|4A696D[0-9A-F]{2})$" options:0 error:NULL];
	NSMutableArray *names = [NSMutableArray array];
	for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[notationController noteDirectoryPath] error:NULL])
		if ([tempName numberOfMatchesInString:name options:0 range:NSMakeRange(0, [name length])]) [names addObject:name];
	return names;
}

- (void)_selfTestUpstreamFixes {
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 90 * NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
		fprintf(stdout, "SELFTEST upstream: HANG (still running after 90 s) in \"%s\"\n", selfTestStage);
		fflush(stdout);
		exit(3);
	});
	[window makeKeyAndOrderFront:nil];
	[self searchForString:@""];
	SelfTestSpin(0.5);
	NSString *folder = [notationController noteDirectoryPath];
	SelfTestLog(@"upstream: notes folder %@, %ld notes", [folder stringByAbbreviatingWithTildeInPath], (long)[notesTableView numberOfRows]);
	
	//Find & Replace can shorten the text after the edited range was worked out (NV 2.5.1 "fix find-replace crash")
	selfTestStage = "edited range past the end of the text";
	@try {
		NSTextStorage *storage = [[[NSTextStorage alloc] initWithString:@"see http://example.com now"] autorelease];
		[storage addLinkAttributesForRange:NSMakeRange(20, 50)];
		[storage addLinkAttributesForRange:NSMakeRange(60, 5)];
		NSUInteger length = [[textView string] length];
		[textView setValue:[NSValue valueWithRange:NSMakeRange(length + 5, 3)] forKey:@"changedRange"];
		[textView didChangeText];
		[textView setValue:[NSValue valueWithRange:NSMakeRange(length > 2 ? length - 2 : 0, 40)] forKey:@"changedRange"];
		[textView didChangeText];
		SelfTestLog(@"upstream: links and editor with an edited range past the end of the text: no exception");
	} @catch (NSException *exception) {
		SelfTestLog(@"upstream: links and editor with an edited range past the end of the text: EXCEPTION %@: %@", [exception name], [exception reason]);
	}
	
	//NV issue 354: NV hung editing titles after a note was titled "/"; what nv27 makes of awkward titles
	selfTestStage = "filenames for awkward titles";
	for (NSString *title in [NSArray arrayWithObjects:@"/", @"a/b", @"/x", @"x/", @":", @".hidden", @"", nil]) {
		@try {
			SelfTestLog(@"upstream: filename for title \"%@\" = \"%@\"", title, [notationController uniqueFilenameForTitle:title fromNote:nil]);
		} @catch (NSException *exception) {
			SelfTestLog(@"upstream: filename for title \"%@\": EXCEPTION %@: %@", title, [exception name], [exception reason]);
		}
	}
	selfTestStage = "notes titled \"/\"";
	@try {
		NSMutableArray *slashNotes = [NSMutableArray array];
		for (int i = 0; i < 2; i++) {
			NSAttributedString *body = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"slash note %d", i]
																		attributes:[prefsController noteBodyAttributes]] autorelease];
			NoteObject *note = [[[NoteObject alloc] initWithNoteBody:body title:@"/" delegate:notationController
															  format:[notationController currentNoteStorageFormat] labels:nil] autorelease];
			[notationController addNewNote:note];
			[slashNotes addObject:note];
		}
		[notationController synchronizeNoteChanges:nil];
		SelfTestSpin(1.0);
		for (NoteObject *note in slashNotes) {
			NSString *path = [folder stringByAppendingPathComponent:filenameOfNote(note)];
			SelfTestLog(@"upstream: note titled \"%@\" saved as \"%@\" (on disk: %d, contents \"%@\")", titleOfNote(note), filenameOfNote(note),
						[[NSFileManager defaultManager] fileExistsAtPath:path],
						[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL]);
		}
		//then rename another note, which is where NV hung
		selfTestStage = "renaming a note after notes titled \"/\"";
		NoteObject *other = [notationController noteObjectAtFilteredIndex:0];
		NSString *oldTitle = [[titleOfNote(other) copy] autorelease];
		[other setTitleString:@"Renamed after slash"];
		[notationController synchronizeNoteChanges:nil];
		SelfTestSpin(0.5);
		SelfTestLog(@"upstream: renamed \"%@\" to \"%@\", file \"%@\" (on disk: %d)", oldTitle, titleOfNote(other), filenameOfNote(other),
					[[NSFileManager defaultManager] fileExistsAtPath:[folder stringByAppendingPathComponent:filenameOfNote(other)]]);
		[other setTitleString:oldTitle];
		[notationController synchronizeNoteChanges:nil];
		for (NoteObject *note in slashNotes) [notationController removeNote:note];
		SelfTestSpin(0.5);
	} @catch (NSException *exception) {
		SelfTestLog(@"upstream: notes titled \"/\": EXCEPTION %@: %@", [exception name], [exception reason]);
	}
	
	//saving swaps the new file in whole; nothing is left behind under a temporary name
	selfTestStage = "saving a note";
	{
		NoteObject *note = [notationController noteObjectAtFilteredIndex:0];
		NSString *path = [folder stringByAppendingPathComponent:filenameOfNote(note)];
		NSString *original = [[[note contentString] string] copy];
		NSAttributedString *edited = [[[NSAttributedString alloc] initWithString:[original stringByAppendingString:@"\nsaved by the self-test"]
																	  attributes:[prefsController noteBodyAttributes]] autorelease];
		[note setContentString:edited];
		[notationController synchronizeNoteChanges:nil];
		SelfTestSpin(0.5);
		NSString *onDisk = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
		SelfTestLog(@"upstream: saved \"%@\": file has the new text=%d; temporary files left in the notes folder: %@", titleOfNote(note),
					[onDisk hasSuffix:@"saved by the self-test"], [self _selfTestTemporaryFilesInNotesFolder]);
		[note setContentString:[[[NSAttributedString alloc] initWithString:original attributes:[prefsController noteBodyAttributes]] autorelease]];
		[notationController synchronizeNoteChanges:nil];
		[original release];
	}
	
	//saves swap the new file in with one rename where the volume allows it (the old four-rename way is the fallback)
	{
		NSString *a = [folder stringByAppendingPathComponent:@".selftest-swap-a"], *b = [folder stringByAppendingPathComponent:@".selftest-swap-b"];
		[@"a" writeToFile:a atomically:NO encoding:NSUTF8StringEncoding error:NULL];
		[@"b" writeToFile:b atomically:NO encoding:NSUTF8StringEncoding error:NULL];
		BOOL swapped = renamex_np([a fileSystemRepresentation], [b fileSystemRepresentation], RENAME_SWAP) == 0;
		SelfTestLog(@"upstream: notes folder's volume swaps files in one step=%d (%s), contents now a=\"%@\" b=\"%@\"", swapped, swapped ? "ok" : strerror(errno),
					[NSString stringWithContentsOfFile:a encoding:NSUTF8StringEncoding error:NULL], [NSString stringWithContentsOfFile:b encoding:NSUTF8StringEncoding error:NULL]);
		[[NSFileManager defaultManager] removeItemAtPath:a error:NULL];
		[[NSFileManager defaultManager] removeItemAtPath:b error:NULL];
	}
	
	//leftover temporary files from an earlier run go to the Trash, but not one that might be another copy's save in progress
	selfTestStage = "leftover temporary files";
	{
		NSString *stale = [folder stringByAppendingPathComponent:@".123456-1700000000-1"];
		NSString *fresh = [folder stringByAppendingPathComponent:@".123456-1700000000-2"];
		[@"stale" writeToFile:stale atomically:NO encoding:NSUTF8StringEncoding error:NULL];
		[@"fresh" writeToFile:fresh atomically:NO encoding:NSUTF8StringEncoding error:NULL];
		[[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObject:[NSDate dateWithTimeIntervalSinceNow:-7200]
																				  forKey:NSFileModificationDate] ofItemAtPath:stale error:NULL];
		NSUInteger trashed = [notationController trashStaleTemporaryFiles];
		SelfTestLog(@"upstream: leftover temporary files: moved %lu to the Trash; 2-hour-old one still there=%d, new one still there=%d", (unsigned long)trashed,
					[[NSFileManager defaultManager] fileExistsAtPath:stale], [[NSFileManager defaultManager] fileExistsAtPath:fresh]);
		[[NSFileManager defaultManager] removeItemAtPath:fresh error:NULL];
	}
	
	//a file moved out of the folder and back under another name (by another app, so FSEvents reports it, in two scans)
	//is the same note, not a deletion and a new note
	selfTestStage = "file renamed across two folder scans";
	{
		BOOL confirmed = [[notationController notationPrefs] confirmFileDeletion];
		[[notationController notationPrefs] setConfirmsFileDeletion:NO];
		NoteObject *note = [[notationController noteObjectAtFilteredIndex:0] retain];
		NSString *oldName = [[filenameOfNote(note) copy] autorelease];
		NSString *outside = [NSTemporaryDirectory() stringByAppendingPathComponent:oldName];
		NSString *newName = [@"Moved back " stringByAppendingString:oldName];
		[[NSFileManager defaultManager] removeItemAtPath:outside error:NULL];
		[[NSTask launchedTaskWithLaunchPath:@"/bin/mv" arguments:[NSArray arrayWithObjects:[folder stringByAppendingPathComponent:oldName], outside, nil]] waitUntilExit];
		SelfTestSpin(1.6);
		NSInteger rowWhileGone = [self _selfTestRowOfNote:note];
		[[NSTask launchedTaskWithLaunchPath:@"/bin/mv" arguments:[NSArray arrayWithObjects:outside, [folder stringByAppendingPathComponent:newName], nil]] waitUntilExit];
		SelfTestSpin(4.0);
		SelfTestLog(@"upstream: file moved out and back as \"%@\": same note still listed=%d (listed while gone=%d), its file now \"%@\", notes listed with that file=%ld",
					newName, [self _selfTestRowOfNote:note] >= 0, rowWhileGone >= 0, filenameOfNote(note),
					(long)[[[notationController valueForKey:@"allNotes"] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *b) {
						return [filenameOfNote(obj) isEqualToString:newName]; }]] count]);
		[note release];
		[[notationController notationPrefs] setConfirmsFileDeletion:confirmed];
	}
	
	//NV issue 218: ⌘⌫ while renaming a note deleted it and gave its title to the next note
	selfTestStage = "command-delete while renaming";
	{
		BOOL confirmed = [prefsController confirmNoteDeletion];
		[prefsController setConfirmNoteDeletion:NO sender:self];
		NSInteger rowsBefore = [notesTableView numberOfRows];
		NoteObject *first = [notationController noteObjectAtFilteredIndex:0], *second = [notationController noteObjectAtFilteredIndex:1];
		NSString *firstTitle = [[titleOfNote(first) copy] autorelease], *secondTitle = [[titleOfNote(second) copy] autorelease];
		[notesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
		[self renameNote:nil];
		SelfTestSpin(0.5);
		BOOL wasEditing = [notesTableView currentEditor] != nil;
		NSEvent *commandDelete = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagCommand
												 timestamp:[[NSProcessInfo processInfo] systemUptime] windowNumber:[window windowNumber] context:nil
												characters:@"\x7f" charactersIgnoringModifiers:@"\x7f" isARepeat:NO keyCode:51];
		[NSApp sendEvent:commandDelete];
		SelfTestSpin(0.5);
		BOOL stillEditing = [notesTableView currentEditor] != nil;
		NSString *editorText = stillEditing ? [[[(NSTextView*)[notesTableView currentEditor] string] copy] autorelease] : nil;
		[window makeFirstResponder:notesTableView];
		SelfTestSpin(0.5);
		SelfTestLog(@"upstream: command-delete while renaming \"%@\" (editing=%d): rows %ld -> %ld, that note listed=%d, still editing=%d (title being edited \"%@\"), next note \"%@\" now titled \"%@\"",
					firstTitle, wasEditing, (long)rowsBefore, (long)[notesTableView numberOfRows], [self _selfTestRowOfNote:first] >= 0, stillEditing,
					editorText, secondTitle, titleOfNote(second));
		[prefsController setConfirmNoteDeletion:confirmed sender:self];
	}
	
	//a second ⌘⌫ while the delete confirmation is showing mustn't queue another confirmation
	selfTestStage = "delete confirmation twice";
	{
		BOOL confirmed = [prefsController confirmNoteDeletion];
		[prefsController setConfirmNoteDeletion:YES sender:self];
		[notesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
		NSInteger rowsBefore = [notesTableView numberOfRows];
		[self deleteNote:nil];
		SelfTestSpin(0.5);
		NSWindow *firstSheet = [window attachedSheet];
		[self deleteNote:nil];
		SelfTestSpin(0.5);
		if (firstSheet) [window endSheet:firstSheet returnCode:NSAlertSecondButtonReturn];
		SelfTestSpin(1.0);
		NSWindow *nextSheet = [window attachedSheet];
		SelfTestLog(@"upstream: delete twice with confirmation: first confirmation shown=%d, another shown after cancelling=%d, rows %ld -> %ld",
					firstSheet != nil, nextSheet != nil, (long)rowsBefore, (long)[notesTableView numberOfRows]);
		if (nextSheet) [window endSheet:nextSheet returnCode:NSAlertSecondButtonReturn];
		[prefsController setConfirmNoteDeletion:confirmed sender:self];
	}
	
	//the tag panel for several notes, closed with its close button
	selfTestStage = "tag panel closed with its close button";
	{
		[notesTableView selectRowIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, MIN((NSInteger)2, [notesTableView numberOfRows]))] byExtendingSelection:NO];
		[self tagNote:nil];
		SelfTestSpin(0.5);
		NSWindow *tagPanel = nil;
		for (NSWindow *aWindow in [NSApp windows])
			if ([aWindow isVisible] && [aWindow isKindOfClass:[NSPanel class]] && [[aWindow title] length] && [[tagEditor tagField] window] == aWindow) tagPanel = aWindow;
		SelfTestLog(@"upstream: tag panel shown=%d", tagPanel != nil);
		[tagPanel performClose:nil];
		SelfTestSpin(1.0);
		[window makeKeyAndOrderFront:nil];
		SelfTestSpin(0.5);
		//open and close it once more, now that the first one is gone
		[self tagNote:nil];
		SelfTestSpin(0.5);
		[[[tagEditor tagField] window] performClose:nil];
		SelfTestSpin(1.0);
		SelfTestLog(@"upstream: tag panel closed with its close button twice: no crash");
	}
	selfTestStage = "";
}

//Home/End and Page Up/Page Down in the notes list move through the list (they used to go to the search field)
- (void)_selfTestListKeys {
	selfTestStage = "Home, End, Page Up, Page Down in the notes list";
	NSMutableArray *added = [NSMutableArray array];
	for (int i = 0; i < 30; i++) {
		NSAttributedString *body = [[[NSAttributedString alloc] initWithString:@"paging" attributes:[prefsController noteBodyAttributes]] autorelease];
		NoteObject *note = [[[NoteObject alloc] initWithNoteBody:body title:[NSString stringWithFormat:@"Paging test %02d", i] delegate:notationController
														  format:[notationController currentNoteStorageFormat] labels:nil] autorelease];
		[notationController addNewNote:note];
		[added addObject:note];
	}
	[self searchForString:@""];
	SelfTestSpin(0.5);
	[window makeKeyAndOrderFront:nil];
	[notesTableView selectRowAndScroll:3];
	[window makeFirstResponder:notesTableView];
	SelfTestSpin(0.3);
	NSString *searchBefore = [[[field stringValue] copy] autorelease];
	CGFloat stride = [notesTableView rowHeight] + [notesTableView intercellSpacing].height;
	SelfTestLog(@"list keys: %ld notes, about %.0f rows fit in the list, selected row 3", (long)[notesTableView numberOfRows],
				NSHeight([notesTableView visibleRect]) / stride);
	
	struct { unichar key; unsigned short keyCode; const char *name; } keys[] = {
		{NSPageDownFunctionKey, 121, "Page Down"}, {NSPageDownFunctionKey, 121, "Page Down"}, {NSPageUpFunctionKey, 116, "Page Up"},
		{NSEndFunctionKey, 119, "End"}, {NSPageDownFunctionKey, 121, "Page Down"}, {NSPageUpFunctionKey, 116, "Page Up"},
		{NSHomeFunctionKey, 115, "Home"}, {NSPageUpFunctionKey, 116, "Page Up"}};
	for (size_t i = 0; i < sizeof(keys) / sizeof(keys[0]); i++) {
		NSString *chars = [NSString stringWithCharacters:&keys[i].key length:1];
		NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagFunction
										 timestamp:[[NSProcessInfo processInfo] systemUptime] windowNumber:[window windowNumber] context:nil
										characters:chars charactersIgnoringModifiers:chars isARepeat:NO keyCode:keys[i].keyCode];
		[NSApp sendEvent:event];
		SelfTestSpin(0.3);
		NSRange visibleRows = [notesTableView rowsInRect:[notesTableView visibleRect]];
		SelfTestLog(@"list keys: %s -> selected row %ld (rows %lu-%lu showing), focus in list=%d, search field unchanged=%d", keys[i].name,
					(long)[notesTableView selectedRow], (unsigned long)visibleRows.location, (unsigned long)NSMaxRange(visibleRows) - 1,
					[window firstResponder] == notesTableView, [[field stringValue] isEqualToString:searchBefore]);
	}
	//a page is however many rows show when the key is pressed: give the list more room and page again
	NSEvent *pageDown = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagFunction
										timestamp:[[NSProcessInfo processInfo] systemUptime] windowNumber:[window windowNumber] context:nil
									   characters:[NSString stringWithFormat:@"%C", (unichar)NSPageDownFunctionKey]
					  charactersIgnoringModifiers:[NSString stringWithFormat:@"%C", (unichar)NSPageDownFunctionKey] isARepeat:NO keyCode:121];
	CGFloat originalDimension = [notesSubview dimension];
	for (int taller = 0; taller < 2; taller++) {
		if (taller) {
			//drag the divider down: the list gets the note editor's room
			[notesSubview setDimension:originalDimension + 150];
			[splitView adjustSubviews];
			[window display];
			SelfTestSpin(0.5);
		}
		[notesTableView selectRowAndScroll:0];
		SelfTestSpin(0.2);
		CGFloat listHeight = NSHeight([notesTableView visibleRect]);
		[NSApp sendEvent:pageDown];
		SelfTestSpin(0.3);
		SelfTestLog(@"list keys: list %.0f pt tall (about %.0f rows): Page Down from row 0 -> row %ld", listHeight, listHeight / stride,
					(long)[notesTableView selectedRow]);
	}
	[notesSubview setDimension:originalDimension];
	[splitView adjustSubviews];
	SelfTestSpin(0.3);
	
	[notesTableView selectRowAndScroll:[notesTableView numberOfRows] / 2];
	[window display];
	PrintSnapshotOfWindow(window, @"list-paging");
	
	for (NoteObject *note in added) [notationController removeNote:note];
	SelfTestSpin(0.5);
	selfTestStage = "";
}

@end

#endif
