//
//  NSString_MultiMarkdown.m
//  Notation
//
//  Created by Christian Tietze on 2010-10-10.
//

#import "NSString_MultiMarkdown.h"
#import "PreviewController.h"
#import "AppController.h"
#import "NoteObject.h"
#import "MarkdownRenderer.h"

@implementation NSString (MultiMarkdown)

+(NSString*)processTaskPaper:(NSString*)inputString
{
    if (inputString)
    {
        //TaskPaper conversion relies on the system Ruby, which macOS may not ship; render as plain MultiMarkdown without it
        NSString *taskPaperScriptPath = @"/usr/bin/ruby";
        if (![[NSFileManager defaultManager] isExecutableFileAtPath:taskPaperScriptPath])
            return inputString;


        NSString *argPath = [[NSBundle mainBundle] pathForResource:@"tp2md"
                                                            ofType:@"rb"
                                                       inDirectory:NULL];

        NSTask *taskPaperTask = [[[NSTask alloc] init] autorelease];
        NSPipe *stdinPipe = [NSPipe pipe];
        NSPipe *stdoutPipe = [NSPipe pipe];
        NSFileHandle *stdinFileHandle = [stdinPipe fileHandleForWriting];
        NSFileHandle *stdoutFileHandle = [stdoutPipe fileHandleForReading];

        [taskPaperTask setStandardInput:stdinPipe];
        [taskPaperTask setStandardOutput:stdoutPipe];

        [taskPaperTask setLaunchPath:taskPaperScriptPath];
        NSArray *argArray = [NSArray arrayWithObject:argPath];
        [taskPaperTask setArguments:argArray];

        [taskPaperTask launch];

        NSString *blech = [NSString stringWithUTF8String:[inputString UTF8String]];

        [stdinFileHandle writeData:[blech dataUsingEncoding:NSUTF8StringEncoding]];
        [stdinFileHandle closeFile];

        NSData *outputData = [stdoutFileHandle readDataToEndOfFile];
        inputString = [[[NSString alloc] initWithData:outputData
                                            encoding:NSUTF8StringEncoding] autorelease];

        [stdoutFileHandle closeFile];


        [taskPaperTask waitUntilExit];

        [taskPaperTask terminate];
    }

	return inputString;
	
}


+(NSString*)processMultiMarkdown:(NSString*)inputString
{
  NSRange archiveFoundRange = [inputString rangeOfString:@"Archive:"];
  NSRange tagFoundRange = [inputString rangeOfString:@"@taskpaper"];
  if (archiveFoundRange.location != NSNotFound || tagFoundRange.location != NSNotFound) {
    inputString = [self processTaskPaper:inputString];
  }
	return [MarkdownRenderer HTMLFromMultiMarkdown:inputString];
}

+(NSString*)documentWithProcessedMultiMarkdown:(NSString*)inputString
{
  AppController *app = [[NSApplication sharedApplication] delegate];
  NSString *processedString = [self processMultiMarkdown:inputString];
  NSString *htmlString = [[PreviewController class] html];
  NSString *cssString = [[PreviewController class] css];
  NSMutableString *outputString = [NSMutableString stringWithString:(NSString *)htmlString];
  NSString *noteTitle =  ([app selectedNoteObject]) ? [NSString stringWithFormat:@"%@",titleOfNote([app selectedNoteObject])] : @"";
		NSString *nvSupportPath = [[NSFileManager defaultManager] applicationSupportDirectory];

  [outputString replaceOccurrencesOfString:@"{%support%}" withString:nvSupportPath options:0 range:NSMakeRange(0, [outputString length])];
  [outputString replaceOccurrencesOfString:@"{%title%}" withString:noteTitle options:0 range:NSMakeRange(0, [outputString length])];
  [outputString replaceOccurrencesOfString:@"{%content%}" withString:processedString options:0 range:NSMakeRange(0, [outputString length])];
  [outputString replaceOccurrencesOfString:@"{%style%}" withString:cssString options:0 range:NSMakeRange(0, [outputString length])];
  return outputString;
}

+(NSString*)xhtmlWithProcessedMultiMarkdown:(NSString*)inputString
{
	return [self processMultiMarkdown:inputString];
}

+(NSString*)stringWithProcessedMultiMarkdown:(NSString*)inputString
{
	return [self processMultiMarkdown:inputString];
} // stringWithProcessedMultiMarkdown:

@end // NSString (MultiMarkdown)
