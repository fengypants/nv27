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
	[self performSelector:@selector(_selfTestClicks) withObject:nil afterDelay:1.0];
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
	[self _selfTestClickAtWindowPoint:center label:@"editor center, from notes list"];
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
	
	[window makeKeyAndOrderFront:nil];
	[self togglePreview:nil];
	[self performSelector:@selector(_selfTestSnapshotPreview) withObject:nil afterDelay:2.0];
}

- (void)_selfTestSnapshotPreview {
	for (NSWindow *aWindow in [NSApp windows]) {
		if (aWindow != window && [aWindow isVisible] && ![aWindow toolbar] && NSWidth([aWindow frame]) > 200)
			PrintSnapshotOfWindow(aWindow, @"preview");
	}
	SelfTestLog(@"done");
	exit(0);
}

@end

#endif
