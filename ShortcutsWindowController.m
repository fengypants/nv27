//
//  ShortcutsWindowController.m
//  Notation
//
//  Help › Keyboard Shortcuts: shows the shortcuts listed in KeyboardShortcuts.md in a window of its own.
//  The file's few formatting rules are described at its top; this turns them into text in standard
//  system fonts and colors (so it follows Light and Dark Mode), with each run of rows as a two-column table.
//

#import "ShortcutsWindowController.h"

@implementation ShortcutsWindowController

static ShortcutsWindowController *sharedController = nil;

+ (ShortcutsWindowController*)sharedController {
	if (!sharedController)
		sharedController = [[ShortcutsWindowController alloc] init];
	return sharedController;
}

- (id)init {
	NSWindow *aWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 540, 640)
													styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
															  NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
													  backing:NSBackingStoreBuffered defer:YES];
	if ((self = [super initWithWindow:aWindow])) {
		[aWindow setTitle:NSLocalizedString(@"Keyboard Shortcuts", @"title of the keyboard shortcuts window")];
		[aWindow setReleasedWhenClosed:NO];
		[aWindow setContentMinSize:NSMakeSize(420, 300)];
		[aWindow center];
		[aWindow setFrameAutosaveName:@"KeyboardShortcuts"];

		NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:[[aWindow contentView] bounds]];
		[scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[scrollView setHasVerticalScroller:YES];
		[scrollView setBorderType:NSNoBorder];

		NSSize contentSize = [scrollView contentSize];
		textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, contentSize.width, contentSize.height)];
		[textView setAutoresizingMask:NSViewWidthSizable];
		[textView setVerticallyResizable:YES];
		[textView setHorizontallyResizable:NO];
		[[textView textContainer] setWidthTracksTextView:YES];
		[textView setTextContainerInset:NSMakeSize(20, 18)];
		[textView setEditable:NO];
		[textView setSelectable:YES];
		[textView setUsesFindBar:YES];
		[textView setDrawsBackground:YES];
		[textView setBackgroundColor:[NSColor textBackgroundColor]];
		[[textView textStorage] setAttributedString:[self shortcutsTextForLocalization:nil]];

		[scrollView setDocumentView:textView];
		[aWindow setContentView:scrollView];
		[scrollView release];
	}
	[aWindow release];
	return self;
}

- (void)dealloc {
	[textView release];
	[super dealloc];
}

static NSParagraphStyle *ParagraphStyle(CGFloat spacingBefore, CGFloat spacingAfter, NSArray *textBlocks) {
	NSMutableParagraphStyle *style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[style setParagraphSpacingBefore:spacingBefore];
	[style setParagraphSpacing:spacingAfter];
	if (textBlocks) [style setTextBlocks:textBlocks];
	return style;
}

//a line of text in the given font and color, with **bold** spans in the font's bold weight
static NSAttributedString *StyledLine(NSString *line, NSFont *font, NSColor *color, NSParagraphStyle *style) {
	NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];
	NSFont *boldFont = [NSFont systemFontOfSize:[font pointSize] weight:NSFontWeightSemibold];
	NSArray *parts = [line componentsSeparatedByString:@"**"];
	for (NSUInteger i = 0; i < [parts count]; i++) {
		NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:(i % 2) ? boldFont : font, NSFontAttributeName,
							   color, NSForegroundColorAttributeName, style, NSParagraphStyleAttributeName, nil];
		[result appendAttributedString:[[[NSAttributedString alloc] initWithString:[parts objectAtIndex:i] attributes:attrs] autorelease]];
	}
	[result appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n"
																	attributes:[NSDictionary dictionaryWithObject:style forKey:NSParagraphStyleAttributeName]] autorelease]];
	return result;
}

//one cell of a two-column table row: padded, with a hairline under it like a standard table's row separators
static NSTextTableBlock *CellBlock(NSTextTable *table, NSInteger row, NSInteger column, CGFloat keysWidth) {
	NSTextTableBlock *block = [[[NSTextTableBlock alloc] initWithTable:table startingRow:row rowSpan:1 startingColumn:column columnSpan:1] autorelease];
	[block setWidth:5.0 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMinYEdge];
	[block setWidth:5.0 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMaxYEdge];
	[block setWidth:column ? 8.0 : 0.0 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMinXEdge];
	[block setWidth:1.0 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockBorder edge:NSMaxYEdge];
	[block setBorderColor:[NSColor separatorColor] forEdge:NSMaxYEdge];
	if (!column) [block setValue:keysWidth type:NSTextBlockAbsoluteValueType forDimension:NSTextBlockWidth];
	return block;
}

