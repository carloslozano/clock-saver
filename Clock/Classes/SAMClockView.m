//
//  SAMClockView.m
//  Clock
//
//  Created by Sam Soffes on 3/8/14.
//  Copyright (c) 2014 Sam Soffes. All rights reserved.
//

#import "SAMClockView.h"
#import "SAMClockConfigureWindowController.h"

NSString *const SAMClockConfigurationDidChangeNotificationName = @"SAMClockConfigurationDidChangeNotification";
NSString *const SAMClockDefaultsModuleName = @"com.samsoffes.clock";
NSString *const SAMClockStyleDefaultsKey = @"SAMClockStyle";
NSString *const SAMClockTickMarksDefaultsKey = @"SAMClockTickMarks";
NSString *const SAMClockNumbersDefaultsKey = @"SAMClockNumbers";

@interface SAMClockView ()
@property (nonatomic, readonly) SAMClockConfigureWindowController *configureWindowController;
@end

@implementation SAMClockView

#pragma mark - Accessors

@synthesize configureWindowController = _configureWindowController;

- (SAMClockConfigureWindowController *)configureWindowController {
	if (!_configureWindowController) {
		_configureWindowController = [[SAMClockConfigureWindowController alloc] init];
		[_configureWindowController loadWindow];
	}
	return _configureWindowController;
}


#pragma mark - NSObject

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - ScreenSaverView

- (id)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
	if ((self = [super initWithFrame:frame isPreview:isPreview])) {
		[self setAnimationTimeInterval:1.0 / 4.0];
		self.wantsLayer = YES;

		ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:SAMClockDefaultsModuleName];
		[defaults registerDefaults:@{
			SAMClockTickMarksDefaultsKey: @YES,
//			SAMClockNumbersDefaultsKey: @YES
		}];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(configurationDidChange:) name:SAMClockConfigurationDidChangeNotificationName object:nil];
		[self configurationDidChange:nil];
	}
	return self;
}


- (void)startAnimation {
    [super startAnimation];
}


- (void)stopAnimation {
    [super stopAnimation];
}


