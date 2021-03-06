//
//  EventXMLReader.m
//  dreaMote
//
//  Created by Moritz Venn on 31.12.08.
//  Copyright 2008-2012 Moritz Venn. All rights reserved.
//

#import "EventXMLReader.h"

#import "Constants.h"
#import "NSDateFormatter+FuzzyFormatting.h"
#import "NSObject+Queue.h"

#import <Objects/Generic/Event.h>
#import <Objects/Generic/Service.h>

static const char *kEnigma2EventExtendedDescription = "e2eventdescriptionextended";
static const NSUInteger kEnigma2EventExtendedDescriptionLength = 27;
static const char *kEnigma2EventDescription = "e2eventdescription";
static const NSUInteger kEnigma2EventDescriptionLength = 19;
static const char *kEnigma2EventTitle = "e2eventtitle";
static const NSUInteger kEnigma2EventTitleLength = 13;
static const char *kEnigma2EventLegacyTitle = "e2eventname";
static const NSUInteger kEnigma2EventLegacyTitleLength = 12;
static const char *kEnigma2EventDuration = "e2eventduration";
static const NSUInteger kEnigma2EventDurationLength = 16;
static const char *kEnigma2EventBegin = "e2eventstart";
static const NSUInteger kEnigma2EventBeginLength = 13;
static const char *kEnigma2EventEventId = "e2eventid";
static const NSUInteger kEnigma2EventEventIdLength = 9;
static const char *kEnigma2EventSref = "e2eventservicereference";
static const NSUInteger kEnigma2EventSrefLength = 24;
static const char *kEnigma2EventSname = "e2eventservicename";
static const NSUInteger kEnigma2EventSnameLength = 19;

typedef enum {
	RESPONSE_UNKNOWN,
	RESPONSE_EVENTLIST,
	RESPONSE_NOW_OR_NEXT,
	RESPONSE_NOWNEXT,
} responseType_t;

@interface Enigma2EventXMLReader()
@property (nonatomic, strong) NSObject<EventProtocol> *currentEvent;
@property (nonatomic, strong) NSDateFormatter *formatter;
@property (nonatomic) responseType_t responseType;
@property (nonatomic) BOOL isNext;
@property (nonatomic, strong) NSMutableArray *nextItems;
@end

@implementation Enigma2EventXMLReader

@synthesize currentEvent, formatter, isNext, nextItems, responseType;

/* initialize */
- (id)initWithDelegate:(NSObject<DataSourceDelegate> *)delegate getServices:(BOOL)getServices selector:(SEL)selector responseType:(responseType_t)response
{
	if((self = [super init]))
	{
		if(response != RESPONSE_UNKNOWN)
		{
			formatter = [[NSDateFormatter alloc] init];
			[formatter setTimeStyle:NSDateFormatterShortStyle];
		}
		_delegate = delegate;
		_delegateSelector = selector;
		_getServices = getServices;
		responseType = response;
		_timeout = kTimeout * 2;
	}
	return self;
}

- (id)initWithDelegate:(NSObject<EventSourceDelegate> *)delegate
{
	if((self = [self initWithDelegate:delegate getServices:NO selector:@selector(addEvent:) responseType:RESPONSE_UNKNOWN]))
	{
		if([delegate respondsToSelector:@selector(addEvents:)])
			self.currentItems = [NSMutableArray arrayWithCapacity:kBatchDispatchItemsCount];
	}
	return self;
}

- (id)initWithDelegateAndGetServices:(NSObject<EventSourceDelegate> *)delegate getServices:(BOOL)getServices
{
	if((self = [self initWithDelegate:delegate getServices:getServices selector:@selector(addEvent:) responseType:RESPONSE_EVENTLIST]))
	{
		if([delegate respondsToSelector:@selector(addEvents:)])
			self.currentItems = [NSMutableArray arrayWithCapacity:kBatchDispatchItemsCount];
	}
	return self;
}

- (id)initWithNowNextDelegate:(NSObject<NowSourceDelegate,NextSourceDelegate> *)delegate
{
	if((self = [self initWithDelegate:delegate getServices:YES selector:NULL responseType:RESPONSE_NOWNEXT]))
	{
		if([delegate respondsToSelector:@selector(addNextEvents:)] && [delegate respondsToSelector:@selector(addNowEvents:)])
		{
			self.currentItems = [NSMutableArray arrayWithCapacity:kBatchDispatchItemsCount];
			self.nextItems = [NSMutableArray arrayWithCapacity:kBatchDispatchItemsCount];
			isNext = NO;
		}
	}
	return self;
}

- (id)initWithNowDelegate:(NSObject<NowSourceDelegate> *)delegate
{
	if((self = [self initWithDelegate:delegate getServices:YES selector:@selector(addNowEvent:) responseType:RESPONSE_NOW_OR_NEXT]))
	{
		if([delegate respondsToSelector:@selector(addNowEvents:)])
		{
			self.currentItems = [NSMutableArray arrayWithCapacity:kBatchDispatchItemsCount];
		}
	}
	return self;
}

