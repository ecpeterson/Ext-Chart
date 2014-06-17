//
//  EXTMaySpectralSequence.m
//  Ext Chart
//
//  Created by Eric Peterson on 7/9/13.
//  Copyright (c) 2013 Harvard University. All rights reserved.
//

#import "EXTMaySpectralSequence.h"
#import "EXTTriple.h"
#import "EXTDifferential.h"

@interface EXTMayTag : NSObject <NSCopying, NSCoding>

@property (assign) int i, j;

+(EXTMayTag*) tagWithI:(int)i J:(int)j;
-(NSString*) description;
-(NSUInteger) hash;

@end

@implementation EXTMayTag

@synthesize i, j;

+(EXTMayTag*) tagWithI:(int)i J:(int)j {
    EXTMayTag *ret = [EXTMayTag new];
    ret.i = i; ret.j = j;
    return ret;
}

-(NSString*) description {
    return [NSString stringWithFormat:@"h_{%d,%d}",i,j];
}

-(EXTMayTag*) copyWithZone:(NSZone*)zone {
    EXTMayTag *ret = [[EXTMayTag allocWithZone:zone] init];
    ret.i = i; ret.j = j;
    return ret;
}

-(BOOL) isEqual:(id)object {
    if ([object class] != [EXTMayTag class])
        return FALSE;
    return ((((EXTMayTag*)object)->i == i) &&
            (((EXTMayTag*)object)->j == j));
}

-(NSUInteger) hash {
    long long key = i;
	key = (~key) + (key << 18); // key = (key << 18) - key - 1;
    key += j;
	key = key ^ (key >> 31);
	key = key * 21; // key = (key + (key << 2)) + (key << 4);
	key = key ^ (key >> 11);
	key = key + (key << 6);
	key = key ^ (key >> 22);
	return (int) key;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        i = [aDecoder decodeIntForKey:@"i"];
        j = [aDecoder decodeIntForKey:@"j"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInteger:i forKey:@"i"];
    [aCoder encodeInteger:j forKey:@"j"];
}

@end




@implementation EXTMaySpectralSequence

-(instancetype) init {
    return self = [super initWithIndexingClass:[EXTTriple class]];
}

