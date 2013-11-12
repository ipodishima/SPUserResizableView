//
//  SPUserResizableView.m
//  SPUserResizableView
//
//  Created by Stephen Poletto on 12/10/11.
//

#import "SPUserResizableView.h"
#import "LayerView.h"

/* Let's inset everything that's drawn (the handles and the content view)
   so that users can trigger a resize from a few pixels outside of
   what they actually see as the bounding box. */
#define kSPUserResizableViewGlobalInset 5.0

#define kSPUserResizableViewDefaultMinWidth 48.0
#define kSPUserResizableViewDefaultMinHeight 48.0
#define kSPUserResizableViewInteractiveBorderSize 10.0

#define kMinWidth @"kMinWidth"
#define kMinHeight @"kMinHeight"
#define kStrokeColor @"kStrokeColor"
#define kFillColor @"kFillColor"
#define kLineWidth @"kLineWidth"
#define kShape @"kShape"

static SPUserResizableViewAnchorPoint SPUserResizableViewNoResizeAnchorPoint = { 0.0, 0.0, 0.0, 0.0 };
static SPUserResizableViewAnchorPoint SPUserResizableViewUpperLeftAnchorPoint = { 1.0, 1.0, -1.0, 1.0 };
static SPUserResizableViewAnchorPoint SPUserResizableViewMiddleLeftAnchorPoint = { 1.0, 0.0, 0.0, 1.0 };
static SPUserResizableViewAnchorPoint SPUserResizableViewLowerLeftAnchorPoint = { 1.0, 0.0, 1.0, 1.0 };
static SPUserResizableViewAnchorPoint SPUserResizableViewUpperMiddleAnchorPoint = { 0.0, 1.0, -1.0, 0.0 };
static SPUserResizableViewAnchorPoint SPUserResizableViewUpperRightAnchorPoint = { 0.0, 1.0, -1.0, -1.0 };
static SPUserResizableViewAnchorPoint SPUserResizableViewMiddleRightAnchorPoint = { 0.0, 0.0, 0.0, -1.0 };
static SPUserResizableViewAnchorPoint SPUserResizableViewLowerRightAnchorPoint = { 0.0, 0.0, 1.0, -1.0 };
static SPUserResizableViewAnchorPoint SPUserResizableViewLowerMiddleAnchorPoint = { 0.0, 0.0, 1.0, 0.0 };

static CGFloat PointWidth = 10.0;

@interface UIBezierPath (dqd_arrowhead)

+ (UIBezierPath *)dqd_bezierPathWithArrowFromPoint:(CGPoint)startPoint
                                           toPoint:(CGPoint)endPoint
                                         tailWidth:(CGFloat)tailWidth
                                         headWidth:(CGFloat)headWidth
                                        headLength:(CGFloat)headLength;

@end

@interface SPUserResizableView ()
@property (nonatomic, strong) UIView *oldSuperview;
@property (nonatomic) NSInteger oldSuperviewIndex;
@end

@implementation SPUserResizableView
@synthesize strokeColor = _strokeColor, fillColor = _fillColor, textColor = _textColor, font = _font, lineWidth = _lineWidth, editing = _editing, delegate = _delegatel;

- (void)setupDefaultAttributes {
    self.minWidth = kSPUserResizableViewDefaultMinWidth;
    self.minHeight = kSPUserResizableViewDefaultMinHeight;
    self.preventsPositionOutsideSuperview = YES;
    
    self.strokeColor = [UIColor colorWithHexa:0xC7000D];
    self.fillColor = [UIColor whiteColor];
    self.lineWidth = 2.0;
    self.shape = SPShapeRect;
    
    self.backgroundColor = [UIColor clearColor];
    
    self.editing = YES;
}