#if DEBUG
//lets the UI self-test show each language's list, whatever the system language
- (void)_selfTestShowLocalization:(NSString*)localization {
	[[textView textStorage] setAttributedString:[self shortcutsTextForLocalization:localization]];
}
#endif

//the list in the user's language (one of the app's localizations), or in the given one
- (NSAttributedString*)shortcutsTextForLocalization:(NSString*)localization {
	NSString *path = localization ? [[NSBundle mainBundle] pathForResource:@"KeyboardShortcuts" ofType:@"md" inDirectory:nil forLocalization:localization] :
									[[NSBundle mainBundle] pathForResource:@"KeyboardShortcuts" ofType:@"md"];
	NSString *source = path ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL] : nil;
	NSMutableAttributedString *text = [[[NSMutableAttributedString alloc] init] autorelease];
	if (!source) return text;

	NSFont *bodyFont = [NSFont systemFontOfSize:13.0];
	NSFont *headingFont = [NSFont systemFontOfSize:15.0 weight:NSFontWeightSemibold];
	NSFont *noteFont = [NSFont systemFontOfSize:12.0];

	NSArray *lines = [source componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

	//the keys column fits its widest entry (key names are longer in some languages, e.g. "Zeilenschalter")
	CGFloat keysWidth = 90.0;
	for (NSString *line in lines) {
		NSArray *cells = [line componentsSeparatedByString:@"|"];
		if ([line hasPrefix:@"|"] && [cells count] > 2) {
			NSString *keys = [[cells objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			keysWidth = MAX(keysWidth, [keys sizeWithAttributes:[NSDictionary dictionaryWithObject:bodyFont forKey:NSFontAttributeName]].width + 24.0);
		}
	}
	keysWidth = ceil(MIN(keysWidth, 200.0));

	NSTextTable *table = nil;
	NSInteger row = 0;
	BOOL inComment = NO, first = YES;

	for (NSString *line in lines) {
		NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		if (inComment || [trimmed hasPrefix:@"<!--"]) {
			inComment = [trimmed rangeOfString:@"-->"].location == NSNotFound;
			continue;
		}
		BOOL isRow = [trimmed hasPrefix:@"|"];
		if (!isRow) table = nil;
		if (![trimmed length]) continue;

		if ([trimmed hasPrefix:@"## "]) {
			[text appendAttributedString:StyledLine([trimmed substringFromIndex:3], headingFont, [NSColor labelColor],
													ParagraphStyle(first ? 0.0 : 18.0, 6.0, nil))];
		} else if (isRow) {
			NSMutableArray *cells = [NSMutableArray array];
			for (NSString *cell in [trimmed componentsSeparatedByString:@"|"]) {
				NSString *cellText = [cell stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
				if ([cellText length]) [cells addObject:cellText];
			}
			if ([cells count] < 2) continue;
			if (!table) {
				table = [[[NSTextTable alloc] init] autorelease];
				[table setNumberOfColumns:2];
				[table setLayoutAlgorithm:NSTextTableAutomaticLayoutAlgorithm];
				[table setValue:100.0 type:NSTextBlockPercentageValueType forDimension:NSTextBlockWidth];
				row = 0;
			}
			for (NSInteger column = 0; column < 2; column++) {
				NSParagraphStyle *style = ParagraphStyle(0.0, 0.0, [NSArray arrayWithObject:CellBlock(table, row, column, keysWidth)]);
				[text appendAttributedString:StyledLine([cells objectAtIndex:column], bodyFont, [NSColor labelColor], style)];
			}
			row++;
		} else if ([trimmed hasPrefix:@"> "]) {
			[text appendAttributedString:StyledLine([trimmed substringFromIndex:2], noteFont, [NSColor secondaryLabelColor],
													ParagraphStyle(8.0, 0.0, nil))];
		} else {
			[text appendAttributedString:StyledLine(trimmed, bodyFont, [NSColor labelColor], ParagraphStyle(0.0, 6.0, nil))];
		}
		first = NO;
	}
	return text;
}

@end