// TODO: should this routine be memoized?
//
// XXX: I'm nervous that not all squares of all sums in a given location will
// land in the same filtration degree.  Hence, it may not make sense to compute
// the squaring operation en masse...  :(
-(NSArray*) squaringMatrix:(int)order location:(EXTTriple*)location {
    // we know the following three facts about the squaring operations:
    // Sq^n(xy) = sum_{i=0}^n Sq^i x Sq^{n-i} y, (Cartan)
    // Sq^0(h_ij) = h_i(j+1),                    (Nakamura on Sq^0)
    // Sq^1(h_ij) = h_ij^2.                      (Definition of Sq^n on n-class)
    //
    // since we're generated by classes of degree 1, this completely determines
    // the squaring structure everywhere, by iteratively splitting apart a
    // square until we get down to just Sq^0s and Sq^1s.
    //
    // an important thing to realize is that applying this naively yields the
    // differential d2 b30 = h12^2 h21 + h13 h20^2 + h21^2 h11 + h22 h10^2.
    // however, the outer two terms are of lower May filtration than the middle
    // two, and so we project to the higher nonzero May filtration degree to get
    // just d2 b30 = h13 h20^2 + h21^2 h11.
    
    EXTTerm *startTerm = [self findTerm:location],
            *endTerm = nil;
    EXTMatrix *ret = nil;
    int activeMayDegree = -1;
    
    for (int termIndex = 0; termIndex < startTerm.size; termIndex++) {
        EXTPolynomialTag *tag = startTerm.names[termIndex];
        NSArray *tags = tag.tags.allKeys;
        NSMutableArray *counters = [NSMutableArray arrayWithCapacity:tags.count];
        for (int i = 0; i < tags.count; i++)
            counters[i] = @0;
        
        // initialize the counter with the left-most stuffing
        int leftover = order;
        
        // iterate through the available buckets.  this loop breaks out whenever
        // we completely roll over on the carries.
        do {
            // start by initializing the leftmost buckets
            for (int i = 0; leftover > 0; i++) {
                int bucketSize = [[tag.tags objectForKey:tags[i]] intValue];
                counters[i] = @(leftover < bucketSize ? leftover : bucketSize);
                leftover -= bucketSize;
            }
            
            // at each term, perform the assigned number of Sq^1s, and apply
            // Sq^0 to the remainder.
            // so: (h_ij^n) |-> (n r) h_ij^(2r) h_i(j+1)^(n-r).
            //
            // first, note that 2 | (n r) exactly when r&(n-r) is true. :) so,
            // if that's ever true then we can just skip this summand entirely.
            bool zeroMod2 = false;
            for (int i = 0; i < counters.count; i++) {
                int r = [counters[i] intValue],
                    n = [[tag.tags objectForKey:tags[i]] intValue];
                zeroMod2 |= r & (n - r);
            }
            
            // if we're not 0 mod 2, then we're 1 mod 2.  this means one of
            // three things can happen next:
            //   1) this term is of lower filtration degree than the active term
            //      and so we skip it and contribute nothing.
            //   2) this term is of filtration degree equal to the active term,
            //      so we add it as expected.
            //   3) this term is of higher filtration degree than the active
            //      term, so we clear the matrix, reinitialize it to point to
            //      the new target, and poke the new value in.
            if (!zeroMod2) {
                EXTPolynomialTag *targetTag = [EXTPolynomialTag new];
                
                // start by building the tag we're going to be looking up
                int mayDegree = 0;
                for (int i = 0; i < counters.count; i++) {
                    EXTMayTag *hij = tags[i],
                              *hinext = [EXTMayTag tagWithI:hij.i J:(hij.j+1)];
                    int n = [[tag.tags objectForKey:tags[i]] intValue],
                        r = [counters[i] intValue];
                    NSNumber *oldSq0Exp = [targetTag.tags objectForKey:hinext],
                             *oldSq1Exp = [targetTag.tags objectForKey:hij];
                    
                    if (oldSq0Exp)
                        oldSq0Exp = @([oldSq0Exp intValue] + n-r);
                    else
                        oldSq0Exp = @(n-r);
                    
                    if (oldSq1Exp)
                        oldSq1Exp = @([oldSq1Exp intValue] + 2*r);
                    else
                        oldSq1Exp = @(2*r);
                    
                    [targetTag.tags setObject:oldSq0Exp forKey:hinext];
                    [targetTag.tags setObject:oldSq1Exp forKey:hij];
                    
                    mayDegree += hij.i*(n+r);
                }
                
                // now we have to make a comparison based on filtration degree.
                if (mayDegree > activeMayDegree) {                    
                    // convert the target tag to an EXTLocation
                    EXTTriple *targetLoc = [EXTTriple identityLocation];
                    for (EXTMayTag *workingTag in targetTag.tags) {
                        EXTTriple *hij = [EXTTriple tripleWithA:1 B:((1<<workingTag.j)*((1<<workingTag.i)-1)) C:workingTag.i];
                        targetLoc = [EXTTriple addLocation:targetLoc to:[EXTTriple scale:hij by:[[targetTag.tags objectForKey:workingTag] intValue]]];
                    }
                    
                    // set up a new target matrix and target term
                    EXTTerm *tempTarget = [self findTerm:targetLoc];
                    if (tempTarget) {
                        endTerm = tempTarget;
                        activeMayDegree = mayDegree;
                        ret = [EXTMatrix matrixWidth:startTerm.size height:endTerm.size];
                    }
                }
                
                if (mayDegree == activeMayDegree) {
                    // find this tag in the target term and poke the value
                    NSMutableArray *col = ret.presentation[termIndex];
                    int pokeIndex = [endTerm.names indexOfObject:targetTag];
                    if (pokeIndex != -1)
                        col[pokeIndex] = @([col[pokeIndex] intValue] + 1);
                }
            }
                        
            // now we move to the next bucket.  start by finding the leftmost
            // nonzero bucket.
            int leftmost = 0;
            for (; [counters[leftmost] intValue] == 0; leftmost++);
            
            // this value of this bucket is going to be split into (value-1)+1.
            // the right-hand part of this is used for a carry, and the left-
            // hand part is used for 'leftovers' to minimally reinitialize
            // the leftmost segment of the counters.
            leftover = [counters[leftmost] intValue] - 1;
            counters[leftmost] = @0;
            // continually try to perform carries until we hit a not-maxed bucket
            int carryBuckets = leftmost+1;
            for (; carryBuckets < counters.count; carryBuckets++) {
                if ([counters[carryBuckets] isEqual:[tag.tags objectForKey:tags[carryBuckets]]]) {
                    leftover += [counters[carryBuckets] intValue];
                    counters[carryBuckets] = @0;
                } else {
                    counters[carryBuckets] = @(1 + [counters[carryBuckets] intValue]);
                    break;
                }
            }
            if (carryBuckets == counters.count)
                leftover += 1;
        } while (leftover != order); // cartan loop
    } // term summand loop
    
    if (!ret || !endTerm)
        return nil;
    
    return @[ret,endTerm];
}

