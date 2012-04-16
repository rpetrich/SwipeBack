#define USE_PRIVATE

#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>
#import <QuartzCore/QuartzCore.h>

#ifdef USE_PRIVATE
#import <UIKit/UIKit2.h>
#endif

__attribute__((visibility("hidden")))
@interface SwipeBackGestureRecognizer : UIGestureRecognizer {
@private
	UINavigationController *navigationController;
	UIViewController *restorableViewController;
	CAGradientLayer *gradientLayer;
	CAGradientLayer *rightGradientLayer;
	CAGradientLayer *shadowLayer;
	UIView *underView;
	UIView *movingView;
	CGFloat offset;
	BOOL isRoot;
	BOOL gestureIsRestoring;
}
@property (nonatomic, assign) UINavigationController *navigationController;
@property (nonatomic, retain) UIViewController *restorableViewController;
@property (nonatomic, readonly) CAGradientLayer *gradientLayer;
@property (nonatomic, readonly) CAGradientLayer *rightGradientLayer;
@end

@implementation SwipeBackGestureRecognizer

@synthesize navigationController;
@synthesize restorableViewController;

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
		gradientLayer.colors = [NSArray arrayWithObjects:(id)[[UIColor colorWithWhite:0.0f alpha:0.0f] CGColor], (id)[[UIColor colorWithWhite:0.0f alpha:0.1f] CGColor], (id)[[UIColor colorWithWhite:0.0f alpha:0.25f] CGColor], nil];
	}
	return gradientLayer;
}

