//
//  EXTDocument.m
//  Ext Chart
//
//  Created by Michael Hopkins on 7/20/11.
//  Copyright 2011 Harvard. All rights reserved.
//

#import "EXTDocument.h"
#import "EXTView.h"
#import "EXTGrid.h"
#import "EXTArtBoard.h"
#import "EXTterm.h"
#import "EXTPair.h"

@implementation EXTDocument

@synthesize artboardRectX;
@synthesize theArtBoard;
@synthesize theGrid;
@synthesize maxPage;
@synthesize terms, differentials;
#pragma mark *** initialization and dealloc ***

- (id)init {
    // upcall.
    self = [super init];
    
    // if we succeeded...
    if (self) {
        // allocate the display parts of things
		theArtBoard = [EXTArtBoard alloc];
		[theArtBoard initWithRect:NSMakeRect(0, 0, 792, 612)];
        
        // and allocate the internal parts of things
        terms = [[NSMutableArray alloc] init];
        differentials = [[NSMutableArray alloc] init];
    }

    return self;
}

// if requested, we can initialize the terms array with some test garbage
-(void) randomize {
    // remove all the old garbage
    [terms release];
    terms = [[NSMutableArray alloc] init];
    
    // add some new garbage.
    // TODO: this ought to randomize the dimension too.
    // XXX: this doesn't catch collisions.
    for(int i = 0; i < 40; i++) {
        EXTPair *location = [EXTPair pairWithA:(arc4random()%30)
                                             B:(arc4random()%30)];
        EXTTerm *term = [EXTTerm newTerm:location
                                andNames:[[NSMutableArray alloc] initWithObjects:@"x",nil]];
        [terms addObject:term];
    }
}

- (void) dealloc {
	[super dealloc];
}

#pragma mark *** windowController tasks ***

- (NSString *)windowNibName
{
    return @"EXTDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
	// the big board is the bounds rectangle of the EXTView object, and is set in the xib file, so we initialize theGrid in the windowControllerDidLoadNib function.   HOWEVER, it screws up the binding of the text cell on the main document.  see the console
	
//	theGrid = [EXTGrid alloc];
//	[theGrid initWithRect:[extview bounds]];
	
	[theGrid setBoundsRect:[extview bounds]];
	
// The analogue of these next settings 	 are done with bindings in Sketch.   I'm not sure what the difference is.
	[extview setDelegate:self];
	[extview setArtBoard:theArtBoard];
	[extview set_grid:theGrid];
	
// since the frame extends past the bounds rectangle, we need observe the drawingRect in order to know what to refresh when the artBoard changes
	
	[theArtBoard addObserver: extview forKeyPath:EXTArtBoardDrawingRectKey options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
	[theGrid addObserver:extview forKeyPath:EXTGridAnyKey options:0 context:nil];

//	[self setEmphasisGridSpacing:8];		
}

#pragma mark ***document saving and loading / TODO: THESE ARE DISABLED ***

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    if ( outError != NULL ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	}
//	return[NSKeyedArchiver archivedDataWithRootObject:[self pages]];
    return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	if ( outError != NULL ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	}
	
	NSArray* arr = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	NSMutableArray* marr = [arr mutableCopy];
	
//	[self setPages:marr];
	[marr release];
    return YES;
}

#pragma mark ***Drawing***

// this performs the culling and delegation calls for drawing a page of the SS
// TODO: does this need spacing to be passed in?  probably a lot of data passing
// needs to be investigated and untangled... :(
-(void) drawPageNumber:(NSUInteger)pageNumber ll:(EXTPair*)lowerLeft
                    ur:(EXTPair*)upperRight withSpacing:(CGFloat)withSpacing {
    
    // iterate through the available terms
    for (EXTTerm *term in [self terms]) {
        // if we're out of the viewing rectangle, then skip it
        if (([[term location] a] <= [lowerLeft a])  ||
            ([[term location] b] <= [lowerLeft b])  ||
            ([[term location] a] >= [upperRight a]) ||
            ([[term location] b] >= [upperRight b]))
            continue;
        
        // otherwise, we're obligated to try to draw it
        // TODO: this still seems like it's put in the wrong place...
        [term drawWithSpacing:withSpacing];
    }
    
    // iterate also through the available differentials
    for (EXTdifferential* differential in [self differentials]) {
        // eventually try to draw these.
        //
        // [differential drawWithSpacing:gridSpacing];
    }
}

-(void)drawPagesUpTo: (NSUInteger) pageNumber {
	;
}

#pragma mark ***view customization***

-(NSUInteger) maxPage {
//	return [pages count] - 1;
    return 0; // XXX: what is this used for? fix it!
}

#pragma mark ***probably controller methods ****



@end
