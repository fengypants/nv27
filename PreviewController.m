//
//  PreviewController.m
//  Notation
//
//  Created by Christian Tietze on 15.10.10.
//  Copyright 2010

#import "PreviewController.h"
#import "AppController.h" // TODO for the defines only, can you get around that?
#import "AppController_Preview.h"
#import "NSString_MultiMarkdown.h"
#import "NSString_Markdown.h"
#import "NoteObject.h"
#import "NSFileManager_NV.h"
#import "NSFileManager+DirectoryLocations.h"

#define kDefaultMarkupPreviewVisible @"markupPreviewVisible"

@implementation PreviewController

@synthesize preview;
@synthesize isPreviewOutdated;
@synthesize isPreviewSticky;

+(void)initialize
{
    NSDictionary *appDefaults = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO]
                                                            forKey:kDefaultMarkupPreviewVisible];

    [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
    /* Initialize webInspector. */
    [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"WebKitDeveloperExtras"];
    [[NSUserDefaults standardUserDefaults] synchronize];

}

-(id)init
{
    if ((self = [super initWithWindowNibName:@"MarkupPreview" owner:self])) {
        self.isPreviewOutdated = YES;
        self.isPreviewSticky = NO;
        //        [[self class] createCustomFiles];
        BOOL showPreviewWindow = [[NSUserDefaults standardUserDefaults] boolForKey:kDefaultMarkupPreviewVisible];
        if (showPreviewWindow) {
            [[self window] orderFront:self];
        }

        [tabView selectTabViewItem:[tabView tabViewItemAtIndex:0]];
    }
    return self;
}

-(void)awakeFromNib
{
    cssString = [[[self class] css] retain];
    htmlString = [[[self class] html] retain];
    lastNote = [[NSApp delegate] selectedNoteObject];
    [sourceView setTextContainerInset:NSMakeSize(10.0,12.0)];
    NSScrollView *scrlView=[sourceView enclosingScrollView];
    [scrlView setScrollsDynamically:YES];
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_7
    if (IsLionOrLater) {
        [scrlView setHorizontalScrollElasticity:NSScrollElasticityNone];
        [scrlView setVerticalScrollElasticity:NSScrollElasticityAutomatic];
        [scrlView setScrollerStyle:NSScrollerStyleOverlay];
    }
#endif
}

//this returns a nice name for the method in the JavaScript environment
+(NSString*)webScriptNameForSelector:(SEL)sel
{
    if(sel == @selector(logJavaScriptString:))
        return @"log";
    return nil;
}

//this allows JavaScript to call the -logJavaScriptString: method
+ (BOOL)isSelectorExcludedFromWebScript:(SEL)sel
{
    if(sel == @selector(logJavaScriptString:))
        return NO;
    return YES;
}

//this is a simple log command
- (void)logJavaScriptString:(NSString*) logText
{
    NSLog(@"JavaScript: %@",logText);
}

//this is called as soon as the script environment is ready in the webview
- (void)webView:(WebView *)sender didClearWindowObject:(WebScriptObject *)windowScriptObject forFrame:(WebFrame *)frame
{
    //add the controller to the script environment
    //the "Cocoa" object will now be available to JavaScript
    [windowScriptObject setValue:self forKey:@"Cocoa"];
}

// Above webView methods from <http://stackoverflow.com/questions/2288582/embedded-webkit-script-callbacks-how/2293305#2293305>

- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener {
    NSString *targetURL = [[request URL] scheme];

    if (![[actionInformation objectForKey:@"WebActionNavigationTypeKey"] isEqualToNumber:[NSNumber numberWithInt:5]]) {
        [[NSWorkspace sharedWorkspace] openURL:[request URL]];
        [listener ignore];
    } else {
        [listener use];
    }
}

- (void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id<WebPolicyDecisionListener>)listener {
    NSLog(@"NEW WIN ACTION SENDER: %@",sender);
    [[NSWorkspace sharedWorkspace] openURL:[actionInformation objectForKey:WebActionOriginalURLKey]];
    [listener ignore];
}

-(void)requestPreviewUpdate:(NSNotification *)notification
{
    AppController *app = [notification object];
    NSString *rawString = [app noteContent];
    NSPasteboard* pb = [NSPasteboard pasteboardWithName:@"mkStreamingPreview"];
    [pb clearContents];
    [pb setString:rawString forType:(NSString*)kUTTypeUTF8PlainText];

    if (![[self window] isVisible]) {
        self.isPreviewOutdated = YES;
        return;
    }

    if (self.isPreviewSticky) {
        return;
    }


    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(preview:) object:app];

    [self performSelector:@selector(preview:) withObject:app afterDelay:0.05];
}

