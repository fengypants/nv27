//
// NSString-Markdown.m
// http://github.com/panicsteve/nv/commit/ce6bf6e5cc3a635ed51fbecffd486ee97808220e
//

#import "NSString_Markdown.h"
#import "NoteObject.h"
#import "MarkdownRenderer.h"

@implementation NSString (Markdown)

+ (NSString*)stringWithProcessedMarkdown:(NSString*)inputString
{
	return [MarkdownRenderer HTMLFromMarkdown:inputString];
}

@end