// applies Sq^(order) to the terms at location to get a differential on page page
-(void) calculateNakamura:(int)order location:(EXTTriple*)location page:(int)page {
    // we need to look up:
    // * the differential on E_new off the target location of Sq^order
    // * the differential on E_old off location
    // * the matrix describing the map Sq^order on E_new
    // * the matrix describing the map Sq^order on E_old
    //
    // then, we apply: d_page (Sq^order x) = Sq^order (d_{page-order} x).
    
    EXTDifferential *underlyingDiff = [self findDifflWithSource:location onPage:page];
    if (!underlyingDiff)
        return;
    
    NSArray *startSquarePair = [self squaringMatrix:order location:((EXTTriple*)underlyingDiff.start.location)],
            *endSquarePair = [self squaringMatrix:order location:((EXTTriple*)underlyingDiff.end.location)];
    
    EXTMatrix *startSquare = startSquarePair[0], *endSquare = endSquarePair[0];
    EXTTerm *newStart = startSquarePair[1], *newEnd = endSquarePair[1];
    if (!newStart || !newEnd)
        return;
    
    int newPage = [EXTTriple calculateDifflPage:newStart.location end:newEnd.location];
    if (newPage == -1) {
        NSLog(@"Something has gone horribly wrong in calculateNakamura...");
    }
    
    EXTDifferential *diff = [self findDifflWithSource:newStart.location onPage:newPage];
    if (!diff) {
        diff = [EXTDifferential differential:newStart end:newEnd page:newPage];
        [self addDifferential:diff];
    }
    
    // for each partial definition A <-- I --> B, we have two squaring morphisms
    // A --> C and B --> D, which we glue together to get the span
    // C <-- A <-- I --> B --> D.
    for (EXTPartialDefinition *oldPartial in underlyingDiff.partialDefinitions) {
        EXTPartialDefinition *partial = [EXTPartialDefinition new];
        partial.action = [EXTMatrix newMultiply:endSquare by:oldPartial.action];
        partial.inclusion = [EXTMatrix newMultiply:startSquare by:oldPartial.inclusion];
        partial.description = [NSString stringWithFormat:@"Nakamura's lemma applied to Sq^%d on %@ in E%d",order,location,page];
        [diff.partialDefinitions addObject:partial];
        // TODO: it's not clear that the rest of the code requires the inclusion
        // map to be an inclusion.  if it does, we should insert something to
        // make that so.  otherwise, we shouldn't, since it requires a choice.
    }

    return;
}

-(void) propagateNakamura:(int)page generators:(NSMutableArray*)generators {
    // then propagate with nakamura's lemma / the cartan formula until exhausted
    
    return;
}

+(EXTMaySpectralSequence*) fillForAn:(int)n width:(int)width {
    EXTMaySpectralSequence *sseq = [EXTMaySpectralSequence new];
    
    [sseq.zeroRanges addObject:[EXTZeroRangeStrict newWithSSeq:sseq]];
    EXTZeroRangeTriple *zrTriple = [EXTZeroRangeTriple new];
    zrTriple.leftEdge = zrTriple.bottomEdge = zrTriple.backEdge = 0;
    zrTriple.rightEdge = zrTriple.topEdge = zrTriple.frontEdge = width;
    [sseq.zeroRanges addObject:zrTriple];
    
    // start by adding the polynomial terms h_{i,j}
    for (int i = 1; ; i++) {
        
        // if we've passed outside of the width or left A(n), then quit.
        if (((1 << i)-2 > width) || (i > n+1))
            break;
        
        for (int j = 0; ; j++) {
            // calculate the location of the present term
            int A = 1, B = (1 << j)*((1 << i) - 1), C = i;
            
            // if we're outside the width limit *or* if we've hit the truncation
            // level, then it's time to move on to the next element.
            if ((B - 1 > width) || (j >= (1 << (n-i+1))))
                break;
            
            int limit = ((i == 1) && (j == 0)) ? width : width/(B-1);
            
            [sseq addPolyClass:[EXTMayTag tagWithI:i J:j] location:[EXTTriple tripleWithA:A B:B C:C] upTo:limit];
        }
    }
    
    [sseq buildDifferentials];
    
    return sseq;
}