- (BOOL)previewIsVisible{
    return [[self window] isVisible];
}

-(void)togglePreview:(id)sender
{

    NSWindow *wnd = [self window];
    if ([wnd isVisible]) {
        //      // TODO: should the "stuck" note remain stuck when preview is closed?
        //      if (self.isPreviewSticky)
        //        [self makePreviewNotSticky:self];
        [wnd orderOut:self];
    } else {
        if (self.isPreviewOutdated) {
            // TODO high coupling; too many assumptions on architecture:
            [self performSelector:@selector(preview:) withObject:[[NSApplication sharedApplication] delegate] afterDelay:0.0];
        }
        [tabView selectTabViewItem:[tabView tabViewItemAtIndex:0]];
        [tabSwitcher setTitle:@"View Source"];

        [wnd orderFront:self];
    }

    // save visibility to defaults
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:[wnd isVisible]]
                                              forKey:kDefaultMarkupPreviewVisible];
}

-(void)windowWillClose:(NSNotification *)notification
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO]
                                              forKey:kDefaultMarkupPreviewVisible];
    NSMenu *previewMenu = [[[NSApp mainMenu] itemWithTitle:@"Preview"] submenu];
    [[previewMenu itemWithTitle:@"Toggle Preview Window"]setState:0];
}

+(NSString*)css {
    NSFileManager *mgr = [NSFileManager defaultManager];
    NSString *folder = [[NSFileManager defaultManager] applicationSupportDirectory];
    NSString *cssFileName = @"custom.css";
    NSString *customCSSPath = [folder stringByAppendingPathComponent: cssFileName];
    if ([mgr fileExistsAtPath:customCSSPath]) {
        return [NSString stringWithContentsOfFile:customCSSPath
                                         encoding:NSUTF8StringEncoding
                                            error:NULL];
    } else {
        NSString *cssPath = [[NSBundle mainBundle] pathForResource:@"custom" ofType:@"css" inDirectory:nil];
        return [NSString stringWithContentsOfFile:cssPath encoding:NSUTF8StringEncoding error:nil];
    }

    //	if (![mgr fileExistsAtPath:customCSSPath]) {
    //		[[self class] createCustomFiles];
    //	}


}

+(NSString*)html {
    NSFileManager *mgr = [NSFileManager defaultManager];

    NSString *folder = [[NSFileManager defaultManager] applicationSupportDirectory];
    NSString *htmlFileName = @"template.html";
    NSString *customHTMLPath = [folder stringByAppendingPathComponent: htmlFileName];
    if ([mgr fileExistsAtPath:customHTMLPath]) {
        return [NSString stringWithContentsOfFile:customHTMLPath
                                         encoding:NSUTF8StringEncoding
                                            error:NULL];
    } else {
        NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"template" ofType:@"html" inDirectory:nil];
        return [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
    }
    //	if (![mgr fileExistsAtPath:customHTMLPath]) {
    //		[[self class] createCustomFiles];
    //	}
}

-(void)preview:(id)object
{
    if (self.isPreviewSticky) {
        return;
    }
    NSString *lastScrollPosition = [preview stringByEvaluatingJavaScriptFromString:@"document.getElementsByTagName('body')[0].scrollTop"];
    //	NSString *lastScrollPosition = [[preview windowScriptObject] evaluateWebScript:@"document.getElementsByTagName('body')[0].scrollTop"];
    AppController *app = object;
    NSString *rawString = [app noteContent];

    SEL mode = [self markupProcessorSelector:[app currentPreviewMode]];
    NSString *processedString = [NSString performSelector:mode withObject:rawString];
    NSString *previewString = processedString;
    NSMutableString *outputString = [NSMutableString stringWithString:(NSString *)htmlString];
    NSString *noteTitle =  ([app selectedNoteObject]) ? [NSString stringWithFormat:@"%@",titleOfNote([app selectedNoteObject])] : @"";

    if (lastNote == [app selectedNoteObject]) {
        NSString *restoreScrollPosition = [NSString stringWithFormat:@"\n<script>var body = document.getElementsByTagName('body')[0],oldscroll = %@;body.scrollTop = oldscroll;</script>",lastScrollPosition];
        previewString = [processedString stringByAppendingString:restoreScrollPosition];
    } else {
        [cssString release];
        [htmlString release];
        cssString = [[[self class] css] retain];
        htmlString = [[[self class] html] retain];
        lastNote = [app selectedNoteObject];
    }
    NSString *nvSupportPath = [[NSFileManager defaultManager] applicationSupportDirectory];

    [outputString replaceOccurrencesOfString:@"{%support%}" withString:nvSupportPath options:0 range:NSMakeRange(0, [outputString length])];
    [outputString replaceOccurrencesOfString:@"{%title%}" withString:noteTitle options:0 range:NSMakeRange(0, [outputString length])];
    [outputString replaceOccurrencesOfString:@"{%content%}" withString:previewString options:0 range:NSMakeRange(0, [outputString length])];
    [outputString replaceOccurrencesOfString:@"{%style%}" withString:cssString options:0 range:NSMakeRange(0, [outputString length])];

    [[preview mainFrame] loadHTMLString:outputString baseURL:nil];
    [preview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"var body = document.getElementsByTagName('body')[0],oldscroll = %@;body.scrollTop = oldscroll;",lastScrollPosition]];
    [[self window] setTitle:noteTitle];

    [sourceView replaceCharactersInRange:NSMakeRange(0, [[sourceView string] length]) withString:processedString];
    self.isPreviewOutdated = NO;
}

