//
//  EXTDocumentInspectorView.m
//  Ext Chart
//
//  Created by Bavarious on 09/07/2013.
//  Copyright (c) 2013 Harvard University. All rights reserved.
//

#import "EXTDocumentInspectorView.h"


#pragma mark - Private variables

static void *_EXTCollapsedContext = &_EXTCollapsedContext;
static const CGFloat _EXTHorizontalMargin = 10.0; // margin = empty space outside of the group view
static const CGFloat _EXTVerticalMargin = 10.0;
static const CGFloat _EXTHorizontalPadding = 5.0; // padding = empty space inside of the group view
static const CGFloat _EXTHeaderHeight = 30.0;
static const CGFloat _EXTContentTopPadding = 1.0; // space between the header and the content view
static const CGFloat _EXTContentBottomPadding = 5.0;
static NSDictionary *_EXTTitleAttributes = nil;
static NSGradient *_EXTHeaderGradient = nil;

#pragma mark - Private functions

NS_INLINE CGFloat _EXTGroupHeightForContentHeight(CGFloat contentHeight) {
    return _EXTHeaderHeight + _EXTContentTopPadding + contentHeight + _EXTContentBottomPadding;
}

NS_INLINE NSSize _EXTGroupSizeForContentSize(NSSize contentSize) {
    return (NSSize){
        .width = _EXTHorizontalPadding + contentSize.width + _EXTHorizontalPadding,
        .height = _EXTGroupHeightForContentHeight(contentSize.height)
    };
}

@interface EXTDocumentInspectorGroupView : NSView
    @property(nonatomic, readonly) NSView *contentView;
    @property(nonatomic, readonly) NSString *title;
    @property(nonatomic, assign, getter=isCollapsed) bool collapsed;
    @property(nonatomic, assign, getter=isContentCentered) bool contentCentered;
    - (instancetype)initWithFrame:(NSRect)frame
                      contentView:(NSView *)contentView
                            title:(NSString *)title;
@end


@implementation EXTDocumentInspectorView

- (instancetype)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        // add some vertical padding, which will sit at the top of the inspector
        NSSize frameSize = self.frame.size;
        frameSize.height += _EXTVerticalMargin;
        [self setFrameSize:frameSize];
    }
    
    return self;
}

- (void)addSubview:(NSView *)subview withTitle:(NSString *)title collapsed:(bool)collapsed centered:(bool)centered {
    NSSize frameSize = [self frame].size;
    NSRect groupViewFrame = {
        .origin.x = _EXTHorizontalMargin,
        .origin.y = frameSize.height,
        .size = _EXTGroupSizeForContentSize([subview frame].size)
    };

    frameSize.height += groupViewFrame.size.height + _EXTVerticalMargin;
    frameSize.width = MAX(frameSize.width, groupViewFrame.size.width + _EXTHorizontalMargin * 2);
    groupViewFrame.size.width = frameSize.width - _EXTHorizontalMargin * 2;
    [self setFrameSize:frameSize];

    EXTDocumentInspectorGroupView *groupView = [[EXTDocumentInspectorGroupView alloc] initWithFrame:groupViewFrame contentView:subview title:title];
    [groupView setAutoresizingMask:NSViewWidthSizable];
    [self addSubview:groupView];

    [groupView addObserver:self forKeyPath:@"collapsed" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:_EXTCollapsedContext];
    [groupView setCollapsed:collapsed];
    [groupView setContentCentered:centered];
}

- (void)willRemoveSubview:(NSView *)subview {
    [subview removeObserver:self forKeyPath:@"collapsed"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == _EXTCollapsedContext) {
        if ((bool)[change[NSKeyValueChangeOldKey] boolValue] != (bool)[change[NSKeyValueChangeNewKey] boolValue])
            [self _extGroupViewDidCollapse:object];
    }
    else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)_extGroupViewDidCollapse:(EXTDocumentInspectorGroupView *)referenceView {
    CGFloat heightDelta = _EXTGroupHeightForContentHeight([[referenceView contentView] frame].size.height) - _EXTHeaderHeight;
    if ([referenceView isCollapsed])
        heightDelta = -heightDelta;

    NSSize frameSize = [self frame].size;
    frameSize.height += heightDelta;
    [self setFrameSize:frameSize];

    NSUInteger referenceViewIndex = [[self subviews] indexOfObject:referenceView];
    if (referenceViewIndex == [[self subviews] count] - 1)
        return;

    NSIndexSet *affectedIndexes = [NSIndexSet indexSetWithIndexesInRange:(NSRange){referenceViewIndex + 1, [[self subviews] count] - referenceViewIndex - 1}];

    [[self subviews] enumerateObjectsAtIndexes:affectedIndexes options:0 usingBlock:^(NSView *subview, NSUInteger idx, BOOL *stop) {
        NSPoint origin = [subview frame].origin;
        origin.y += heightDelta;
        [subview setFrameOrigin:origin];
    }];
}

- (void)drawRect:(NSRect)dirtyRect {
    [[EXTDocumentInspectorView backgroundColor] setFill];
    NSRectFill(dirtyRect);
}

- (BOOL)isFlipped {
    return YES;
}

- (BOOL)isOpaque {
    return YES;
}

+ (NSColor *)backgroundColor {
    return [NSColor windowBackgroundColor];
}