- (CAGradientLayer *)rightGradientLayer
{
	if (!rightGradientLayer) {
		rightGradientLayer = [[CAGradientLayer alloc] init];
		rightGradientLayer.startPoint = (CGPoint){1.0f, 0.0f};
		rightGradientLayer.endPoint = (CGPoint){0.0f, 0.0f};
		rightGradientLayer.colors = [NSArray arrayWithObjects:(id)[[UIColor colorWithWhite:0.0f alpha:0.0f] CGColor], (id)[[UIColor colorWithWhite:0.0f alpha:0.1f] CGColor], (id)[[UIColor colorWithWhite:0.0f alpha:0.25f] CGColor], nil];
	}
	return rightGradientLayer;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	UIView *navView = navigationController.view;
	offset = [self locationInView:navView].x;
	if (!navigationController.modalViewController) {
		if (offset < 10.0f) {
			NSArray *viewControllers = navigationController.viewControllers;
			NSInteger viewControllerCount = viewControllers.count;
			UIView *view = navigationController.topViewController.view.superview;
			[movingView release];
			movingView = [view retain];
			view.clipsToBounds = YES;
			CGRect frame = view.frame;
			isRoot = viewControllerCount < 2;
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
			frame.size.width = 15.0f;
			frame.origin.x -= 15.0f;
			[CATransaction begin];
			[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
			shadowLayer = self.gradientLayer;
			shadowLayer.opacity = 1.0f;
			shadowLayer.frame = frame;
			[view.superview.layer insertSublayer:shadowLayer below:view.layer];
			[CATransaction commit];
			gestureIsRestoring = NO;
			self.state = UIGestureRecognizerStateBegan;
			return;
		}
		if (offset > navView.bounds.size.width - 10.0f) {
			UIView *view = navigationController.topViewController.view.superview;
			view.clipsToBounds = YES;
			CGRect frame = view.frame;
			isRoot = !restorableViewController;
			[underView release];
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
			} else {
				underView = [view retain];
				movingView = [restorableViewController.view retain];
				offset -= frame.size.width;
				frame.origin.x += frame.size.width;
				movingView.frame = frame;
				[view.superview insertSubview:movingView aboveSubview:view];
				frame.origin.x -= 15.0f;
				[CATransaction begin];
				[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
				shadowLayer = self.gradientLayer;
			}
			frame.size.width = 15.0f;
			shadowLayer.opacity = 1.0f;
			shadowLayer.frame = frame;
			[view.superview.layer insertSublayer:shadowLayer below:movingView.layer];
			[CATransaction commit];
			gestureIsRestoring = YES;
			self.state = UIGestureRecognizerStateBegan;
			return;
		}
	}
	self.state = UIGestureRecognizerStateFailed;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	CGFloat currentOffset = [self locationInView:navigationController.view].x;
	CGRect frame = movingView.frame;
	frame.origin.x = currentOffset - offset;
	if (isRoot)
		frame.origin.x *= (1.0f / 3.0f);
	if (gestureIsRestoring && isRoot) {
		if (frame.origin.x > 0.0f)
			frame.origin.x = 0.0f;
		movingView.frame = frame;
		frame.origin.x += frame.size.width;
		frame.size.width = 15.0f;
		[CATransaction begin];
		[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
		rightGradientLayer.frame = frame;
	} else {
		if (frame.origin.x < 0.0f)
			frame.origin.x = 0.0f;
		movingView.frame = frame;
		frame.size.width = 15.0f;
		frame.origin.x -= 15.0f;
		[CATransaction begin];
		[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
		gradientLayer.frame = frame;
	}
	[CATransaction commit];
}

- (void)completeWithState:(UIGestureRecognizerState)state
{
	CGRect frame = movingView.frame;
	if (state == UIGestureRecognizerStateEnded) {
		frame.origin.x = (gestureIsRestoring && !isRoot) ? 0 : frame.size.width;
	} else {
		frame.origin.x = (gestureIsRestoring && !isRoot) ? frame.size.width : 0.0f;
	}
	NSTimeInterval duration = isRoot ? (1.0 / 5.0) : (1.0 / 3.0);
	[UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
#ifdef USE_PRIVATE
		if (state == UIGestureRecognizerStateEnded) {
			UINavigationBar *bar = navigationController.navigationBar;
			[bar setLocked:0];
			id delegate = bar.delegate;
			bar.delegate = nil;
			if (gestureIsRestoring) {
				[bar pushNavigationItem:restorableViewController.navigationItem animated:YES];
			} else {
				[bar popNavigationItemAnimated:YES];
			}
			bar.delegate = delegate;
			[bar setLocked:1];
		}
#endif
		movingView.frame = frame;
	} completion:NULL];
	if (gestureIsRestoring && isRoot) {
		frame.origin.x += frame.size.width;
		frame.size.width = 15.0f;
	} else {
		frame.size.width = 15.0f;
		frame.origin.x -= 15.0f;
	}
	[CATransaction begin];
	[CATransaction setAnimationDuration:duration];
	[CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
	[CATransaction setCompletionBlock:^{
		[gradientLayer removeFromSuperlayer];
		[rightGradientLayer removeFromSuperlayer];
		if (state == UIGestureRecognizerStateEnded) {
			void (^animations)(void) = gestureIsRestoring ? ^{
#ifdef USE_PRIVATE
				NSMutableArray *viewControllers = [navigationController.viewControllers mutableCopy];
				[viewControllers addObject:restorableViewController];
				[navigationController setViewControllers:viewControllers animated:NO];
#else
				[navigationController pushViewController:restorableViewController animated:YES];
#endif
				[restorableViewController release];
				restorableViewController = nil;
			} : ^{
#ifdef USE_PRIVATE
				NSMutableArray *viewControllers = [navigationController.viewControllers mutableCopy];
				UIViewController *viewController = [viewControllers lastObject];
				[restorableViewController release];
				restorableViewController = [viewController retain];
				[viewControllers removeObjectAtIndex:viewControllers.count-1];
				[viewController viewWillDisappear:NO];
				[viewController viewDidDisappear:NO];
				[navigationController setViewControllers:viewControllers animated:NO];
				[viewControllers release];
#else
				[navigationController popViewControllerAnimated:NO];
#endif
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
	}];
	shadowLayer.frame = frame;
	shadowLayer.opacity = 0.0f;
	[CATransaction commit];
	self.state = state;
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
	[gradientLayer removeFromSuperlayer];
	[gradientLayer release];
	[movingView release];
	[underView release];
	[super dealloc];
}

@end

static void *SwipeBackGestureRecognizerKey;

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
	[self.view addGestureRecognizer:recognizer];
}

- (void)dealloc
{
	SwipeBackGestureRecognizer *recognizer = objc_getAssociatedObject(self, &SwipeBackGestureRecognizerKey);
	if (recognizer) {
		recognizer.navigationController = nil;
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