-(SEL)markupProcessorSelector:(NSInteger)previewMode
{
    if (previewMode == MarkdownPreview) {
        previewMode = MultiMarkdownPreview;
        return @selector(stringWithProcessedMultiMarkdown:);
    } else if (previewMode == MultiMarkdownPreview) {
        return @selector(stringWithProcessedMultiMarkdown:);
    }

    return nil;
}

+ (void) createCustomFiles
{
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSString *folder = [[NSFileManager defaultManager] applicationSupportDirectory];
    if ([fileManager fileExistsAtPath: folder] == NO)
    {
        [fileManager createFolderAtPath:folder];
        //				[fileManager createDirectoryAtPath: folder attributes: nil];

    }

    NSString *cssFileName = @"custom.css";
    NSString *cssFile = [folder stringByAppendingPathComponent: cssFileName];

    if ([fileManager fileExistsAtPath:cssFile] == NO)
    {
        NSString *cssPath = [[NSBundle mainBundle] pathForResource:@"customclean" ofType:@"css" inDirectory:nil];
        NSString *cssString = [NSString stringWithContentsOfFile:cssPath encoding:NSUTF8StringEncoding error:nil];
        NSData *cssData = [NSData dataWithBytes:[cssString UTF8String] length:[cssString length]];
        [fileManager createFileAtPath:cssFile contents:cssData attributes:nil];
    }

    NSString *htmlFileName = @"template.html";
    NSString *htmlFile = [folder stringByAppendingPathComponent: htmlFileName];

    if ([fileManager fileExistsAtPath:htmlFile] == NO)
    {
        NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"templateclean" ofType:@"html" inDirectory:nil];
        NSString *htmlString = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
        NSData *htmlData = [NSData dataWithBytes:[htmlString UTF8String] length:[htmlString length]];
        [fileManager createFileAtPath:htmlFile contents:htmlData attributes:nil];
    }

}

-(IBAction)makePreviewSticky:(id)sender
{
    self.isPreviewSticky = YES;
    //  [[preview window] setTitle:@"Locked"];
    [stickyPreviewButton setState:YES];
    [stickyPreviewButton setToolTip:@"Return the preview to normal functionality."];
    [stickyPreviewButton setAction:@selector(makePreviewNotSticky:)];
    [saveButton setEnabled:NO];
    [[self window] setHidesOnDeactivate:NO];
}

-(IBAction)makePreviewNotSticky:(id)sender
{
    self.isPreviewSticky = NO;
    [[preview window] setTitle:@"Preview"];
    [stickyPreviewButton setState:NO];
    [stickyPreviewButton setToolTip:@"Maintain current note in Preview, even if you switch to other notes."];
    [stickyPreviewButton setAction:@selector(makePreviewSticky:)];
    [saveButton setEnabled:YES];
    self.isPreviewOutdated = YES;
    [self performSelector:@selector(preview:) withObject:[[NSApplication sharedApplication] delegate] afterDelay:0.0];
    [[self window] setHidesOnDeactivate:YES];
}

-(IBAction)printPreview:(id)sender
{
    NSTabViewItem *selectedTab=[tabView selectedTabViewItem];
    //1 is webview   2 is source view
    if ([selectedTab.identifier integerValue]==1) {
        [tabView selectNextTabViewItem:self];
    }
    NSPrintInfo* printInfo = [NSPrintInfo sharedPrintInfo];

    [printInfo setHorizontallyCentered:YES];
    [printInfo setVerticallyCentered:NO];
    NSPrintOperation *printOp=[[[preview mainFrame] frameView] printOperationWithPrintInfo:printInfo];
    [printOp runOperationModalForWindow:tabView.window delegate:self didRunSelector:@selector(printOperationDidRun:success:contextInfo:) contextInfo:selectedTab];
}

