//
//  ShortcutsWindowController.h
//  Notation
//
//  Help › Keyboard Shortcuts: shows the shortcuts listed in KeyboardShortcuts.md in a window of its own.
//

#import <Cocoa/Cocoa.h>

@interface ShortcutsWindowController : NSWindowController {
	NSTextView *textView;
}

+ (ShortcutsWindowController*)sharedController;

@end