- (void)setupDefaultValues
{
    
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self setupDefaultAttributes];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        [self setupDefaultAttributes];
        
        self.minWidth = [aDecoder decodeFloatForKey:kMinWidth];
        self.minHeight = [aDecoder decodeFloatForKey:kMinHeight];
        self.strokeColor = [UIColor colorWithString:[aDecoder decodeObjectForKey:kStrokeColor]];
        self.fillColor = [UIColor colorWithString:[aDecoder decodeObjectForKey:kFillColor]];
        self.lineWidth = [aDecoder decodeFloatForKey:kLineWidth];
        self.shape = [aDecoder decodeIntegerForKey:kShape];
        self.editing = NO;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    
    [aCoder encodeFloat:self.minWidth forKey:kMinWidth];
    [aCoder encodeFloat:self.minHeight forKey:kMinHeight];
    [aCoder encodeObject:[self.strokeColor stringFromColor] forKey:kStrokeColor];
    [aCoder encodeObject:[self.fillColor stringFromColor] forKey:kFillColor];
    [aCoder encodeFloat:self.lineWidth forKey:kLineWidth];
    [aCoder encodeInteger:self.shape forKey:kShape];
}

- (id)initWithFrame:(CGRect)frame andDelegate:(id<DToolDelegate>)delegate
{
    if ((self = [super initWithFrame:frame])) {
        [self setupDefaultAttributes];
        self.delegate = delegate;
    }
    return self;
}

- (void) draw
{
    [self setNeedsDisplay];
}

- (void)setContentView:(UIView *)newContentView {
    [_contentView removeFromSuperview];
    _contentView = newContentView;
    _contentView.frame = CGRectInset(self.bounds, kSPUserResizableViewGlobalInset + kSPUserResizableViewInteractiveBorderSize/2, kSPUserResizableViewGlobalInset + kSPUserResizableViewInteractiveBorderSize/2);
    [self addSubview:_contentView];
}

- (void)setFrame:(CGRect)newFrame {
    [super setFrame:newFrame];
    _contentView.frame = CGRectInset(self.bounds, kSPUserResizableViewGlobalInset + kSPUserResizableViewInteractiveBorderSize/2, kSPUserResizableViewGlobalInset + kSPUserResizableViewInteractiveBorderSize/2);
}

static CGFloat SPDistanceBetweenTwoPoints(CGPoint point1, CGPoint point2) {
    CGFloat dx = point2.x - point1.x;
    CGFloat dy = point2.y - point1.y;
    return sqrt(dx*dx + dy*dy);
};

typedef struct CGPointSPUserResizableViewAnchorPointPair {
    CGPoint point;
    SPUserResizableViewAnchorPoint anchorPoint;
} CGPointSPUserResizableViewAnchorPointPair;

- (SPUserResizableViewAnchorPoint)anchorPointForTouchLocation:(CGPoint)touchPoint {
    // (1) Calculate the positions of each of the anchor points.
    CGPointSPUserResizableViewAnchorPointPair upperLeft = { CGPointMake(0.0, 0.0), SPUserResizableViewUpperLeftAnchorPoint };
    CGPointSPUserResizableViewAnchorPointPair upperMiddle = { CGPointMake(self.bounds.size.width/2, 0.0), SPUserResizableViewUpperMiddleAnchorPoint };
    CGPointSPUserResizableViewAnchorPointPair upperRight = { CGPointMake(self.bounds.size.width, 0.0), SPUserResizableViewUpperRightAnchorPoint };
    CGPointSPUserResizableViewAnchorPointPair middleRight = { CGPointMake(self.bounds.size.width, self.bounds.size.height/2), SPUserResizableViewMiddleRightAnchorPoint };
    CGPointSPUserResizableViewAnchorPointPair lowerRight = { CGPointMake(self.bounds.size.width, self.bounds.size.height), SPUserResizableViewLowerRightAnchorPoint };
    CGPointSPUserResizableViewAnchorPointPair lowerMiddle = { CGPointMake(self.bounds.size.width/2, self.bounds.size.height), SPUserResizableViewLowerMiddleAnchorPoint };
    CGPointSPUserResizableViewAnchorPointPair lowerLeft = { CGPointMake(0, self.bounds.size.height), SPUserResizableViewLowerLeftAnchorPoint };
    CGPointSPUserResizableViewAnchorPointPair middleLeft = { CGPointMake(0, self.bounds.size.height/2), SPUserResizableViewMiddleLeftAnchorPoint };
    CGPointSPUserResizableViewAnchorPointPair centerPoint = { CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2), SPUserResizableViewNoResizeAnchorPoint };
    
    // (2) Iterate over each of the anchor points and find the one closest to the user's touch.
    CGPointSPUserResizableViewAnchorPointPair allPoints[9] = { upperLeft, upperRight, lowerRight, lowerLeft, upperMiddle, lowerMiddle, middleLeft, middleRight, centerPoint };
    CGFloat smallestDistance = MAXFLOAT; CGPointSPUserResizableViewAnchorPointPair closestPoint = centerPoint;
    for (NSInteger i = 0; i < 9; i++) {
        CGFloat distance = SPDistanceBetweenTwoPoints(touchPoint, allPoints[i].point);
        if (distance < smallestDistance) { 
            closestPoint = allPoints[i];
            smallestDistance = distance;
        }
    }
    return closestPoint.anchorPoint;
}