@end


@implementation EXTDocumentInspectorGroupView

+ (void)initialize {
    if (self == [EXTDocumentInspectorGroupView class]) {
        NSMutableParagraphStyle *titleParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [titleParagraphStyle setAlignment:NSCenterTextAlignment];
        NSShadow *shadow = [[NSShadow alloc] init];
        [shadow setShadowColor:[NSColor whiteColor]];
        [shadow setShadowBlurRadius:0.0];
        [shadow setShadowOffset:(NSSize){0.0, -1.0}];
        _EXTTitleAttributes = @{NSFontAttributeName : [NSFont boldSystemFontOfSize:13.0],
                                NSParagraphStyleAttributeName : titleParagraphStyle,
                                NSShadowAttributeName : shadow};
        _EXTHeaderGradient = [[NSGradient alloc] initWithColorsAndLocations:
                              [NSColor colorWithCalibratedWhite:0.953 alpha:1.0], 0.0,
                              [NSColor colorWithCalibratedWhite:0.929 alpha:1.0], 0.3,
                              [NSColor colorWithCalibratedWhite:0.800 alpha:1.0], 1.0,
                              nil];
    }
}

- (instancetype)initWithFrame:(NSRect)frame
                  contentView:(NSView *)contentView
                        title:(NSString *)title {
    self = [super initWithFrame:frame];
    if (self) {
        _contentView = contentView;

        NSSize contentSize = [contentView frame].size;
        if ([_contentView autoresizingMask] & NSViewWidthSizable)
            contentSize.width = frame.size.width - _EXTHorizontalPadding * 2;
        [contentView setFrameSize:contentSize];
        [self _extLayoutContentFrame];
        [self addSubview:contentView];

        _title = [title copy];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(frameDidChange:) name:NSViewFrameDidChangeNotification object:self];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:self];
}

- (void)mouseDown:(NSEvent *)event {
    [super mouseDown:event];
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    if (NSPointInRect(location, [self _extHeaderFrame]))
        [self setCollapsed:!_collapsed];
}

- (void)setCollapsed:(bool)collapsed {
    if (collapsed != _collapsed) {
        NSSize targetSize = [self frame].size;
        targetSize.height = collapsed ? _EXTHeaderHeight : _EXTGroupSizeForContentSize([_contentView frame].size).height;

        _collapsed = collapsed;
        [self setFrameSize:targetSize];
    }
}

- (void)_extLayoutContentFrame {
    const NSRect bounds = [self bounds];
    const NSPoint contentOrigin = {
        .x = (_contentCentered ?
              floor(NSMinX(bounds) + (bounds.size.width - [_contentView frame].size.width) / 2) :
              floor(NSMinX(bounds) + _EXTHorizontalPadding)),
        .y = _EXTHeaderHeight + _EXTContentTopPadding
    };

    [_contentView setFrameOrigin:contentOrigin];
}

- (void)setContentCentered:(bool)contentCentered {
    if (contentCentered != _contentCentered) {
        _contentCentered = contentCentered;
        [self _extLayoutContentFrame];
    }
}

- (void)frameDidChange:(NSNotification *)notification {
    [self _extLayoutContentFrame];
}

- (void)resetCursorRects {
    [self addCursorRect:[self _extHeaderFrame] cursor:[NSCursor pointingHandCursor]];
}

- (void)drawRect:(NSRect)dirtyRect {
    const NSRect bounds = [self bounds];
    const CGFloat borderWidth = 1.0;
    NSColor *borderColor = [NSColor colorWithCalibratedWhite:0.4 alpha:1.0];

    // Border clip
    NSBezierPath *borderPath = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bounds, borderWidth / 2, borderWidth / 2) xRadius:5.0 yRadius:5.0];
    [borderPath setLineWidth:borderWidth];
    [borderPath addClip];
    {
        // Header
        const NSRect headerFrame = [self _extHeaderFrame];
        if (NSIntersectsRect(dirtyRect, headerFrame)) {
            [_EXTHeaderGradient drawInRect:headerFrame angle:90];

            NSRect headerBorderFrame, dummyRect;
            NSDivideRect(headerFrame, &headerBorderFrame, &dummyRect, 1.0, NSMaxYEdge);
            headerBorderFrame = NSInsetRect(headerBorderFrame, 0.5, 0.5);
            NSBezierPath *headerBottomBorder = [NSBezierPath bezierPathWithRect:headerBorderFrame];
            [headerBottomBorder setLineWidth:1.0];
            [[NSColor lightGrayColor] setStroke];
            [headerBottomBorder stroke];

            headerBorderFrame.origin.y += 1.0;
            headerBottomBorder = [NSBezierPath bezierPathWithRect:headerBorderFrame];
            [headerBottomBorder setLineWidth:1.0];
            [[NSColor whiteColor] setStroke];
            [headerBottomBorder stroke];

            // Header title
            [_title drawInRect:NSInsetRect(headerFrame, 5.0, 5.0) withAttributes:_EXTTitleAttributes];
        }
    }
    // Border drawing
    [borderColor setStroke];
    [borderPath stroke];
}

- (NSRect)_extHeaderFrame {
    return (NSRect){NSZeroPoint, {[self bounds].size.width, _EXTHeaderHeight}};
}

- (BOOL)isFlipped {
    return YES;
}

@end
