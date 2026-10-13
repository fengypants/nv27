//
//  NotationPrefsViewController.h
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

@class NotationPrefs;

@interface FileKindListView : NSTableView {
    IBOutlet NSPopUpButton *storageFormatPopupButton;
}
@end

@interface NotationPrefsViewController : NSObject 
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_6
<NSTableViewDelegate, NSTableViewDataSource>
#endif
{
    IBOutlet NSTableView *allowedExtensionsTable;
    IBOutlet NSTableView *allowedTypesTable;
    IBOutlet NSTextField *fileAttributesHelpText;
    IBOutlet NSButton *newExtensionButton;
    IBOutlet NSButton *newTypeButton;
	IBOutlet NSButton *makeDefaultExtensionButton;
    IBOutlet NSButton *removeExtensionButton;
    IBOutlet NSButton *removeTypeButton;
    IBOutlet NSButton *confirmFileDeletionButton;
	IBOutlet NSButton *secureTextEntryButton;
    IBOutlet NSPopUpButton *storageFormatPopupButton;
    IBOutlet NSWindow *webOptionsWindow;
	
	//controls of the removed Simplenote "Synchronization" tab; still connected in NotationPrefsView.nib
	IBOutlet NSButton *enabledSyncButton;
	IBOutlet NSTextField *syncAccountField, *syncPasswordField, *verifyStatusField;
	IBOutlet NSImageView *verifyStatusImageView, *syncEncAlertView;
	IBOutlet NSTextField *syncEncAlertField;
	IBOutlet NSPopUpButton *syncingFrequency;
	
	//controls of the removed note encryption feature (in the "Security" tab); still connected in NotationPrefsView.nib
	IBOutlet NSButton *enableEncryptionButton, *changePasswordButton, *removeFromKeychainButton;
	IBOutlet NSStepper *keyLengthStepper;
	IBOutlet NSTextField *keyLengthField;
	IBOutlet NSMatrix *passwordSettingsMatrix;
    
    IBOutlet NSView *view;
	NSSegmentedControl *extensionButtons;

	BOOL didAwakeFromNib;
    
	NSInteger notesStorageFormatInProgress;
    NotationPrefs *notationPrefs;

    
#pragma mark nvALT Finder tagging
    IBOutlet NSButton *useFinderTaggingButton;
}

- (NSView*)view;
- (void)removeSynchronizationTab;
- (void)removeEncryptionControls;
- (void)setSeparateFileControlsState:(BOOL)separateFileControlsState;
- (void)initializeControls;

- (IBAction)addedExtension:(id)sender;
- (IBAction)addedType:(id)sender;
- (IBAction)changedFileDeletionWarningSettings:(id)sender;
- (IBAction)changedFileStorageFormat:(id)sender;
- (IBAction)changedSecureTextEntry:(id)sender;
- (void)notesStorageFormatDidChange;
- (NSInteger)notesStorageFormatInProgress;
- (IBAction)makeDefaultExtension:(id)sender;
- (IBAction)removedExtension:(id)sender;
- (IBAction)removedType:(id)sender;


#pragma mark nvALT Finder tagging
- (IBAction)switchToFinderTags:(id)sender;

@end
