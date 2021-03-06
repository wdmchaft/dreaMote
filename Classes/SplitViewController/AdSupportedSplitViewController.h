//
//  AdSupportedSplitViewController.h
//  dreaMote
//
//  Created by Moritz Venn on 02.03.11.
//  Copyright 2011-2012 Moritz Venn. All rights reserved.
//

#import <Foundation/Foundation.h>

#if INCLUDE_FEATURE(Ads)
	#import <iAd/ADBannerView.h>
#endif

#import <MGSplitViewController.h>

@interface AdSupportedSplitViewController : MGSplitViewController
#if INCLUDE_FEATURE(Ads)
											<ADBannerViewDelegate>
#endif
{
#if INCLUDE_FEATURE(Ads)
@private
	ADBannerView *_adBannerView;
	BOOL _adBannerViewIsVisible;
#endif
}

@end