- (BOOL)isResizing {
    return (anchorPoint.adjustsH || anchorPoint.adjustsW || anchorPoint.adjustsX || anchorPoint.adjustsY);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    // Notify the delegate we've begun our editing session.
    if (self.spDelegate && [self.spDelegate respondsToSelector:@selector(userResizableViewDidBeginEditing:)]) {
        [self.spDelegate userResizableViewDidBeginEditing:self];
    }
    self.editing = YES;
    [self.delegate toolDidStartEditing:self];

    UITouch *touch = [touches anyObject];
    anchorPoint = [self anchorPointForTouchLocation:[touch locationInView:self]];
    
    // When resizing, all calculations are done in the superview's coordinate space.
    _touchStart = [touch locationInView:self.superview];
    if (![self isResizing]) {
        // When translating, all calculations are done in the view's coordinate space.
        _touchStart = [touch locationInView:self];
    }
    
    [self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    // Notify the delegate we've ended our editing session.
    if (self.spDelegate && [self.spDelegate respondsToSelector:@selector(userResizableViewDidEndEditing:)]) {
        [self.spDelegate userResizableViewDidEndEditing:self];
    }
    [self.delegate toolDidStopEditing:self];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    // Notify the delegate we've ended our editing session.
    if (self.spDelegate && [self.spDelegate respondsToSelector:@selector(userResizableViewDidEndEditing:)]) {
        [self.spDelegate userResizableViewDidEndEditing:self];
    }
    [self.delegate toolDidStopEditing:self];
}

- (void)resizeUsingTouchLocation:(CGPoint)touchPoint {
    // (1) Update the touch point if we're outside the superview.
    if (self.preventsPositionOutsideSuperview) {
        CGFloat border = kSPUserResizableViewGlobalInset + kSPUserResizableViewInteractiveBorderSize/2;
        if (touchPoint.x < border) {
            touchPoint.x = border;
        }
        if (touchPoint.x > self.superview.bounds.size.width - border) {
            touchPoint.x = self.superview.bounds.size.width - border;
        }
        if (touchPoint.y < border) {
            touchPoint.y = border;
        }
        if (touchPoint.y > self.superview.bounds.size.height - border) {
            touchPoint.y = self.superview.bounds.size.height - border;
        }
    }
    
    // (2) Calculate the deltas using the current anchor point.
    CGFloat deltaW = anchorPoint.adjustsW * (_touchStart.x - touchPoint.x);
    CGFloat deltaX = anchorPoint.adjustsX * (-1.0 * deltaW);
    CGFloat deltaH = anchorPoint.adjustsH * (touchPoint.y - _touchStart.y);
    CGFloat deltaY = anchorPoint.adjustsY * (-1.0 * deltaH);
    
    // (3) Calculate the new frame.
    CGFloat newX = self.frame.origin.x + deltaX;
    CGFloat newY = self.frame.origin.y + deltaY;
    CGFloat newWidth = self.frame.size.width + deltaW;
    CGFloat newHeight = self.frame.size.height + deltaH;
    
    // (4) If the new frame is too small, cancel the changes.
    if (newWidth < self.minWidth) {
        newWidth = self.frame.size.width;
        newX = self.frame.origin.x;
    }
    if (newHeight < self.minHeight) {
        newHeight = self.frame.size.height;
        newY = self.frame.origin.y;
    }
    
    // (5) Ensure the resize won't cause the view to move offscreen.
    if (self.preventsPositionOutsideSuperview) {
        if (newX < self.superview.bounds.origin.x) {
            // Calculate how much to grow the width by such that the new X coordintae will align with the superview.
            deltaW = self.frame.origin.x - self.superview.bounds.origin.x;
            newWidth = self.frame.size.width + deltaW;
            newX = self.superview.bounds.origin.x;
        }
        if (newX + newWidth > self.superview.bounds.origin.x + self.superview.bounds.size.width) {
            newWidth = self.superview.bounds.size.width - newX;
        }
        if (newY < self.superview.bounds.origin.y) {
            // Calculate how much to grow the height by such that the new Y coordintae will align with the superview.
            deltaH = self.frame.origin.y - self.superview.bounds.origin.y;
            newHeight = self.frame.size.height + deltaH;
            newY = self.superview.bounds.origin.y;
        }
        if (newY + newHeight > self.superview.bounds.origin.y + self.superview.bounds.size.height) {
            newHeight = self.superview.bounds.size.height - newY;
        }
    }
    
    self.frame = CGRectMake(newX, newY, newWidth, newHeight);
    _touchStart = touchPoint;
    [self setNeedsDisplay];
}

- (void)translateUsingTouchLocation:(CGPoint)touchPoint {
    CGPoint newCenter = CGPointMake(self.center.x + touchPoint.x - _touchStart.x, self.center.y + touchPoint.y - _touchStart.y);
    if (self.preventsPositionOutsideSuperview) {
        // Ensure the translation won't cause the view to move offscreen.
        CGFloat midPointX = CGRectGetMidX(self.bounds);
        if (newCenter.x > self.superview.bounds.size.width - midPointX) {
            newCenter.x = self.superview.bounds.size.width - midPointX;
        }
        if (newCenter.x < midPointX) {
            newCenter.x = midPointX;
        }
        CGFloat midPointY = CGRectGetMidY(self.bounds);
        if (newCenter.y > self.superview.bounds.size.height - midPointY) {
            newCenter.y = self.superview.bounds.size.height - midPointY;
        }
        if (newCenter.y < midPointY) {
            newCenter.y = midPointY;
        }
    }
    self.center = newCenter;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if ([self isResizing]) {
        [self resizeUsingTouchLocation:[[touches anyObject] locationInView:self.superview]];
    } else {
        [self translateUsingTouchLocation:[[touches anyObject] locationInView:self]];
    }
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    
    // (1) Draw the bounding box.
    CGContextSetLineWidth(context, self.lineWidth);
    CGContextSetStrokeColorWithColor(context, self.strokeColor.CGColor);
    CGContextSetFillColorWithColor(context, self.fillColor.CGColor);
   
    CGRect borderRect = CGRectInset(self.bounds, kSPUserResizableViewInteractiveBorderSize/2, kSPUserResizableViewInteractiveBorderSize/2);

    switch (self.shape) {
        case SPShapeRect:
            CGContextFillRect(context, borderRect);
            CGContextStrokeRect(context, borderRect);
            break;
        case SPShapeEllipse:
            CGContextFillEllipseInRect(context, borderRect);
            CGContextStrokeEllipseInRect(context, borderRect);
            break;
            case SPShapeArrow:
        {
            CGPoint startPoint = CGPointMake((self.bounds.size.width)/2, self.bounds.size.height - kSPUserResizableViewInteractiveBorderSize);
            CGPoint stopPoint = CGPointMake((self.bounds.size.width )/2, +kSPUserResizableViewInteractiveBorderSize);
            CGFloat height = CGRectGetHeight(borderRect);
            CGFloat width = CGRectGetWidth(borderRect);
            
            UIBezierPath *path = [UIBezierPath dqd_bezierPathWithArrowFromPoint:startPoint
                                                          toPoint:stopPoint
                                                        tailWidth:0.2*width
                                                        headWidth:width
                                                       headLength:0.3*height];
            [path fill];
            [path stroke];
        }
            break;
        default:
            break;
    }
    
    if (_editing)
    {
        // (2) Calculate the bounding boxes for each of the anchor points.
        CGPoint upperLeft = CGPointMake(0.0, 0.0);
        CGPoint upperRight = CGPointMake(self.bounds.size.width - kSPUserResizableViewInteractiveBorderSize, 0.0);
        CGPoint lowerRight = CGPointMake(self.bounds.size.width - kSPUserResizableViewInteractiveBorderSize, self.bounds.size.height - kSPUserResizableViewInteractiveBorderSize);
        CGPoint lowerLeft = CGPointMake(0.0, self.bounds.size.height - kSPUserResizableViewInteractiveBorderSize);
        CGPoint upperMiddle = CGPointMake((self.bounds.size.width - kSPUserResizableViewInteractiveBorderSize)/2, 0.0);
        CGPoint lowerMiddle = CGPointMake((self.bounds.size.width - kSPUserResizableViewInteractiveBorderSize)/2, self.bounds.size.height - kSPUserResizableViewInteractiveBorderSize);
        CGPoint middleLeft = CGPointMake(0.0, (self.bounds.size.height - kSPUserResizableViewInteractiveBorderSize)/2);
        CGPoint middleRight = CGPointMake(self.bounds.size.width - kSPUserResizableViewInteractiveBorderSize, (self.bounds.size.height - kSPUserResizableViewInteractiveBorderSize)/2);

        NSMutableArray *allPoints = nil;
        
        switch (self.shape) {
            case SPShapeRect:
            case SPShapeArrow:
                allPoints = [NSMutableArray arrayWithObjects:
                             [NSValue valueWithCGPoint:upperLeft],
                             [NSValue valueWithCGPoint:upperRight],
                             [NSValue valueWithCGPoint:lowerRight],
                             [NSValue valueWithCGPoint:lowerLeft],
                             [NSValue valueWithCGPoint:upperMiddle],
                             [NSValue valueWithCGPoint:lowerMiddle],
                             [NSValue valueWithCGPoint:middleLeft],
                             [NSValue valueWithCGPoint:middleRight], nil];
                break;
            case SPShapeEllipse:
                allPoints = [NSMutableArray arrayWithObjects:
                             [NSValue valueWithCGPoint:upperMiddle],
                             [NSValue valueWithCGPoint:lowerMiddle],
                             [NSValue valueWithCGPoint:middleLeft],
                             [NSValue valueWithCGPoint:middleRight], nil];
                break;
            default:
                break;
        }
        // (5) Fill each anchor point using the gradient, then stroke the border.
        for (NSValue *v in allPoints) {
            [self drawPointOnContext:context forPoint:[v CGPointValue]];
        }
    }
    CGContextRestoreGState(context);
}

- (void) drawPointOnContext:(CGContextRef)context forPoint:(CGPoint)point
{
    CGContextSaveGState(context);
    CGPoint onSizePoint = point;
    CGMutablePathRef circlePath = CGPathCreateMutable();
    CGPathAddEllipseInRect(circlePath, NULL, CGRectMake(onSizePoint.x, onSizePoint.y, PointWidth, PointWidth));
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextSetLineWidth(context, 1.0);
    
    CGContextAddPath(context, circlePath);
    CGContextFillPath(context);
    CGContextAddPath(context, circlePath);
    CGContextStrokePath(context);
    CGPathRelease(circlePath);
    CGContextRestoreGState(context);
}

- (void)dealloc {
    [_contentView removeFromSuperview];
}

#pragma mark - DTool protocol
// undo / redo
- (BOOL)canUndo
{
    return self.superview == nil ? NO : YES;
}

- (void)undoLatestStep
{
    if ([self canUndo]) {
        self.oldSuperview = self.superview;
        self.oldSuperviewIndex = [[self.superview subviews] indexOfObject:self];
        [self removeFromSuperview];
    }
}

- (BOOL)canRedo
{
    return self.superview == nil ? YES : NO;
}

- (void)redoLatestStep
{
    if ([self canRedo]) {
        [self.oldSuperview insertSubview:self atIndex:self.oldSuperviewIndex];
        self.oldSuperview = nil;
    }
}

- (void) finalizeUndoRedo
{
    self.oldSuperview = nil;
}

- (void)setEditing:(BOOL)editing
{
    _editing = editing;
    [self setNeedsDisplay];
    
    if (_editing) {
        [self.delegate toolDidStartEditing:self];
    }
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    BOOL canAcceptTouches = NO;
    
    if (!self.editing && CGRectContainsPoint(self.frame, point)) {
        canAcceptTouches = YES;
    }
    
    if (!canAcceptTouches)
    {
        self.editing = NO;
    }
    return canAcceptTouches;
}

@end

#define kArrowPointCount 7

@implementation UIBezierPath (dqd_arrowhead)

+ (UIBezierPath *)dqd_bezierPathWithArrowFromPoint:(CGPoint)startPoint
                                           toPoint:(CGPoint)endPoint
                                         tailWidth:(CGFloat)tailWidth
                                         headWidth:(CGFloat)headWidth
                                        headLength:(CGFloat)headLength {
    CGFloat length = hypotf(endPoint.x - startPoint.x, endPoint.y - startPoint.y);
    
    CGPoint points[kArrowPointCount];
    [self dqd_getAxisAlignedArrowPoints:points
                              forLength:length
                              tailWidth:tailWidth
                              headWidth:headWidth
                             headLength:headLength];
    
    CGAffineTransform transform = [self dqd_transformForStartPoint:startPoint
                                                          endPoint:endPoint
                                                            length:length];
    
    CGMutablePathRef cgPath = CGPathCreateMutable();
    CGPathAddLines(cgPath, &transform, points, sizeof points / sizeof *points);
    CGPathCloseSubpath(cgPath);
    
    UIBezierPath *uiPath = [UIBezierPath bezierPathWithCGPath:cgPath];
    CGPathRelease(cgPath);
    return uiPath;
}

+ (void)dqd_getAxisAlignedArrowPoints:(CGPoint[kArrowPointCount])points
                            forLength:(CGFloat)length
                            tailWidth:(CGFloat)tailWidth
                            headWidth:(CGFloat)headWidth
                           headLength:(CGFloat)headLength {
    CGFloat tailLength = length - headLength;
    points[0] = CGPointMake(0, tailWidth / 2);
    points[1] = CGPointMake(tailLength, tailWidth / 2);
    points[2] = CGPointMake(tailLength, headWidth / 2);
    points[3] = CGPointMake(length, 0);
    points[4] = CGPointMake(tailLength, -headWidth / 2);
    points[5] = CGPointMake(tailLength, -tailWidth / 2);
    points[6] = CGPointMake(0, -tailWidth / 2);
}

+ (CGAffineTransform)dqd_transformForStartPoint:(CGPoint)startPoint
                                       endPoint:(CGPoint)endPoint
                                         length:(CGFloat)length {
    CGFloat cosine = (endPoint.x - startPoint.x) / length;
    CGFloat sine = (endPoint.y - startPoint.y) / length;
    return (CGAffineTransform){ cosine, sine, -sine, cosine, startPoint.x, startPoint.y };
}

@end