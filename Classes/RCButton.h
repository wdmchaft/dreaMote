//
//  RCButton.h
//  dreaMote
//
//  Created by Moritz Venn on 23.07.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface RCButton : UIButton {
@public
	NSInteger rcCode;
}

@property (nonatomic) NSInteger rcCode;

@end