- (id)initWithNextDelegate:(NSObject<NextSourceDelegate> *)delegate
{
	if((self = [self initWithDelegate:delegate getServices:NO selector:@selector(addNextEvent:) responseType:RESPONSE_NOW_OR_NEXT]))
	{
		if([delegate respondsToSelector:@selector(addNowEvents:)])
		{
			self.nextItems = [NSMutableArray arrayWithCapacity:kBatchDispatchItemsCount];
		}
	}
	return self;
}

/* send fake object */
- (void)errorLoadingDocument:(NSError *)error
{
	NSObject<EventProtocol> *fakeObject = [[GenericEvent alloc] init];
	fakeObject.title = NSLocalizedString(@"Error retrieving Data", @"");

	if(_getServices)
	{
		NSObject<ServiceProtocol> *fakeService = [[GenericService alloc] init];
		fakeService.sname = NSLocalizedString(@"Error retrieving Data", @"");
		[(GenericService *)fakeService setValid:NO];
		fakeObject.service = fakeService;
	}

	SEL selector = _delegateSelector;
	if(selector == NULL) // only possible in combined now/next where one callback should suffice
		selector = @selector(addNowEvent:);

	// for some reason this hides the "unknown selector" warning, so keep it for now :)
	[_delegate performSelectorOnMainThread:selector
								withObject:fakeObject
							 waitUntilDone:NO];
	[super errorLoadingDocument:error];
}

- (void)finishedParsingDocument
{
	if(self.currentItems.count)
	{
		if(_delegateSelector == NULL || _delegateSelector == @selector(addNowEvent:))
			[(NSObject<NowSourceDelegate> *)_delegate addNowEvents:self.currentItems];
		else
			[(NSObject<EventSourceDelegate> *)_delegate addEvents:self.currentItems];
		[self.currentItems removeAllObjects];
	}
	if(self.nextItems.count)
	{
		[(NSObject<NextSourceDelegate> *)_delegate addNextEvents:self.nextItems];
		[self.nextItems removeAllObjects];
	}
	[super finishedParsingDocument];
}

/*
 Example:
 <?xml version="1.0" encoding="UTF-8"?>
 <e2eventlist>
 <e2event>
 <e2eventid>40710</e2eventid>
 <e2eventstart>1205037000</e2eventstart>
 <e2eventduration>1500</e2eventduration>
 <e2eventtitle>Aktion Schulstreich</e2eventtitle>
 <e2eventdescription>1. Hauptschule Sonthofen - Motto: Wir nageln Deutsch und Mathe an die Wand</e2eventdescription>
 <e2eventdescriptionextended>In dieser ersten Folge kommt der Notruf aus dem Allgäu. Die Räume der Hauptschule in der Alpenstadt Sonthofen sind ziemlich farblos und erinnern mehr an ein Kloster, als an eine fröhliche Schule.</e2eventdescriptionextended>
 <e2eventservicereference>1:0:1:6DCA:44D:1:C00000:0:0:0:</e2eventservicereference>
 <e2eventservicename>Das Erste</e2eventservicename>
 </e2event>
 </e2eventlist>
*/
- (void)elementFound:(const xmlChar *)localname prefix:(const xmlChar *)prefix uri:(const xmlChar *)URI namespaceCount:(int)namespaceCount namespaces:(const xmlChar **)namespaces attributeCount:(int)attributeCount defaultAttributeCount:(int)defaultAttributeCount attributes:(xmlSAX2Attributes *)attributes
{
	if(!strncmp((const char *)localname, kEnigma2EventElement, kEnigma2EventElementLength))
	{
		self.currentEvent = [[GenericEvent alloc] init];
		if(_getServices)
		{
			GenericService *service = [[GenericService alloc] init];
			self.currentEvent.service = service;
		}
	}
	else if(	!strncmp((const char *)localname, kEnigma2EventExtendedDescription, kEnigma2EventExtendedDescriptionLength)
			||	!strncmp((const char *)localname, kEnigma2EventDescription, kEnigma2EventDescriptionLength)
			||	!strncmp((const char *)localname, kEnigma2EventTitle, kEnigma2EventTitleLength)
			||	!strncmp((const char *)localname, kEnigma2EventLegacyTitle, kEnigma2EventLegacyTitleLength)
			||	!strncmp((const char *)localname, kEnigma2EventDuration, kEnigma2EventDurationLength)
			||	!strncmp((const char *)localname, kEnigma2EventBegin, kEnigma2EventBeginLength)
			||	!strncmp((const char *)localname, kEnigma2EventEventId, kEnigma2EventEventIdLength)
			||	(_getServices && (
					!strncmp((const char *)localname, kEnigma2EventSref, kEnigma2EventSrefLength)
				||	!strncmp((const char *)localname, kEnigma2EventSname, kEnigma2EventSnameLength)
			)	)
		)
	{
		currentString = [[NSMutableString alloc] init];
	}
}