- (void)printOperationDidRun:(NSPrintOperation *)printOperation  success:(BOOL)success  contextInfo:(void *)contextInfo{
    NSTabViewItem *selTab=(NSTabViewItem *)contextInfo;
    if (selTab&&(tabView.selectedTabViewItem!=selTab)) {
        [tabView selectTabViewItem:selTab];
    }
}

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSFileHandlingPanelOKButton) {

        AppController *app = [[NSApplication sharedApplication] delegate];
        NSString *rawString = [app noteContent];
        NSString *processedString = [[[NSString alloc] init] autorelease];

        if ([app currentPreviewMode] == MarkdownPreview) {
            processedString = [NSString stringWithProcessedMarkdown:rawString];
        } else if ([app currentPreviewMode] == MultiMarkdownPreview) {
            processedString = ( [includeTemplate state] == NSOnState ) ? [NSString documentWithProcessedMultiMarkdown:rawString] : [NSString xhtmlWithProcessedMultiMarkdown:rawString];
        }
        NSURL *file = [sheet URL];
        NSError *error;
        [processedString writeToURL:file atomically:YES encoding:NSUTF8StringEncoding error:&error];
    }
}

-(IBAction)saveHTML:(id)sender
{
    if (!accessoryView) {
        if (![NSBundle loadNibNamed:@"SaveHTMLPreview" owner:self]) {
            NSLog(@"Failed to load SaveHTMLPreview.nib");
            NSBeep();
            return;
        }

    }
    // TODO high coupling; too many assumptions on architecture:
    AppController *app = [NSApp delegate];

    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setAccessoryView:accessoryView];
    [savePanel setCanCreateDirectories:YES];
    [savePanel setCanSelectHiddenExtension:YES];

    NSArray *fileTypes = [[NSArray alloc] initWithObjects:@"html",@"xhtml",@"htm",nil];
    [savePanel setAllowedFileTypes:fileTypes];


    NSString *rawString = [app noteContent];
    NSString *xhtmlOutput = [NSString xhtmlWithProcessedMultiMarkdown:rawString];
    if ([xhtmlOutput hasPrefix:@"<?xml version="]) {
        [includeTemplate setState:0];
        [includeTemplate setEnabled:NO];
        [templateNote setStringValue:@"Template embed unavailable because your note will render as a full XHTML document"];
    } else {
        [includeTemplate setEnabled:YES];
        [templateNote setStringValue:@"Select this to embed the ouput within your current preview HTML and CSS"];
    }

    NSString *noteTitle =  ([app selectedNoteObject]) ? [NSString stringWithFormat:@"%@",titleOfNote([app selectedNoteObject])] : @"";
    //	[savePanel beginSheetForDirectory:nil file:noteTitle modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
    savePanel.nameFieldStringValue=noteTitle;
    [savePanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger returnCode) {
        if (returnCode == NSFileHandlingPanelOKButton) {
            NSString *processedString = [[[NSString alloc] init] autorelease];

            if ([app currentPreviewMode] == MarkdownPreview) {
                processedString = [NSString stringWithProcessedMarkdown:rawString];
            } else if ([app currentPreviewMode] == MultiMarkdownPreview) {
                processedString = ( [includeTemplate state] == NSOnState ) ? [NSString documentWithProcessedMultiMarkdown:rawString] : [NSString xhtmlWithProcessedMultiMarkdown:rawString];
            }
            NSURL *file = [savePanel URL];
            NSError *error;
            [processedString writeToURL:file atomically:YES encoding:NSUTF8StringEncoding error:&error];
        }
    }];
    [fileTypes release];

}

-(IBAction)switchTabs:(id)sender
{

    if ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 0) {
        [tabSwitcher setTitle:@"View Preview"];
        [tabView selectTabViewItem:[tabView tabViewItemAtIndex:1]];
    } else {
        [tabSwitcher setTitle:@"View Source"];
        [tabView selectTabViewItem:[tabView tabViewItemAtIndex:0]];
    }
}

- (void)dealloc {
    [htmlString release];
    [cssString release];
    [lastNote release];
    [saveButton release];
    [tabSwitcher release];
    [preview release];
    [super dealloc];
}

@end
