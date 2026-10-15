//
//  ETScrollView.m
//  Notation
//
//  Created by elasticthreads on 3/14/11.
//

#import "ETScrollView.h"

@implementation ETScrollView


+ (BOOL)isCompatibleWithResponsiveScrolling{
    return NO;
}


- (void)awakeFromNib{
    //nvALT's custom scrollers are gone; use the system's (overlay or legacy, following the user's setting)
    [self setHorizontalScrollElasticity:NSScrollElasticityNone];
    [self setVerticalScrollElasticity:NSScrollElasticityAllowed];
    if ([self.documentView isKindOfClass:[NSTableView class]])
        [self setAutohidesScrollers:YES];
    [self setScrollerStyle:[NSScroller preferredScrollerStyle]];
}

@end
