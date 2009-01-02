//
//  Enigma2Connector.m
//  dreaMote
//
//  Created by Moritz Venn on 08.03.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "Enigma2Connector.h"

#import "Objects/ServiceProtocol.h"
#import "Objects/TimerProtocol.h"

#import "XMLReader/Enigma2/ServiceXMLReader.h"
#import "XMLReader/Enigma2/EventXMLReader.h"
#import "XMLReader/Enigma2/TimerXMLReader.h"
#import "XMLReader/Enigma2/VolumeXMLReader.h"
#import "XMLReader/Enigma2/MovieXMLReader.h"

enum powerStates {
	kShutdownState = 1,
	kRebootState = 2,
	kRestartGUIState = 3,
};

@implementation Enigma2Connector

@synthesize baseAddress;

- (const BOOL)hasFeature: (enum connectorFeatures)feature
{
	return 
		(feature != kFeaturesMessageCaption);
}

- (NSInteger)getMaxVolume
{
	return 100;
}

- (id)initWithAddress:(NSString *) address
{
	if(self = [super init])
	{
		self.baseAddress = [NSURL URLWithString: address];
	}
	return self;
}

- (void)dealloc
{
	[baseAddress release];

	[super dealloc];
}

+ (NSObject <RemoteConnector>*)createClassWithAddress:(NSString *) address
{
	return (NSObject <RemoteConnector>*)[[Enigma2Connector alloc] initWithAddress: address];
}

- (BOOL)isReachable
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString:@"/web/about" relativeToURL:baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	NSHTTPURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	[NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	return ([response statusCode] == 200);
}

- (BOOL)zapTo:(NSObject<ServiceProtocol> *) service
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString:[NSString stringWithFormat:@"/web/zap?sRef=%@", [service.sref stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]] relativeToURL:baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	// Create URL Object and download it
	NSHTTPURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	[NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	return ([response statusCode] == 200);
}

- (CXMLDocument *)fetchBouquets:(id)target action:(SEL)action
{
	NSURL *myURI = [NSURL URLWithString: @"/web/getservices" relativeToURL: baseAddress];

	BaseXMLReader *streamReader = [[Enigma2ServiceXMLReader alloc] initWithTarget: target action: action];
	CXMLDocument *doc = [streamReader parseXMLFileAtURL: myURI parseError: nil];
	[streamReader autorelease];
	return doc;
}

- (CXMLDocument *)fetchServices:(id)target action:(SEL)action bouquet:(NSObject<ServiceProtocol> *)bouquet;
{
	NSString *sref = nil;
	if(!bouquet) // single bouquet mode
		sref =  @"1:7:1:0:0:0:0:0:0:0:FROM%20BOUQUET%20%22userbouquet.favourites.tv%22%20ORDER%20BY%20bouquet";
	else
		sref = [bouquet.sref stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat:@"/web/getservices?sRef=%@", sref] relativeToURL:baseAddress];

	BaseXMLReader *streamReader = [[Enigma2ServiceXMLReader alloc] initWithTarget: target action: action];
	CXMLDocument *doc = [streamReader parseXMLFileAtURL: myURI parseError: nil];
	[streamReader autorelease];
	return doc;
}

- (CXMLDocument *)fetchEPG:(id)target action:(SEL)action service:(NSObject<ServiceProtocol> *)service
{
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat:@"/web/epgservice?sRef=%@", service.sref] relativeToURL: baseAddress];

	BaseXMLReader *streamReader = [[Enigma2EventXMLReader alloc] initWithTarget: target action: action];
	CXMLDocument *doc = [streamReader parseXMLFileAtURL: myURI parseError: nil];
	[streamReader autorelease];
	return doc;
}

- (CXMLDocument *)fetchTimers:(id)target action:(SEL)action
{
	NSURL *myURI = [NSURL URLWithString: @"/web/timerlist" relativeToURL: baseAddress];

	BaseXMLReader *streamReader = [[Enigma2TimerXMLReader alloc] initWithTarget: target action: action];
	CXMLDocument *doc = [streamReader parseXMLFileAtURL: myURI parseError: nil];
	[streamReader autorelease];
	return doc;
}

- (CXMLDocument *)fetchMovielist:(id)target action:(SEL)action
{
	NSURL *myURI = [NSURL URLWithString: @"/web/movielist" relativeToURL: baseAddress];

	BaseXMLReader *streamReader = [[Enigma2MovieXMLReader alloc] initWithTarget: target action: action];
	CXMLDocument *doc = [streamReader parseXMLFileAtURL: myURI parseError: nil];
	[streamReader autorelease];
	return doc;
}

- (void)sendPowerstate: (NSInteger) newState
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat:@"/web/powerstate?newstate=%d", newState] relativeToURL: baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	// Create URL Object and download it
	NSURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	[NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)shutdown
{
	[self sendPowerstate: kShutdownState];
}

- (void)standby
{
	// XXX: we send remote control command button power here as we want to toggle standby
	[self sendButton: kButtonCodePower];
}

- (void)reboot
{
	[self sendPowerstate: kRebootState];
}

- (void)restart
{
	[self sendPowerstate: kRestartGUIState];
}