+(EXTMaySpectralSequence*) fillToWidth:(int)width {
    EXTMaySpectralSequence *sseq = [EXTMaySpectralSequence new];
    EXTZeroRangeTriple *zrTriple = [EXTZeroRangeTriple new];
    zrTriple.leftEdge = zrTriple.bottomEdge = zrTriple.backEdge = 0;
    zrTriple.rightEdge = zrTriple.topEdge = zrTriple.frontEdge = width;
    [sseq.zeroRanges addObject:zrTriple];
    
    [sseq.zeroRanges addObject:[EXTZeroRangeStrict newWithSSeq:sseq]];
    
    // start by adding the polynomial terms h_{i,j}
    for (int i = 1; ; i++) {
        
        // if we've passed outside of the width, then quit.
        if ((1 << i)-2 > width)
            break;
        
        for (int j = 0; ; j++) {
            // calculate the location of the present term
            int A = 1, B = (1 << j)*((1 << i) - 1), C = i;
            if (B - 1 > width)
                break;
            
            int limit = ((i == 1) && (j == 0)) ? width : width/(B-1);
            
            [sseq addPolyClass:[EXTMayTag tagWithI:i J:j] location:[EXTTriple tripleWithA:A B:B C:C] upTo:limit];
        }
    }
    
    [sseq buildDifferentials];
    
    return sseq;
}

-(void) buildDifferentials {
    // add the d1 differentials
    for (NSDictionary *generator in self.generators) {
        EXTMayTag *tag = [generator objectForKey:@"name"];
        int i = tag.i, j = tag.j;
        
        // these elements are genuinely primitive, so never support diff'ls.
        if (i == 1)
            continue;
        
        EXTTriple *location = [generator objectForKey:@"location"];
        EXTTerm *target = [self findTerm:[EXTTriple followDiffl:location page:1]];
        EXTDifferential *diff = [EXTDifferential differential:[self findTerm:location] end:target page:1];
        EXTPartialDefinition *partial = [EXTPartialDefinition new];
        partial.inclusion = [EXTMatrix identity:1];
        partial.action = [EXTMatrix matrixWidth:1 height:target.size];
        
        // the formula for the May d_1 comes straight from the Steenrod
        // diagonal: d_1 h_{i,j} = sum_{k=1}^{i-1} h_{k,i-k+j} h_{i-k,j}
        for (int k = 1; k <= i-1; k++) {
            EXTMayTag *tagLeft = [EXTMayTag tagWithI:k J:(i-k+j)],
            *tagRight = [EXTMayTag tagWithI:(i-k) J:j];
            
            NSDictionary *leftEntry = nil, *rightEntry = nil;
            for (NSDictionary *workingEntry in self.generators)
                if ([[workingEntry objectForKey:@"name"] isEqual:tagLeft])
                    leftEntry = workingEntry;
                else if ([[workingEntry objectForKey:@"name"] isEqual:tagRight])
                    rightEntry = workingEntry;
            EXTMatrix *product = [self productWithLeft:[leftEntry objectForKey:@"location"] right:[rightEntry objectForKey:@"location"]];
            partial.action = [EXTMatrix sum:partial.action with:product];
            partial.description = [NSString stringWithFormat:@"May d1 differential on %@",tag];
        }
        
        [diff.partialDefinitions addObject:partial];
        [self addDifferential:diff];
    }
    
    // propagate the d1 differentials with Leibniz's rule
    NSMutableArray *locations = [NSMutableArray array];
    for (NSMutableDictionary *generator in self.generators)
        [locations addObject:[generator objectForKey:@"location"]];
    [self propagateLeibniz:locations page:1];
    
    // TODO: use nakamura's lemma to get the higher differentials.
    // XXX: right now i'm going to hard-code something that works for A(1)...
    EXTTriple *h20 = [EXTTriple tripleWithA:1 B:3 C:2];
    if ([self findTerm:h20])
        [self calculateNakamura:1 location:h20 page:1];
    
    EXTTriple *h20squared = [EXTTriple tripleWithA:2 B:6 C:4];
    if ([self findTerm:h20squared])
        [self propagateLeibniz:@[h20squared, [EXTTriple tripleWithA:1 B:1 C:1], [EXTTriple tripleWithA:1 B:2 C:1]] page:2];
    
    return;
}

@end