- (void)drawRect:(NSRect)rect {
    [super drawRect:rect];

	CGSize size = rect.size;

	NSColor *handColor;
	NSColor *backgroundColor;
	NSColor *clockBackgroundColor;
	NSColor *secondsColor = [NSColor colorWithCalibratedRed:0.965 green:0.773 blue:0.180 alpha:1];

	if (self.clockStyle == SAMClockViewStyleLightFace) {
		backgroundColor = [NSColor blackColor];
		handColor = [NSColor colorWithCalibratedRed:0.039f green:0.039f blue:0.043f alpha:1.0f];
		clockBackgroundColor = [NSColor colorWithCalibratedRed:0.996f green:0.996f blue:0.996f alpha:1.0f];
	} else {
		backgroundColor = [NSColor whiteColor];
		handColor = [NSColor colorWithCalibratedRed:0.988f green:0.992f blue:0.988f alpha:1.0f];
		clockBackgroundColor = [NSColor colorWithCalibratedRed:0.129f green:0.125f blue:0.141f alpha:1.0f];
	}

	// Screen background
	[backgroundColor setFill];
	[NSBezierPath fillRect:rect];

	// Clock background
	[clockBackgroundColor setFill];
	CGRect frame = [self clockFrameForBounds:self.bounds];
	CGFloat width = frame.size.width;
	NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:frame];
	path.lineWidth = 4.0f;
	[path fill];

	CGFloat twoPi = M_PI * 2.0f;
	CGFloat angleOffset = M_PI_2;
	CGPoint center = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));

	if (self.drawsTicks) {
		// Ticks divider
		CGFloat dividerPosition = 0.074960128f;
		[[backgroundColor colorWithAlphaComponent:0.05f] setStroke];
		path = [NSBezierPath bezierPathWithOvalInRect:CGRectInset(frame, frame.size.width * dividerPosition, frame.size.width * dividerPosition)];
		path.lineWidth = 1.0f;
		[path stroke];

		// Ticks
		CGFloat tickLength = ceilf(width * -0.049441786f);
		CGFloat tickRadius = ceilf(width * 0.437799043f);
		for (NSUInteger i = 0; i < 60; i++) {
			BOOL large = (i % 5) == 0;
			CGFloat angle = -((CGFloat)i / 60.0f * twoPi) + angleOffset;
			NSBezierPath *path = [NSBezierPath bezierPath];
			[path moveToPoint:CGPointMake(center.x + cosf(angle) * (tickRadius - tickLength), center.y + sinf(angle) * (tickRadius - tickLength))];
			[path lineToPoint:CGPointMake(center.x + cosf(angle) * tickRadius, center.y + sinf(angle) * tickRadius)];
			path.lineWidth = ceilf(width * (large ? 0.009569378f : 0.004784689f));
			[large ? handColor : [handColor colorWithAlphaComponent:0.5f] setStroke];
			[path stroke];
		}
	}

	// Numbers
	if (self.drawsNumbers) {
		NSDictionary *attributes = @{
			NSForegroundColorAttributeName: handColor,
			NSKernAttributeName: @(ceilf(width * -0.006379585f) * self.layer.contentsScale)
		};
		CGFloat textRadius = frame.size.width * 0.402711324f;

		for (NSUInteger i = 0; i < 12; i++) {
			NSString *text = [NSString stringWithFormat:@"%i", ((int)i - 12 % 12) ?: 12];
			NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:text attributes:attributes];
			[string addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"HelveticaNeue-Light" size:ceilf(width * 0.03907496f) * self.layer.contentsScale] range:NSMakeRange(0, string.length)];
			CGSize stringSize = [string size];
			CGFloat angle = -((CGFloat)i / 12.0f * twoPi) + angleOffset;
			CGRect rect = CGRectMake(center.x + cosf(angle) * (textRadius - (stringSize.width / 2.0f)), center.y + sinf(angle) * (textRadius - (stringSize.height / 2.0f)), stringSize.width, stringSize.height);
			rect.origin.x -= stringSize.width / 2.0f;
			rect.origin.y -= stringSize.height / 2.0f;

			[string drawInRect:rect];
		}
	}

	// Get time components
	NSDateComponents *comps = [[NSCalendar currentCalendar] components:NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit fromDate:[NSDate date]];

	// Hours
	[[handColor colorWithAlphaComponent:0.7f] setStroke];
	CGFloat angle = -(twoPi * ((CGFloat)comps.hour + ((CGFloat)comps.minute / 60.0f)) / 12.0f) + angleOffset;
	[self drawHandWithSize:CGSizeMake(ceilf(width * 0.023125997f), ceilf(width * 0.263955343f)) angle:angle lineCapStyle:NSSquareLineCapStyle];

	// Minutes
	[handColor setStroke];
	angle = -(twoPi * (CGFloat)comps.minute / 60.0f) + angleOffset;
	[self drawHandWithSize:CGSizeMake(ceilf(width * 0.014354067f), ceilf(width * 0.391547049f)) angle:angle lineCapStyle:NSSquareLineCapStyle];

	// Seconds
	[secondsColor set];
	angle = -(twoPi * (CGFloat)comps.second / 60.0f) + angleOffset;
	[self drawHandWithSize:CGSizeMake(ceilf(width * 0.009569378f), ceilf(width * 0.391547049f)) angle:angle lineCapStyle:NSSquareLineCapStyle];

	// Counterweight
	[self drawHandWithSize:CGSizeMake(ceilf(width * 0.028708134f), -ceilf(width * 0.076555024f)) angle:angle lineCapStyle:NSRoundLineCapStyle];

	// Counterweight circle
	CGFloat nubSize = ceilf(width * 0.052631579f);
	frame = CGRectMake(ceilf((size.width - nubSize) / 2.0f), ceilf((size.height - nubSize) / 2.0f), nubSize, nubSize);
	path = [NSBezierPath bezierPathWithOvalInRect:frame];
	[path fill];

	// Screw
	CGFloat dotSize = ceilf(width * 0.006379585f);
	[[NSColor blackColor] setFill];
	frame = CGRectMake(ceilf((size.width - dotSize) / 2.0f), ceilf((size.height - dotSize) / 2.0f), dotSize, dotSize);
	path = [NSBezierPath bezierPathWithOvalInRect:frame];
	[path fill];
}


- (void)animateOneFrame {
	[self setNeedsDisplay:YES];
}


- (BOOL)hasConfigureSheet {
    return YES;
}


- (NSWindow *)configureSheet {
    return self.configureWindowController.window;
}


#pragma mark - Private

- (CGRect)clockFrameForBounds:(CGRect)bounds {
	CGSize size = bounds.size;
	CGFloat clockSize = MIN(size.width, size.height) * 0.55f;
	return CGRectMake(ceilf((size.width - clockSize) / 2.0f), ceilf((size.height - clockSize) / 2.0f), clockSize, clockSize);
}


// The size's height is the hand length. The size's width is the hand width, duh.
- (void)drawHandWithSize:(CGSize)size angle:(CGFloat)angle lineCapStyle:(NSLineCapStyle)lineCapStyle {
	CGRect frame = [self clockFrameForBounds:self.bounds];
	CGPoint center = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
	CGPoint point = CGPointMake(center.x + cosf(angle) * size.height, center.y + sinf(angle) * size.height);

	NSBezierPath *path = [NSBezierPath bezierPath];
	[path moveToPoint:center];
	[path lineToPoint:point];
	path.lineWidth = size.width;
	path.lineCapStyle = lineCapStyle;
	[path stroke];
}


- (void)configurationDidChange:(NSNotification *)notification {
	ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:SAMClockDefaultsModuleName];

	self.clockStyle = [defaults integerForKey:SAMClockStyleDefaultsKey];
	self.drawsTicks = [defaults boolForKey:SAMClockTickMarksDefaultsKey];
	self.drawsNumbers = [defaults boolForKey:SAMClockNumbersDefaultsKey];
}

@end