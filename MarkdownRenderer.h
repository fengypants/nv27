//
//  MarkdownRenderer.h
//  Notation
//
//  In-process Markdown/MultiMarkdown-to-HTML conversion using cmark-gfm.
//  Replaces the bundled Intel-only multimarkdown executable and the Markdown.pl
//  perl script, both of which required spawning a process for every render.
//

#import <Foundation/Foundation.h>

@interface MarkdownRenderer : NSObject

//CommonMark + GitHub extensions (tables, strikethrough, autolinks, task lists, footnotes)
+ (NSString *)HTMLFromMarkdown:(NSString *)markdown;

//as above, plus MultiMarkdown conveniences: a leading metadata block (or YAML front matter)
//is not rendered, and headers get MultiMarkdown-style id attributes for internal links
+ (NSString *)HTMLFromMultiMarkdown:(NSString *)markdown;

@end
