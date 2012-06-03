#define USE_PRIVATE

#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>
#import <QuartzCore/QuartzCore.h>

#ifdef USE_PRIVATE
#import <UIKit/UIKit2.h>
#endif

static inline CGFloat CGFloatRoundToScreenScale(CGFloat value)
{
	CGFloat scale = [UIScreen mainScreen].scale;
	return roundf(value * scale) / scale;
}

@class SwipeBackGestureRecognizer;

@protocol SwipeBackGestureRecognizerDelegate <NSObject>
@required
- (BOOL)swipeBackGestureRecognizerShouldInhibitGestures:(SwipeBackGestureRecognizer *)recognizer;
- (BOOL)swipeBackGestureRecognizerShouldAllowSwipeBack:(SwipeBackGestureRecognizer *)recognizer;
- (BOOL)swipeBackGestureRecognizerShouldAllowSwipeForward:(SwipeBackGestureRecognizer *)recognizer;
@end

__attribute__((visibility("hidden")))
@interface SwipeBackGestureRecognizer : UIGestureRecognizer {
@private
	UINavigationController *navigationController;
	id<SwipeBackGestureRecognizerDelegate> delegate;
	UIViewController *restorableViewController;
	CAGradientLayer *gradientLayer;
	CAGradientLayer *rightGradientLayer;
	CAGradientLayer *shadowLayer;
	CAGradientLayer *navigationBarShadow;
	UIView *underView;
	UIView *movingView;
	CGFloat offset;
	BOOL isRoot;
	BOOL gestureIsRestoring;
}
@property (nonatomic, assign) UINavigationController *navigationController;
@property (nonatomic, assign) id<SwipeBackGestureRecognizerDelegate> delegate;
@property (nonatomic, retain) UIViewController *restorableViewController;
@property (nonatomic, readonly) CAGradientLayer *gradientLayer;
@property (nonatomic, readonly) CAGradientLayer *rightGradientLayer;
@property (nonatomic, readonly) CAGradientLayer *navigationBarShadow;
@end

@implementation SwipeBackGestureRecognizer

+ (NSArray *)gradientColors
{
	return [NSArray arrayWithObjects:
		(id)[[UIColor colorWithWhite:0.0f alpha:0.0f] CGColor],
		(id)[[UIColor colorWithWhite:0.0f alpha:0.1f] CGColor],
		(id)[[UIColor colorWithWhite:0.0f alpha:0.25f] CGColor],
		(id)[[UIColor colorWithWhite:0.0f alpha:0.4f] CGColor],
		nil];
}

+ (NSArray *)gradientLocations
{
	return [NSArray arrayWithObjects:
		[NSNumber numberWithFloat:0.0f],
		[NSNumber numberWithFloat:15.0f / 32.0f],
		[NSNumber numberWithFloat:30.0f / 32.0f],
		[NSNumber numberWithFloat:1.0f],
		nil];
}

+ (CGFloat)shadowSize
{
	return 20.0f;
}

@synthesize navigationController;
@synthesize restorableViewController;
@synthesize delegate;

- (BOOL)delaysTouchesBegan
{
	return YES;
}

- (CAGradientLayer *)gradientLayer
{
	if (!gradientLayer) {
		gradientLayer = [[CAGradientLayer alloc] init];
		gradientLayer.startPoint = (CGPoint){0.0f, 0.0f};
		gradientLayer.endPoint = (CGPoint){1.0f, 0.0f};
		gradientLayer.colors = [[self class] gradientColors];
		gradientLayer.locations = [[self class] gradientLocations];
	}
	return gradientLayer;
}

- (CAGradientLayer *)rightGradientLayer
{
	if (!rightGradientLayer) {
		rightGradientLayer = [[CAGradientLayer alloc] init];
		rightGradientLayer.startPoint = (CGPoint){1.0f, 0.0f};
		rightGradientLayer.endPoint = (CGPoint){0.0f, 0.0f};
		rightGradientLayer.colors = [[self class] gradientColors];
		rightGradientLayer.locations = [[self class] gradientLocations];
	}
	return rightGradientLayer;
}

