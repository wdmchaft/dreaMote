//
//  AdSupportedSplitViewController.m
//  dreaMote
//
//  Created by Moritz Venn on 02.03.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "AdSupportedSplitViewController.h"

@interface AdSupportedSplitViewController()
#if SHOW_ADS()
- (void)createAdBannerView;
- (void)fixupAdView:(UIInterfaceOrientation)toInterfaceOrientation;
@property (nonatomic, retain) id adBannerView;
@property (nonatomic) BOOL adBannerViewIsVisible;
#endif
@end


@implementation AdSupportedSplitViewController

#if SHOW_ADS()
@synthesize adBannerView = _adBannerView;
@synthesize adBannerViewIsVisible = _adBannerViewIsVisible;
#endif

- (void)dealloc
{
#if SHOW_ADS()
	[_adBannerView release];
#endif
	[super dealloc];
}

- (void)loadView
{
	[super loadView];

#if SHOW_ADS()
	[self createAdBannerView];
#endif
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
#if SHOW_ADS()
	[self fixupAdView:self.interfaceOrientation];
#endif
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation 
										 duration:(NSTimeInterval)duration
{
	[super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation 
											duration:duration];
#if SHOW_ADS()
	[self fixupAdView:toInterfaceOrientation];
#endif
}

#pragma mark ADBannerViewDelegate
#if SHOW_ADS()

//#define __BOTTOM_AD__

- (CGFloat)getBannerHeight:(UIDeviceOrientation)orientation
{
	if(UIInterfaceOrientationIsLandscape(orientation))
		return IS_IPAD() ? 66 : 32;
	else
		return IS_IPAD() ? 66 : 50;
}

- (CGFloat)getBannerHeight
{
	return [self getBannerHeight:self.interfaceOrientation];
}

- (void)createAdBannerView
{
	Class classAdBannerView = NSClassFromString(@"ADBannerView");
	if(classAdBannerView != nil)
	{
		self.adBannerView = [[[classAdBannerView alloc] initWithFrame:CGRectZero] autorelease];
		[_adBannerView setRequiredContentSizeIdentifiers:[NSSet setWithObjects:
														  bannerContentSizeIdentifierPortrait,
														  bannerContentSizeIdentifierLandscape,
														  nil]];
		if(UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
		{
			[_adBannerView setCurrentContentSizeIdentifier:bannerContentSizeIdentifierLandscape];
		}
		else
		{
			[_adBannerView setCurrentContentSizeIdentifier:bannerContentSizeIdentifierPortrait];
		}
#ifdef __BOTTOM_AD__
		// Banner at Bottom
		CGRect cgRect =[[UIScreen mainScreen] bounds];
		CGSize cgSize = cgRect.size;
		[_adBannerView setFrame:CGRectOffset([_adBannerView frame], 0, cgSize.height + [self getBannerHeight])];
#else
		// Banner at the Top
		[_adBannerView setFrame:CGRectOffset([_adBannerView frame], 0, -[self getBannerHeight])];
#endif
		[_adBannerView setDelegate:self];
		
		[self.view addSubview:_adBannerView];
	}
}

// XXX: only supports vertical split
- (void)fixupAdView:(UIInterfaceOrientation)toInterfaceOrientation
{
	if (_adBannerView != nil)
	{
		if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
		{
			[_adBannerView setCurrentContentSizeIdentifier:bannerContentSizeIdentifierLandscape];
		}
		else
		{
			[_adBannerView setCurrentContentSizeIdentifier:bannerContentSizeIdentifierPortrait];
		}
		[UIView beginAnimations:@"fixupViews" context:nil];
		if(_adBannerViewIsVisible)
		{
			CGRect adBannerViewFrame = [_adBannerView frame];
			CGRect masterViewFrame = self.masterViewController.view.frame;
			CGRect detailViewFrame = self.detailViewController.view.frame;
			CGFloat newBannerHeight = [self getBannerHeight:toInterfaceOrientation];

			adBannerViewFrame.origin.x = 0;
#ifdef __BOTTOM_AD__
			CGSize cgSize = [[UIScreen mainScreen] bounds].size;
			adBannerViewFrame.origin.y = cgSize.height - newBannerHeight - self.tabBarController.tabBar.frame.size.height;
#else
			adBannerViewFrame.origin.y = 0;
#endif
			[_adBannerView setFrame:adBannerViewFrame];
			[self.view bringSubviewToFront:_adBannerView];

#ifdef __BOTTOM_AD__
			masterViewFrame.origin.y = 0;
			detailViewFrame.origin.y = 0;
#else
			masterViewFrame.origin.y = newBannerHeight;
			detailViewFrame.origin.y = newBannerHeight;
#endif
			masterViewFrame.size.height = self.view.frame.size.height - newBannerHeight;
			detailViewFrame.size.height = self.view.frame.size.height - newBannerHeight;
			self.masterViewController.view.frame = masterViewFrame;
			self.detailViewController.view.frame = detailViewFrame;
		}
		else
		{
			CGRect adBannerViewFrame = [_adBannerView frame];
			adBannerViewFrame.origin.x = 0;
#ifdef __BOTTOM_AD__
			CGSize cgSize = [[UIScreen mainScreen] bounds].size;
			adBannerViewFrame.origin.y = cgSize.height + [self getBannerHeight:toInterfaceOrientation];
#else
			adBannerViewFrame.origin.y = -[self getBannerHeight:toInterfaceOrientation];
#endif
			[_adBannerView setFrame:adBannerViewFrame];

			CGRect masterViewFrame = self.masterViewController.view.frame;
			CGRect detailViewFrame = self.detailViewController.view.frame;
			masterViewFrame.origin.y = 0;
			detailViewFrame.origin.y = 0;
			masterViewFrame.size.height = self.view.frame.size.height;
			detailViewFrame.size.height = self.view.frame.size.height;
			self.masterViewController.view.frame = masterViewFrame;
			self.detailViewController.view.frame = detailViewFrame;
		}
		[UIView commitAnimations];
	}
}

- (void)bannerViewDidLoadAd:(ADBannerView *)banner
{
	if(!_adBannerViewIsVisible)
	{
		_adBannerViewIsVisible = YES;
		[self fixupAdView:self.interfaceOrientation];
	}
}

- (void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error
{
	if(_adBannerViewIsVisible)
	{
		_adBannerViewIsVisible = NO;
		[self fixupAdView:self.interfaceOrientation];
	}
}
#endif

@end
