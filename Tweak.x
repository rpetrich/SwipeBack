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
	CAGradientLayer *gradientLayer;
	UIView *underView;
	CGFloat offset;
}
@property (nonatomic, assign) UINavigationController *navigationController;
@end

@implementation SwipeBackGestureRecognizer

@synthesize navigationController;

- (BOOL)delaysTouchesBegan
{
	return YES;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	offset = [self locationInView:navigationController.view].x;
	if (offset < 10.0f) {
		NSArray *viewControllers = navigationController.viewControllers;
		NSInteger viewControllerCount = viewControllers.count;
		if ((viewControllerCount >= 2) && !navigationController.modalViewController) {
			UIView *view = navigationController.topViewController.view.superview;
			view.clipsToBounds = YES;
			CGRect frame = view.frame;
			[underView release];
			underView = [[[viewControllers objectAtIndex:viewControllerCount-2] view] retain];
			underView.frame = frame;
			[view.superview insertSubview:underView belowSubview:view];
			if (!gradientLayer) {
				gradientLayer = [[CAGradientLayer alloc] init];
				gradientLayer.startPoint = (CGPoint){0.0f, 0.0f};
				gradientLayer.endPoint = (CGPoint){1.0f, 0.0f};
				gradientLayer.colors = [NSArray arrayWithObjects:(id)[[UIColor colorWithWhite:0.0f alpha:0.0f] CGColor], (id)[[UIColor colorWithWhite:0.0f alpha:0.1f] CGColor], (id)[[UIColor colorWithWhite:0.0f alpha:0.25f] CGColor], nil];
			}
			frame.size.width = 15.0f;
			frame.origin.x -= 15.0f;
			[CATransaction begin];
			[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
			gradientLayer.frame = frame;
			[view.superview.layer insertSublayer:gradientLayer below:view.layer];
			[CATransaction commit];
			self.state = UIGestureRecognizerStateBegan;
			return;
		}
	}
	self.state = UIGestureRecognizerStateFailed;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	CGFloat currentOffset = [self locationInView:navigationController.view].x;
	UIView *view = navigationController.topViewController.view.superview;
	CGRect frame = view.frame;
	frame.origin.x = currentOffset - offset;
	view.frame = frame;
	frame.size.width = 15.0f;
	frame.origin.x -= 15.0f;
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	gradientLayer.frame = frame;
	[CATransaction commit];
}

- (void)completeWithState:(UIGestureRecognizerState)state
{
	UIView *view = navigationController.topViewController.view.superview;
	CGRect frame = view.frame;
	frame.origin.x = (state == UIGestureRecognizerStateEnded) ? frame.size.width : 0.0f;
	[UIView animateWithDuration:1.0/3.0 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
#ifdef USE_PRIVATE
		if (state == UIGestureRecognizerStateEnded) {
			UINavigationBar *bar = navigationController.navigationBar;
			[bar setLocked:0];
			id delegate = bar.delegate;
			bar.delegate = nil;
			[bar popNavigationItemAnimated:YES];
			bar.delegate = delegate;
			[bar setLocked:1];
		}
#endif
		view.frame = frame;
	} completion:NULL];
	frame.size.width = 15.0f;
	frame.origin.x -= 15.0f;
	[CATransaction begin];
	[CATransaction setAnimationDuration:1.0/3.0];
	[CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
	[CATransaction setCompletionBlock:^{
		[gradientLayer removeFromSuperlayer];
		if (state == UIGestureRecognizerStateEnded) {
			[UIView transitionWithView:navigationController.view
			                  duration:1.0/4.0
			                   options:UIViewAnimationOptionTransitionCrossDissolve
			                animations:^
				{
#ifdef USE_PRIVATE
					NSMutableArray *viewControllers = [navigationController.viewControllers mutableCopy];
					[viewControllers removeObjectAtIndex:viewControllers.count-1];
					[navigationController setViewControllers:viewControllers animated:NO];
					[viewControllers release];
#else
					[navigationController popViewControllerAnimated:NO];
#endif
				}
			                completion:NULL];
			[view removeFromSuperview];
		} else {
			[underView removeFromSuperview];
		}
		[underView release];
		underView = nil;
	}];
	gradientLayer.frame = frame;
	[CATransaction commit];
	self.state = state;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[self completeWithState:([self locationInView:navigationController.view].x > 100.0f) ? UIGestureRecognizerStateEnded : UIGestureRecognizerStateCancelled];
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
	[gradientLayer removeFromSuperlayer];
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

%end
