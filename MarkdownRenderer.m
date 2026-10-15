//
//  MarkdownRenderer.m
//  Notation
//

#import "MarkdownRenderer.h"

#include <cmark-gfm.h>
#include <cmark-gfm-core-extensions.h>

@implementation MarkdownRenderer

static NSString *RenderCommonMark(NSString *markdown, BOOL smartPunctuation) {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		cmark_gfm_core_extensions_ensure_registered();
	});

	if (![markdown length])
		return @"";

	//raw HTML in notes is intentional (as with Markdown.pl and MultiMarkdown), so render it unescaped
	int options = CMARK_OPT_UNSAFE | CMARK_OPT_FOOTNOTES | CMARK_OPT_STRIKETHROUGH_DOUBLE_TILDE;
	if (smartPunctuation)
		options |= CMARK_OPT_SMART;

	cmark_parser *parser = cmark_parser_new(options);
	if (!parser)
		return @"";

	static const char *extensionNames[] = { "table", "strikethrough", "autolink", "tasklist" };
	for (size_t i = 0; i < sizeof(extensionNames) / sizeof(extensionNames[0]); i++) {
		cmark_syntax_extension *extension = cmark_find_syntax_extension(extensionNames[i]);
		if (extension)
			cmark_parser_attach_syntax_extension(parser, extension);
	}

	const char *utf8 = [markdown UTF8String];
	cmark_parser_feed(parser, utf8, strlen(utf8));
	cmark_node *document = cmark_parser_finish(parser);

	NSString *html = @"";
	if (document) {
		char *renderedHTML = cmark_render_html(document, options, cmark_parser_get_syntax_extensions(parser));
		if (renderedHTML) {
			html = [NSString stringWithUTF8String:renderedHTML] ?: @"";
			cmark_get_default_mem_allocator()->free(renderedHTML);
		}
		cmark_node_free(document);
	}
	cmark_parser_free(parser);

	return html;
}

//MultiMarkdown metadata: "Key: value" lines (with indented continuation lines) at the very top of
//the note, terminated by a blank line; also accepts YAML front matter delimited by "---"
static NSString *StringByRemovingMetadata(NSString *markdown) {
	static NSRegularExpression *keyLineExpression = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		keyLineExpression = [[NSRegularExpression alloc] initWithPattern:@"^[A-Za-z0-9][A-Za-z0-9 _-]*:(?!//)" options:0 error:NULL];
	});

	NSString *normalized = [[markdown stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"]
							stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
	NSArray *lines = [normalized componentsSeparatedByString:@"\n"];
	if (![lines count])
		return markdown;

	NSString *firstLine = [lines objectAtIndex:0];

	if ([firstLine isEqualToString:@"---"]) {
		NSUInteger i;
		for (i = 1; i < [lines count]; i++) {
			NSString *line = [lines objectAtIndex:i];
			if ([line isEqualToString:@"---"] || [line isEqualToString:@"..."]) {
				return [[lines subarrayWithRange:NSMakeRange(i + 1, [lines count] - (i + 1))] componentsJoinedByString:@"\n"];
			}
		}
		return markdown;
	}

	if (![keyLineExpression firstMatchInString:firstLine options:0 range:NSMakeRange(0, [firstLine length])])
		return markdown;

	NSUInteger i;
	for (i = 1; i < [lines count]; i++) {
		NSString *line = [lines objectAtIndex:i];
		if (![[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length])
			break;
		BOOL isContinuation = [line hasPrefix:@" "] || [line hasPrefix:@"\t"];
		if (!isContinuation && ![keyLineExpression firstMatchInString:line options:0 range:NSMakeRange(0, [line length])])
			return markdown; //not a metadata block after all
	}

	if (i >= [lines count])
		return @"";
	return [[lines subarrayWithRange:NSMakeRange(i, [lines count] - i)] componentsJoinedByString:@"\n"];
}

//MultiMarkdown gives each header an id derived from its text (lowercased, without spaces or
//punctuation), which is what [link][Header Text] cross-references and custom CSS/JS rely on
static NSString *StringByAddingHeaderIDs(NSString *html) {
	static NSRegularExpression *headerExpression = nil, *tagExpression = nil;
	static NSCharacterSet *allowedCharacters = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		headerExpression = [[NSRegularExpression alloc] initWithPattern:@"<h([1-6])>(.*?)</h\\1>" options:0 error:NULL];
		tagExpression = [[NSRegularExpression alloc] initWithPattern:@"<[^>]*>|&[#A-Za-z0-9]+;" options:0 error:NULL];
		NSMutableCharacterSet *set = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
		[set addCharactersInString:@"-_:."];
		allowedCharacters = [set copy];
		[set release];
	});

	NSArray *matches = [headerExpression matchesInString:html options:0 range:NSMakeRange(0, [html length])];
	if (![matches count])
		return html;

	NSMutableString *result = [[html mutableCopy] autorelease];
	for (NSTextCheckingResult *match in [matches reverseObjectEnumerator]) {
		NSString *innerHTML = [html substringWithRange:[match rangeAtIndex:2]];
		NSString *text = [tagExpression stringByReplacingMatchesInString:innerHTML options:0 range:NSMakeRange(0, [innerHTML length]) withTemplate:@""];

		NSMutableString *label = [NSMutableString stringWithCapacity:[text length]];
		NSString *lowercaseText = [text lowercaseString];
		NSUInteger i;
		for (i = 0; i < [lowercaseText length]; i++) {
			unichar c = [lowercaseText characterAtIndex:i];
			if ([allowedCharacters characterIsMember:c])
				[label appendFormat:@"%C", c];
		}
		if (![label length])
			continue;

		NSString *level = [html substringWithRange:[match rangeAtIndex:1]];
		NSRange openingTagRange = NSMakeRange([match range].location, 4); //"<hN>"
		[result replaceCharactersInRange:openingTagRange withString:[NSString stringWithFormat:@"<h%@ id=\"%@\">", level, label]];
	}
	return result;
}

+ (NSString *)HTMLFromMarkdown:(NSString *)markdown {
	return RenderCommonMark(markdown, NO);
}

+ (NSString *)HTMLFromMultiMarkdown:(NSString *)markdown {
	return StringByAddingHeaderIDs(RenderCommonMark(StringByRemovingMetadata(markdown), YES));
}

@end
