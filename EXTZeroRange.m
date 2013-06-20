//
//  EXTZeroRange.m
//  Ext Chart
//
//  Created by Eric Peterson on 6/20/13.
//  Copyright (c) 2013 Harvard University. All rights reserved.
//

#import "EXTZeroRange.h"

@implementation EXTZeroRangePair

@synthesize leftEdge, rightEdge, topEdge, bottomEdge;

-(BOOL) isInRange:(EXTPair*)loc {
    return ((loc.a >= leftEdge) &&
            (loc.a <= rightEdge) &&
            (loc.b >= bottomEdge) &&
            (loc.b <= topEdge));
}

@end



@implementation EXTZeroRangeTriple

@synthesize leftEdge, rightEdge, topEdge, bottomEdge, backEdge, frontEdge;

-(BOOL) isInRange:(EXTTriple*)loc {
    return ((loc.a >= leftEdge) &&
            (loc.a <= rightEdge) &&
            (loc.b >= bottomEdge) &&
            (loc.b <= topEdge) &&
            (loc.c >= backEdge) &&
            (loc.c <= frontEdge));
}

@end