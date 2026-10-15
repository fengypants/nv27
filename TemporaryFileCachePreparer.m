//
//  TemporaryFileCachePreparer.m
//  Notation
//

/*Copyright (c) 2010, Zachary Schneirov. All rights reserved.
    This file is part of Notational Velocity.

    Notational Velocity is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Notational Velocity is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Notational Velocity.  If not, see <http://www.gnu.org/licenses/>. */


#import "TemporaryFileCachePreparer.h"
#import "NotationPrefs.h"

//prepares the private temporary folder in which notes are written out for editing in external (ODB) editors
//(this used to mount a RAM disk for encrypted databases; note encryption has since been removed)

@implementation TemporaryFileCachePreparer

static NSString *TempDirectoryPathForEditing() {
	return [NSTemporaryDirectory() stringByAppendingPathComponent:@"NVPlainTextEditingSpace"];
}

- (void)dealloc {
	[preparedCachePath release];
	[super dealloc];
}

- (void)prepEditingSpaceIfNecessaryForNotationPrefs:(NotationPrefs*)prefs {
	
	NSAssert(prefs != nil, @"prefs are nil");
	
	/*
		plain text files: just use files directly
		database, rich text and HTML files: use the temp directory
	
		ODBEditor will decide based on each specific file whether to open it directly
		e.g., if it's a plain text file in plain-text-mode, or if the editor supports RTF/HTML
	*/
	
	if ([self _createFolderAtPath:TempDirectoryPathForEditing()]) {
		[self _finishPreparationWithPath:TempDirectoryPathForEditing()];
	} else {
		[self _stopPreparation];
	}
}

- (NSString*)preparedCachePath {
	return preparedCachePath;
}

- (void)_finishPreparationWithPath:(NSString*)aPath {
	//funnel for the success delegate method
	
	NSAssert(preparedCachePath == nil, @"preparedCachePath already set?");
	preparedCachePath = [aPath retain];
	
	[delegate temporaryFileCachePreparerFinished:self];
}

- (void)_stopPreparation {
	[delegate temporaryFileCachePreparerDidNotFinish:self];
}

- (void)setDelegate:(id)aDelegate {
	if (aDelegate) {
		NSAssert([aDelegate respondsToSelector:@selector(temporaryFileCachePreparerDidNotFinish:)], @"delegate is bad (1)");
		NSAssert([aDelegate respondsToSelector:@selector(temporaryFileCachePreparerFinished:)], @"delegate is bad (2)");
	}
	delegate = aDelegate;
}
- (id)delegate {
	return delegate;
}

- (BOOL)_createFolderAtPath:(NSString*)path {
	NSError *err = nil;
	NSFileManager *fileMan = [NSFileManager defaultManager];
	BOOL isDirectory = NO, didCreate = ([fileMan fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory) ? YES : 
	[fileMan createDirectoryAtPath:path withIntermediateDirectories:NO attributes:
	 [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:0700] forKey:NSFilePosixPermissions] error:&err];
	if (!didCreate) NSLog(@"couldn't create directory '%@': %@", path, (err ? [err localizedDescription] : @"(unknown error)"));
	return didCreate;
}

@end
