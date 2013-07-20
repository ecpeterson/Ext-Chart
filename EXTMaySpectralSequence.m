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

@interface EXTMayTag : NSObject <NSCopying>
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
@end




@implementation EXTMaySpectralSequence

+(EXTTriple*) followSquare:(EXTTriple*)location order:(int)order {
    /*
     |h_ij| = (1, 2^j(2^i-1), i)
     |Sq^0 h_ij| = |h_i(j+1)| = (1, 2 2^j(2^i-1), i)
     |Sq^1 h_ij| = |h_ij^2| = (2, 2 2^j(2^i-1), 2i)
     
     Sq^n: (a, b, c) |-> (a+n, 2b, n*c)?
    */
    
    // XXX: i think B is not quite right.
    
    return [EXTTriple tripleWithA:(location.a+order) B:(location.b*2) C:(location.c*order)];
}

// TODO: should this routine be memoized?
-(EXTMatrix*) squaringMatrix:(int)order location:(EXTTriple*)location {
    // we know the following three facts about the squaring operations:
    // Sq^n(xy) = sum_{i=0}^n Sq^i x Sq^{n-i} y, (Cartan)
    // Sq^0(h_ij) = h_i(j+1),                    (Nakamura on Sq^0)
    // Sq^1(h_ij) = h_ij^2.                      (Definition of Sq^n on n-class)
    //
    // since we're generated by classes of degree 1, this completely determines
    // the squaring structure everywhere, by iteratively splitting apart a
    // square until we get down to just Sq^0s and Sq^1s.
    
    EXTTerm *startTerm = [self findTerm:location],
            *endTerm = [self findTerm:[EXTMaySpectralSequence followSquare:location order:order]];
    EXTMatrix *ret = [EXTMatrix matrixWidth:startTerm.size height:endTerm.size];
    
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
            for (int i = 0; leftover > 0; ) {
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
            
            // if we're not 0 mod 2, then we're 1 mod 2, and we should do it.
            if (!zeroMod2) {
                EXTPolynomialTag *targetTag = [EXTPolynomialTag new];
                
                // start by building the tag we're going to be looking up
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
                }
                
                // find this tag in the target term and poke the value
                NSMutableArray *col = ret.presentation[termIndex];
                int pokeIndex = [endTerm.names indexOfObject:targetTag];
                col[pokeIndex] = @([col[pokeIndex] intValue] + 1);
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
        } while (leftover != order); // cartan loop
    } // term summand loop
    
    return ret;
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
    
    EXTTriple *newSource = [EXTMaySpectralSequence followSquare:location order:order];
    EXTDifferential *diff = [self findDifflWithSource:newSource onPage:(page+order)];
    if (!diff) {
        EXTTerm *start = [self findTerm:newSource],
                *end = [self findTerm:[EXTTriple followDiffl:newSource page:(page+order)]];
        if (!start || !end)
            return;
        
        diff = [EXTDifferential differential:start end:end page:(page+order)];
        [self addDifferential:diff];
    }
    
    // for each partial definition A <-- I --> B, we have two squaring morphisms
    // A --> C and B --> D, which we glue together to get the span
    // C <-- A <-- I --> B --> D.
    for (EXTPartialDefinition *oldPartial in underlyingDiff.partialDefinitions) {
        EXTPartialDefinition *partial = [EXTPartialDefinition new];
        partial.differential = [EXTMatrix newMultiply:[self squaringMatrix:order location:((EXTTriple*)underlyingDiff.end.location)] by:partial.differential];
        partial.inclusion = [EXTMatrix newMultiply:[self squaringMatrix:order location:((EXTTriple*)underlyingDiff.start.location)] by:partial.inclusion];
        [diff.partialDefinitions addObject:partial];
        // TODO: it's not clear that the rest of the code requires the inclusion
        // map to be an inclusion.  if it does, we should insert something to
        // make that so.  otherwise, we shouldn't, since it requires a choice.
    }

    return;
}

-(void) propagateNakamura:(int)page generators:(NSMutableArray*)generators {
    // then propagate with nakamura's lemma / the Cartan formula until exhausted
    
    return;
}

+(EXTMaySpectralSequence*) fillToWidth:(int)width {
    EXTMaySpectralSequence *sseq = (EXTMaySpectralSequence*)[EXTMaySpectralSequence sSeqWithUnit:[EXTTriple class]];
    
    [sseq.zeroRanges addObject:[EXTZeroRangeStrict newWithSSeq:sseq]];
    int last1Index = 0;
    
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
        
        if (i == 1)
            last1Index = [sseq.names count];
    }
    
    // then add their d1 differentials
    for (int index = 0; index < sseq.names.count; index++) {
        EXTMayTag *tag = sseq.names[index];
        int i = tag.i, j = tag.j;
        
        // these elements are genuinely primitive, so never support diff'ls.
        if (i == 1)
            continue;
        
        EXTTriple *location = sseq.locations[index];
        EXTTerm *target = [sseq findTerm:[EXTTriple followDiffl:location page:1]];
        EXTDifferential *diff = [EXTDifferential differential:[sseq findTerm:location] end:target page:1];
        EXTPartialDefinition *partial = [EXTPartialDefinition new];
        partial.inclusion = [EXTMatrix identity:1];
        partial.differential = [EXTMatrix matrixWidth:1 height:target.size];
        
        // the formula for the May d_1 comes straight from the Steenrod
        // diagonal: d_1 h_{i,j} = sum_{k=1}^{i-1} h_{k,i-k+j} h_{i-k,j}
        for (int k = 1; k <= i-1; k++) {
            EXTMayTag *tagLeft = [EXTMayTag tagWithI:k J:(i-k+j)],
                      *tagRight = [EXTMayTag tagWithI:(i-k) J:j];
            int leftIndex = [sseq.names indexOfObject:tagLeft],
                rightIndex = [sseq.names indexOfObject:tagRight];
            EXTMatrix *product = [sseq productWithLeft:sseq.locations[leftIndex] right:sseq.locations[rightIndex]];
            partial.differential = [EXTMatrix sum:partial.differential with:product];
        }
        
        [diff.partialDefinitions addObject:partial];
        [sseq addDifferential:diff];
    }
    
    // propagate the d1 differentials with Leibniz's rule
    [sseq propagateLeibniz:sseq.locations page:1];
    
    [sseq computeGroupsForPage:0];
    [sseq computeGroupsForPage:1];
    [sseq computeGroupsForPage:2];
    
    return sseq;
}

@end