- (void)getVolume:(id)target action:(SEL)action
{
	NSURL *myURI = [NSURL URLWithString: @"/web/vol" relativeToURL: baseAddress];

	Enigma2VolumeXMLReader *streamReader = [[Enigma2VolumeXMLReader alloc] initWithTarget: target action: action];
	[streamReader parseXMLFileAtURL:myURI parseError: nil];
	[streamReader autorelease];
}

- (BOOL)toggleMuted
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString: @"/web/vol?set=mute" relativeToURL: baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	// Create URL Object and download it
	NSURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	NSData *data = [NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];
	
	NSString *myString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	NSRange myRange = [myString rangeOfString: @"<e2ismuted>True</e2ismuted>"];
	[myString release];
	if(myRange.length)
		return YES;

	return NO;
}

- (BOOL)setVolume:(NSInteger) newVolume
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat:@"/web/vol?set=set%d", newVolume] relativeToURL: baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	// Create URL Object and download it
	NSURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	NSData *data = [NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];
	
	NSString *myString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	NSRange myRange = [myString rangeOfString: @"<e2result>True</e2result>"];
	[myString release];
	if(myRange.length)
		return YES;
	
	return NO;
}

- (BOOL)addTimer:(NSObject<TimerProtocol> *) newTimer
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat: @"/web/timeradd?sRef=%@&begin=%d&end=%d&name=%@&description=%@&eit=%@&disabled=%d&justplay=%d&afterevent=%d", newTimer.service.sref, (int)[newTimer.begin timeIntervalSince1970], (int)[newTimer.end timeIntervalSince1970], [newTimer.title stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding], [newTimer.tdescription stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding], newTimer.eit, newTimer.disabled ? 1 : 0, newTimer.justplay ? 1 : 0, newTimer.afterevent] relativeToURL: baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	// Create URL Object and download it
	NSURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	NSData *data = [NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];
	
	NSString *myString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	NSRange myRange = [myString rangeOfString: @"<e2state>True</e2state>"];
	[myString release];
	if(myRange.length)
		return YES;
	
	return NO;
}

- (BOOL)editTimer:(NSObject<TimerProtocol> *) oldTimer: (NSObject<TimerProtocol> *) newTimer
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat: @"/web/timerchange?sRef=%@&begin=%d&end=%d&name=%@&description=%@&eit=%@&disabled=%d&justplay=%d&afterevent=%d&channelOld=%@&beginOld=%d&endOld=%d&deleteOldOnSave=1", newTimer.service.sref, (int)[newTimer.begin timeIntervalSince1970], (int)[newTimer.end timeIntervalSince1970], [newTimer.title stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding], [newTimer.tdescription stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding], newTimer.eit, newTimer.disabled ? 1 : 0, newTimer.justplay ? 1 : 0, newTimer.afterevent, oldTimer.service.sref, (int)[oldTimer.begin timeIntervalSince1970], (int)[oldTimer.end timeIntervalSince1970]] relativeToURL: baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	// Create URL Object and download it
	NSURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	NSData *data = [NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];
	
	NSString *myString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	NSRange myRange = [myString rangeOfString: @"<e2state>True</e2state>"];
	[myString release];
	if(myRange.length)
		return YES;
	
	return NO;
}

- (BOOL)delTimer:(NSObject<TimerProtocol> *) oldTimer
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat: @"/web/timerdelete?sRef=%@&begin=%d&end=%d", oldTimer.service.sref, (int)[oldTimer.begin timeIntervalSince1970], (int)[oldTimer.end timeIntervalSince1970]] relativeToURL: baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	// Create URL Object and download it
	NSURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	NSData *data = [NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];
	
	NSString *myString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	NSRange myRange = [myString rangeOfString: @"<e2state>True</e2state>"];
	[myString release];
	if(myRange.length)
		return YES;
	
	return NO;
}

- (BOOL)sendButton:(NSInteger) type
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat: @"/web/remotecontrol?command=%d", type] relativeToURL: baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	// Create URL Object and download it
	NSURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	NSData *data = [NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];
	
	NSString *myString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	NSRange myRange = [myString rangeOfString: @"<e2result>True</e2result>"];
	[myString release];
	if(myRange.length)
		return YES;
	
	return NO;
}

- (BOOL)sendMessage:(NSString *)message: (NSString *)caption: (NSInteger)type: (NSInteger)timeout
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat: @"/web/message?text=%@&type=%d&timeout=%d", [message  stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding], type, timeout] relativeToURL: baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	// Create URL Object and download it
	NSURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	NSData *data = [NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];

	NSString *myString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	NSRange myRange = [myString rangeOfString: @"<e2result>True</e2result>"];
	[myString release];
	if(myRange.length)
		return YES;

	return NO;
}

- (NSData *)getScreenshot: (enum screenshotType)type
{
	NSString *appendType = nil;
	switch(type)
	{
		case kScreenshotTypeOSD:
			appendType = @"?command=o";
			break;
		case kScreenshotTypeVideo:
			appendType = @"?command=v";
			break;
		case kScreenshotTypeBoth:
		default:
			appendType = @"";
			break;
	}

	// Generate URI
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat: @"/grab%@", appendType] relativeToURL: baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	// Create URL Object and download it
	NSURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	NSData *data = [NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	return data;
}

- (void)freeCaches
{
	// XXX: We don't use any caches
}

@end
