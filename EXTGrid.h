//
//  EXTGrid.h
//  Ext Chart
//
//  Created by Michael Hopkins on 7/20/11.
//  Copyright 2011 Harvard University. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface EXTGrid : NSObject

@property(nonatomic, strong) NSColor *gridColor, *emphasisGridColor, *axisColor;
@property(nonatomic, assign) CGFloat gridSpacing;
@property(nonatomic, assign) NSInteger emphasisSpacing;
@property(nonatomic, assign) NSRect boundsRect;
@property(nonatomic, strong) NSBezierPath *gridPath, *emphasisGridPath;

// Drawing
-(NSBezierPath *) makeGridInRect: (NSRect) rect withFactor:(NSUInteger) factor;

- (void) drawGridInRect:(NSRect)rect;
- (void) drawGrid;
- (void) drawAxes;

- (void) drawEnclosingRectAtPoint: (NSPoint)point;

/*! Given a view point, returns the grid point representing the origin of the grid square containing that view point */
- (EXTIntPoint)convertPointFromView:(NSPoint)viewPoint;

/*! Given a view point, returns the grid point nearest to that view point */
- (EXTIntPoint)nearestGridPoint:(NSPoint)viewPoint;

/*! Given a grid point, returns the corresponding point in view coordinate space */
- (NSPoint)convertPointToView:(EXTIntPoint)gridPoint;

/*! Given a grid point, returns a grid square rectangle in view coordinate space whose origin matches the grid point */
- (NSRect)viewBoundingRectForGridPoint:(EXTIntPoint)gridSquareOrigin;
@end

#pragma mark - Public variables

extern NSString * const EXTGridAnyKey;

extern NSString * const EXTGridColorPreferenceKey;
extern NSString * const EXTGridSpacingPreferenceKey;
extern NSString * const EXTGridEmphasisColorPreferenceKey;
extern NSString * const EXTGridEmphasisSpacingPreferenceKey;
extern NSString * const EXTGridAxisColorPreferenceKey;