- (CAGradientLayer *)navigationBarShadow
{
	if (!navigationBarShadow) {
		navigationBarShadow = [[CAGradientLayer alloc] init];
		navigationBarShadow.startPoint = (CGPoint){0.0f, 1.0f};
		navigationBarShadow.endPoint = (CGPoint){0.0f, 0.0f};
		navigationBarShadow.colors = [[self class] gradientColors];
		navigationBarShadow.locations = [[self class] gradientLocations];
	}
	return navigationBarShadow;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	UIView *navView = navigationController.view;
	offset = [self locationInView:navView].x;
	if (!navigationController.modalViewController) {
		if (offset < 10.0f) {
			if ([delegate swipeBackGestureRecognizerShouldInhibitGestures:self])
				goto cancel;
			NSArray *viewControllers = navigationController.viewControllers;
			NSInteger viewControllerCount = viewControllers.count;
			UIView *view = navigationController.topViewController.view.superview;
			[movingView release];
			movingView = [view retain];
			view.clipsToBounds = YES;
			CGRect frame = view.frame;
			isRoot = (viewControllerCount < 2) || (delegate && ![delegate swipeBackGestureRecognizerShouldAllowSwipeBack:self]);
			UIViewController *viewController = isRoot ? nil : [viewControllers objectAtIndex:viewControllerCount-2];
#ifdef USE_PRIVATE
			[viewController viewWillAppear:NO];
#endif
			[underView release];
			if (isRoot) {
				underView = [[UIView alloc] initWithFrame:frame];
				underView.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
			} else {
				underView = [viewController.view retain];
				underView.frame = frame;
			}
			[view.superview insertSubview:underView belowSubview:view];
#ifdef USE_PRIVATE
			[viewController viewDidAppear:YES];
#endif
			CGRect shadowFrame = frame;
			CGFloat shadowSize = [[self class] shadowSize];
			shadowFrame.size.width = shadowSize;
			shadowFrame.origin.x -= shadowSize;
			[CATransaction begin];
			[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
			shadowLayer = self.gradientLayer;
			shadowLayer.opacity = 1.0f;
			shadowLayer.frame = shadowFrame;
			[view.superview.layer insertSublayer:shadowLayer below:view.layer];
			if (isRoot) {
				CALayer *navShadow = self.navigationBarShadow;
				shadowFrame = frame;
				shadowFrame.size.height = shadowSize;
				navShadow.frame = shadowFrame;
				[view.superview.layer insertSublayer:navShadow below:view.layer];
			}
			[CATransaction commit];
			gestureIsRestoring = NO;
			self.state = UIGestureRecognizerStateBegan;
			navView.window.userInteractionEnabled = NO;
			return;
		}
		if (offset > navView.bounds.size.width - 10.0f) {
			if ([delegate swipeBackGestureRecognizerShouldInhibitGestures:self])
				goto cancel;
			UIView *view = navigationController.topViewController.view.superview;
			view.clipsToBounds = YES;
			CGRect frame = view.frame;
			isRoot = !restorableViewController || ([navigationController.viewControllers indexOfObjectIdenticalTo:restorableViewController] != NSNotFound) || (delegate && ![delegate swipeBackGestureRecognizerShouldAllowSwipeForward:self]);
			[underView release];
			CGFloat shadowSize = [[self class] shadowSize];
			CGRect shadowFrame = frame;
			if (isRoot) {
				underView = [[UIView alloc] initWithFrame:frame];
				underView.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
				[view.superview insertSubview:underView belowSubview:view];
				[movingView release];
				movingView = [view retain];
				frame.origin.x -= frame.size.width;
				[CATransaction begin];
				[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
				shadowLayer = self.rightGradientLayer;
				CALayer *navShadow = self.navigationBarShadow;
				shadowFrame.size.height = shadowSize;
				navShadow.frame = shadowFrame;
				[view.superview.layer insertSublayer:navShadow below:view.layer];
			} else {
				underView = [view retain];
				movingView = [restorableViewController.view retain];
				offset -= frame.size.width;
				frame.origin.x += frame.size.width;
				movingView.frame = frame;
				[view.superview insertSubview:movingView aboveSubview:view];
				frame.origin.x -= shadowSize;
				[CATransaction begin];
				[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
				shadowLayer = self.gradientLayer;
			}
			frame.size.width = shadowSize;
			shadowLayer.opacity = 1.0f;
			shadowLayer.frame = frame;
			[view.superview.layer insertSublayer:shadowLayer below:movingView.layer];
			[CATransaction commit];
			gestureIsRestoring = YES;
			self.state = UIGestureRecognizerStateBegan;
			navView.window.userInteractionEnabled = NO;
			return;
		}
	}
cancel:
	self.state = UIGestureRecognizerStateFailed;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	CGFloat currentOffset = [self locationInView:navigationController.view].x;
	CGRect frame = movingView.frame;
	frame.origin.x = currentOffset - offset;
	if (isRoot)
		frame.origin.x *= (1.0f / 3.0f);
	frame.origin.x = CGFloatRoundToScreenScale(frame.origin.x);
	if (gestureIsRestoring && isRoot) {
		if (frame.origin.x > 0.0f)
			frame.origin.x = 0.0f;
		movingView.frame = frame;
		frame.origin.x += frame.size.width;
		frame.size.width = [[self class] shadowSize];
		[CATransaction begin];
		[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
		rightGradientLayer.frame = frame;
	} else {
		if (frame.origin.x < 0.0f)
			frame.origin.x = 0.0f;
		movingView.frame = frame;
		frame.size.width = [[self class] shadowSize];
		frame.origin.x -= frame.size.width;
		[CATransaction begin];
		[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
		gradientLayer.frame = frame;
	}
	[CATransaction commit];
}

- (void)completeWithState:(UIGestureRecognizerState)state
{
	CGRect frame = movingView.frame;
	frame.origin.x = ((state == UIGestureRecognizerStateEnded) ^ (gestureIsRestoring && !isRoot)) ? frame.size.width : 0.0f;
	NSTimeInterval duration = isRoot ? (1.0 / 5.0) : (1.0 / 3.0);
	[UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
#ifdef USE_PRIVATE
		if (state == UIGestureRecognizerStateEnded) {
			UINavigationBar *bar = navigationController.navigationBar;
			[bar setLocked:0];
			id oldDelegate = bar.delegate;
			bar.delegate = nil;
			if (gestureIsRestoring) {
				[bar pushNavigationItem:restorableViewController.navigationItem animated:YES];
			} else {
				[bar popNavigationItemAnimated:YES];
			}
			bar.delegate = oldDelegate;
			[bar setLocked:1];
		}
#endif
		movingView.frame = frame;
	} completion:NULL];
	if (gestureIsRestoring && isRoot) {
		frame.origin.x += frame.size.width;
		frame.size.width = [[self class] shadowSize];
	} else {
		frame.size.width = [[self class] shadowSize];
		frame.origin.x -= frame.size.width;
	}
	if (state == UIGestureRecognizerStateEnded) {
		[[[UIApplication sharedApplication] keyWindow] endEditing:YES];
	}
	[CATransaction begin];
	[CATransaction setAnimationDuration:duration];
	[CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
	[CATransaction setCompletionBlock:^{
		[gradientLayer removeFromSuperlayer];
		[rightGradientLayer removeFromSuperlayer];
		if (state == UIGestureRecognizerStateEnded) {
			void (^animations)(void) = gestureIsRestoring ? ^{
				[navigationController pushViewController:restorableViewController animated:NO];
				[restorableViewController release];
				restorableViewController = nil;
			} : ^{
				[navigationController popViewControllerAnimated:NO];
			};
			[UIView transitionWithView:navigationController.view
			                  duration:1.0/4.0
			                   options:UIViewAnimationOptionTransitionCrossDissolve
			                animations:animations
			                completion:NULL];
			[movingView removeFromSuperview];
			[navigationController setNavigationBarHidden:NO animated:YES];
		} else {
			[(gestureIsRestoring && !isRoot) ? movingView : underView removeFromSuperview];
		}
		[underView release];
		underView = nil;
		[movingView release];
		movingView = nil;
		[navigationBarShadow removeFromSuperlayer];
	}];
	shadowLayer.frame = frame;
	shadowLayer.opacity = 0.0f;
	[CATransaction commit];
	self.state = state;
	navigationController.view.window.userInteractionEnabled = YES;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (isRoot) {
		[self completeWithState:UIGestureRecognizerStateCancelled];
	} else if (gestureIsRestoring) {
		[self completeWithState:([self locationInView:navigationController.view].x < navigationController.view.bounds.size.width - 100.0f) ? UIGestureRecognizerStateEnded : UIGestureRecognizerStateCancelled];
	} else {
		[self completeWithState:([self locationInView:navigationController.view].x > 100.0f) ? UIGestureRecognizerStateEnded : UIGestureRecognizerStateCancelled];
	}
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[self completeWithState:UIGestureRecognizerStateCancelled];
}

- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer
{
	return NO;
}

- (void)dealloc
{
	[restorableViewController release];
	[navigationBarShadow removeFromSuperlayer];
	[navigationBarShadow release];
	[rightGradientLayer removeFromSuperlayer];
	[rightGradientLayer release];
	[gradientLayer removeFromSuperlayer];
	[gradientLayer release];
	[movingView release];
	[underView release];
	[super dealloc];
}

@end

static void *SwipeBackGestureRecognizerKey;

@interface UINavigationController (SwipeBackGestureRecognizer) <SwipeBackGestureRecognizerDelegate>
@end

static inline BOOL isEnabled()
{
	NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.rpetrich.swipeback.plist"];
	NSString *key = [@"SBEnabled-" stringByAppendingString:[NSBundle mainBundle].bundleIdentifier];
	id temp = [settings objectForKey:key];
	return temp ? [temp boolValue] : YES;
}

@implementation UINavigationController (SwipeBackGestureRecognizer)

- (BOOL)swipeBackGestureRecognizerShouldInhibitGestures:(SwipeBackGestureRecognizer *)recognizer
{
	return !isEnabled();
}

- (BOOL)swipeBackGestureRecognizerShouldAllowSwipeBack:(SwipeBackGestureRecognizer *)recognizer
{
	return YES;
}

- (BOOL)swipeBackGestureRecognizerShouldAllowSwipeForward:(SwipeBackGestureRecognizer *)recognizer
{
	return YES;
}

@end

%hook UINavigationController

- (void)viewDidLoad
{
	%orig;
	SwipeBackGestureRecognizer *recognizer = objc_getAssociatedObject(self, &SwipeBackGestureRecognizerKey);
	if (!recognizer) {
		recognizer = [[[SwipeBackGestureRecognizer alloc] init] autorelease];
		objc_setAssociatedObject(self, &SwipeBackGestureRecognizerKey, recognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	recognizer.navigationController = self;
	recognizer.delegate = self;
	[self.view addGestureRecognizer:recognizer];
}

- (void)dealloc
{
	SwipeBackGestureRecognizer *recognizer = objc_getAssociatedObject(self, &SwipeBackGestureRecognizerKey);
	if (recognizer) {
		recognizer.navigationController = nil;
		recognizer.delegate = nil;
		objc_setAssociatedObject(self, &SwipeBackGestureRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	%orig;
}

- (UIViewController *)_popViewControllerWithTransition:(int)transitionType allowPoppingLast:(BOOL)allowPoppingLast
{
	UIViewController *result = %orig;
	SwipeBackGestureRecognizer *recognizer = objc_getAssociatedObject(self, &SwipeBackGestureRecognizerKey);
	recognizer.restorableViewController = result;
	return result;
}

%end

%hook BrowserController

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
	%orig;
	scrollView.alwaysBounceHorizontal = isEnabled();
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	if (isEnabled()) {
		%orig;
		CGFloat offset = scrollView.contentOffset.x;
		if (offset < -25.0f) {
			[self goBack];
		} else if (offset > scrollView.bounds.size.width - scrollView.contentSize.width + 25.0f) {
			[self goForward];
		}
	} else {
		%orig;
	}
}

%end
