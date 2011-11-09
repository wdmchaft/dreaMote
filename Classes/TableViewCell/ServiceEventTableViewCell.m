//
//  ServiceEventTableViewCell.m
//  dreaMote
//
//  Created by Moritz Venn on 15.01.11.
//  Copyright 2011 Moritz Venn. All rights reserved.
//

#import "Constants.h"
#import "ServiceEventTableViewCell.h"

/*!
 @brief Cell identifier for this cell.
 */
NSString *kServiceEventCell_ID = @"ServiceEventCell_ID";

/*!
 @brief Private functions of ServiceTableViewCell.
 */
@interface ServiceEventTableViewCell()
/*!
 @brief Private helper to create a label.
 */
- (UILabel *)newLabelWithPrimaryColor:(UIColor *) primaryColor selectedColor:(UIColor *) selectedColor fontSize:(CGFloat) fontSize bold:(BOOL) bold;
@end

@implementation ServiceEventTableViewCell

@synthesize formatter, loadPicon;

/* initialize */
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	if((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
	{
		const UIView *myContentView = self.contentView;

		// you can do this here specifically or at the table level for all cells
		self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

		// A label that displays the Servicename.
		_serviceNameLabel = [self newLabelWithPrimaryColor:[DreamoteConfiguration singleton].textColor
											 selectedColor:[DreamoteConfiguration singleton].highlightedTextColor
												  fontSize:kServiceEventServiceSize
													  bold:YES];
		[myContentView addSubview: _serviceNameLabel];

		// label that might be used to display currently playing event
		_nowLabel = [self newLabelWithPrimaryColor:[DreamoteConfiguration singleton].textColor
									 selectedColor:[DreamoteConfiguration singleton].highlightedTextColor
										  fontSize:kServiceEventEventSize
											  bold:NO];
		[myContentView addSubview: _nowLabel];

		_nowTimeLabel = [self newLabelWithPrimaryColor:[DreamoteConfiguration singleton].textColor
									 selectedColor:[DreamoteConfiguration singleton].highlightedTextColor
										  fontSize:kServiceEventEventSize
											  bold:NO];
		[myContentView addSubview: _nowTimeLabel];

		_nextLabel = [self newLabelWithPrimaryColor:[DreamoteConfiguration singleton].textColor
									 selectedColor:[DreamoteConfiguration singleton].highlightedTextColor
										  fontSize:kServiceEventEventSize
											  bold:NO];
		[myContentView addSubview: _nextLabel];

		_nextTimeLabel = [self newLabelWithPrimaryColor:[DreamoteConfiguration singleton].textColor
									  selectedColor:[DreamoteConfiguration singleton].highlightedTextColor
										   fontSize:kServiceEventEventSize
											   bold:NO];
		[myContentView addSubview: _nextTimeLabel];

		NSString *localeIdentifier = [[NSLocale componentsFromLocaleIdentifier:[[NSLocale currentLocale] localeIdentifier]] objectForKey:NSLocaleLanguageCode];
		if([localeIdentifier isEqualToString:@"de"])
			timeWidth = (IS_IPAD()) ? 100 : 80;
		else // tested for en_US
			timeWidth = (IS_IPAD()) ? 150 : 110;

		loadPicon = YES;
	}

	return self;
}

- (void)theme
{
	_serviceNameLabel.textColor = [DreamoteConfiguration singleton].textColor;
	_serviceNameLabel.highlightedTextColor = [DreamoteConfiguration singleton].highlightedTextColor;
	_nowLabel.textColor = [DreamoteConfiguration singleton].textColor;
	_nowLabel.highlightedTextColor = [DreamoteConfiguration singleton].highlightedTextColor;
	_nowTimeLabel.textColor = [DreamoteConfiguration singleton].textColor;
	_nowTimeLabel.highlightedTextColor = [DreamoteConfiguration singleton].highlightedTextColor;
	_nextLabel.textColor = [DreamoteConfiguration singleton].textColor;
	_nextLabel.highlightedTextColor = [DreamoteConfiguration singleton].highlightedTextColor;
	_nextTimeLabel.textColor = [DreamoteConfiguration singleton].textColor;
	_nextTimeLabel.highlightedTextColor = [DreamoteConfiguration singleton].highlightedTextColor;
	[super theme];
}

- (void)prepareForReuse
{
	_nowLabel.text = nil;
	_nowTimeLabel.text = nil;
	_nextLabel.text = nil;
	_nextTimeLabel.text = nil;
	_serviceNameLabel.text = nil;

	self.imageView.image = nil;
	self.accessoryType = UITableViewCellAccessoryNone;

	_now = nil;
	_next = nil;

	[super prepareForReuse];
}

/* getter for now property */
- (NSObject<EventProtocol> *)now
{
	return _now;
}

/* setter for service property */
- (void)setNow:(NSObject<EventProtocol> *)new
{
	// Abort if same event assigned
	if([_now isEqual:new]) return;
	_now = new;

	if(new.valid)
	{
		NSDate *beginDate = new.begin;
		const NSObject<ServiceProtocol> *service = new.service;
		const BOOL serviceValid = service.valid;

		// Check if valid event data
		if(beginDate)
		{
			// Check if cache already generated
			if(new.timeString == nil)
			{
				// Not generated, do so...
				const NSString *begin = [formatter stringFromDate:beginDate];
				const NSString *end = [formatter stringFromDate:new.end];
				if(begin && end)
					new.timeString = [NSString stringWithFormat: @"%@ - %@", begin, end];
			}

			_nowLabel.text = new.title;
			_nowTimeLabel.text = new.timeString;
		}
		else
		{
			if(serviceValid)
				_nowLabel.text = NSLocalizedString(@"No EPG", @"Placeholder text in Now/Next-ServiceList if no EPG data present");
			else
				_nowLabel.text = nil;

			_nowTimeLabel.text = nil;
		}
		_serviceNameLabel.text = service.sname;

		if(serviceValid)
		{
			if(service.piconLoaded || loadPicon)
				self.imageView.image = service.picon;
			self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
	}
	else
		_serviceNameLabel.text = new.title;

	[self setNeedsDisplay];
}

/* getter of next property */
- (NSObject<EventProtocol> *)next
{
	return _next;
}

/* setter of next property */
- (void)setNext:(NSObject<EventProtocol> *)new
{
	// Abort if same event assigned
	if([_next isEqual:new]) return;
	_next = new;

	NSDate *beginDate = new.begin;

	// Check if valid event data
	if(beginDate)
	{
		// Check if cache already generated
		if(new.timeString == nil)
		{
			// Not generated, do so...
			const NSString *begin = [formatter stringFromDate:beginDate];
			const NSString *end = [formatter stringFromDate:new.end];
			if(begin && end)
				new.timeString = [NSString stringWithFormat: @"%@ - %@", begin, end];
		}

		_nextLabel.text = new.title;
		_nextTimeLabel.text = new.timeString;
	}

	[self setNeedsDisplay];
}

/* layout */
- (void)layoutSubviews
{
	[super layoutSubviews];
	const CGRect contentRect = self.contentView.bounds;

	if(!_now.service.valid)
	{
		const CGRect frame = CGRectMake(kLeftMargin, (contentRect.size.height - kServiceEventServiceSize) / 2 , contentRect.size.width - kRightMargin, kServiceEventServiceSize + 5);
		_serviceNameLabel.frame = frame;
	}
	else
	{
		const NSInteger offset = 3;
		CGRect imageRect = self.imageView.frame;
		if(self.editing)
			imageRect.origin.x += kLeftMargin;
		self.imageView.frame = imageRect;
		const NSInteger leftMargin = (self.imageView.image) ? (imageRect.size.width + imageRect.origin.x + offset) : contentRect.origin.x + kLeftMargin;

		// Base frame
		CGRect frame = CGRectMake(leftMargin, 1, contentRect.size.width - leftMargin - kRightMargin, kServiceEventServiceSize + offset);
		_serviceNameLabel.frame = frame;

		frame.origin.y += frame.size.height;
		frame.size.width = timeWidth;
		frame.size.height = kServiceEventEventSize + offset;
		_nowTimeLabel.frame = frame;

		frame.origin.x += frame.size.width + 5;
		frame.size.width = contentRect.size.width - frame.origin.x - kRightMargin;
		_nowLabel.frame = frame;

		frame.origin.x = leftMargin;
		frame.origin.y += frame.size.height;
		frame.size.width = timeWidth;
		_nextTimeLabel.frame = frame;

		frame.origin.x += frame.size.width + 5;
		frame.size.width = contentRect.size.width - frame.origin.x - kRightMargin;
		_nextLabel.frame = frame;
	}
}

/* (de)select */
- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
	[super setSelected:selected animated:animated];

	_serviceNameLabel.highlighted = selected;
}

/* Create and configure a label. */
- (UILabel *)newLabelWithPrimaryColor:(UIColor *) primaryColor selectedColor:(UIColor *) selectedColor fontSize:(CGFloat) fontSize bold:(BOOL) bold
{
	UIFont *font;
	UILabel *newLabel;

	if (bold) {
		font = [UIFont boldSystemFontOfSize:fontSize];
	} else {
		font = [UIFont systemFontOfSize:fontSize];
	}

	newLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	newLabel.backgroundColor = [UIColor clearColor];
	newLabel.opaque = NO;
	newLabel.textColor = primaryColor;
	newLabel.highlightedTextColor = selectedColor;
	newLabel.font = font;
	
	return newLabel;
}

@end