- (void)endElement:(const xmlChar *)localname prefix:(const xmlChar *)prefix uri:(const xmlChar *)URI
{
	if([currentString isEqualToString:@"None"])
	{
		self.currentString = nil;
		return;
	}

	if(!strncmp((const char *)localname, kEnigma2EventElement, kEnigma2EventElementLength))
	{
		SEL selector = _delegateSelector;
		switch(responseType)
		{
			default: break;
			case RESPONSE_NOWNEXT:
			{
				_getServices = isNext; // if current is "next", next event will be "now" and thus we need to get the service
				selector = isNext ? @selector(addNextEvent:) : @selector(addNowEvent:);
				isNext = !isNext;
				/* FALL THROUGH */
			}
			case RESPONSE_NOW_OR_NEXT:
			{
				const NSString *begin = [formatter stringFromDate:currentEvent.begin];
				const NSString *end = [formatter stringFromDate:currentEvent.end];
				if(begin && end)
					currentEvent.timeString = [NSString stringWithFormat: @"%@ - %@", begin, end];
				break;
			}
			case RESPONSE_EVENTLIST:
			{
				[formatter setDateStyle:NSDateFormatterMediumStyle];
				const NSString *begin = [formatter fuzzyDate:currentEvent.begin];
				[formatter setDateStyle:NSDateFormatterNoStyle];
				const NSString *end = [formatter stringFromDate:currentEvent.end];
				if(begin && end)
					currentEvent.timeString = [NSString stringWithFormat: @"%@ - %@", begin, end];
				break;
			}
		}

		if(selector == @selector(addNowEvent:) && self.currentItems)
		{
			[self.currentItems addObject:currentEvent];
			if(self.currentItems.count > kBatchDispatchItemsCount)
			{
				NSArray *dispatchArray = [self.currentItems copy];
				[self.currentItems removeAllObjects];
				[[_delegate queueOnMainThread] addNowEvents:dispatchArray];
			}
		}
		else if(selector == @selector(addEvent:) && self.currentItems)
		{
			[self.currentItems addObject:currentEvent];
			if(self.currentItems.count > kBatchDispatchItemsCount)
			{
				NSArray *dispatchArray = [self.currentItems copy];
				[self.currentItems removeAllObjects];
				[[_delegate queueOnMainThread] addEvents:dispatchArray];
			}
		}
		else if(selector == @selector(addNextEvent:) && self.nextItems)
		{
			[self.nextItems addObject:currentEvent];
			if(self.nextItems.count >= kBatchDispatchItemsCount)
			{
				NSArray *dispatchArray = [self.nextItems copy];
				[self.nextItems removeAllObjects];
				[[_delegate queueOnMainThread] addNextEvents:dispatchArray];
			}
		}
		else
		{
			// TODO: not using queueOnMainThread here because of "unknown selector" warning
			[_delegate performSelectorOnMainThread:selector
										withObject:currentEvent
									 waitUntilDone:NO];
		}
	}
	else if(!strncmp((const char *)localname, kEnigma2EventExtendedDescription, kEnigma2EventExtendedDescriptionLength))
	{
		currentEvent.edescription = currentString;
	}
	else if(!strncmp((const char *)localname, kEnigma2EventDescription, kEnigma2EventDescriptionLength))
	{
		currentEvent.sdescription = currentString;
	}
	else if(	!strncmp((const char *)localname, kEnigma2EventTitle, kEnigma2EventTitleLength)
			||	!strncmp((const char *)localname, kEnigma2EventLegacyTitle, kEnigma2EventLegacyTitleLength)
		)
	{
		currentEvent.title = currentString;
	}
	else if(!strncmp((const char *)localname, kEnigma2EventDuration, kEnigma2EventDurationLength))
	{
		[currentEvent setEndFromDurationString:currentString];
	}
	else if(!strncmp((const char *)localname, kEnigma2EventBegin, kEnigma2EventBeginLength))
	{
		[currentEvent setBeginFromString:currentString];
	}
	else if(!strncmp((const char *)localname, kEnigma2EventEventId, kEnigma2EventEventIdLength))
	{
		currentEvent.eit = currentString;
	}
	else if(_getServices)
	{
		if(!strncmp((const char *)localname, kEnigma2EventSref, kEnigma2EventSrefLength))
		{
			currentEvent.service.sref = currentString;
			// if service begins with 1:64: this is a marker
			if([currentString hasPrefix:@"1:64:"])
				[(GenericService *)currentEvent.service setValid:NO];
		}
		else if(!strncmp((const char *)localname, kEnigma2EventSname, kEnigma2EventSnameLength))
		{
			currentEvent.service.sname = currentString;
		}
	}

	// this either does nothing or releases the string that was in use
	self.currentString = nil;
}

@end
