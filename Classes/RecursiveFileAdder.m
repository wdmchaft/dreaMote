//
//  RecursiveFileAdder.m
//  dreaMote
//
//  Created by Moritz Venn on 13.01.11.
//  Copyright 2011 Moritz Venn. All rights reserved.
//

#import "RecursiveFileAdder.h"

#import "RemoteConnectorObject.h"

@interface RecursiveFileAdder()
- (void)fetchData;
@property (nonatomic, retain) NSObject<RecursiveFileAdderDelegate> *delegate;
@end

@implementation RecursiveFileAdder

@synthesize delegate = _delegate;

- (id)initWithPath:(NSString *)path
{
	if((self = [super init]))
	{
		_remainingPaths = [[NSMutableArray arrayWithObject:path] retain];
	}
	return self;
}

- (void)dealloc
{
	[_remainingPaths release];
	[_delegate release];

	[super dealloc];
}

/* add file to list */
- (void)addFile: (NSObject<FileProtocol> *)file
{
	// directory
	if(file.isDirectory)
	{
		// check if this is ".."
		NSString *sref = file.sref;
		NSRange rangeOfString = [sref rangeOfString:file.root];
		if(rangeOfString.location == NSNotFound) return;

		// it's not, add to our queue
		// TODO: add copy back if this actually uses a cxmldocument
		[_remainingPaths addObject:sref];
	}
	// file
	else if(file != nil)
	{
		[_delegate recursiveFileAdder:self addFile:file];
	}
}

/* start download of file list */
- (void)fetchData
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[_fileXMLDoc release];
	NSString *path = [[_remainingPaths lastObject] retain];
	[_remainingPaths removeLastObject];
	_fileXMLDoc = [[[RemoteConnectorObject sharedRemoteConnector] fetchFiles:self path:path] retain];
	[path release];
	[pool release];
}

- (void)addFilesToDelegate:(NSObject<RecursiveFileAdderDelegate> *)delegate
{
	self.delegate = delegate;
	[NSThread detachNewThreadSelector:@selector(fetchData) toTarget:self withObject:nil];
}

#pragma mark -
#pragma mark DataSourceDelegate
#pragma mark -

- (void)dataSourceDelegate:(BaseXMLReader *)dataSource errorParsingDocument:(CXMLDocument *)document error:(NSError *)error
{
	// alert user
	const UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failed to retrieve data", @"")
														  message:[error localizedDescription]
														 delegate:nil
												cancelButtonTitle:@"OK"
												otherButtonTitles:nil];
	[alert show];
	[alert release];

	// TODO: is it a good idea to try to continue at any cost?
	if([_remainingPaths count])
	{
		[NSThread detachNewThreadSelector:@selector(fetchData) toTarget:self withObject:nil];
	}
	else
	{
		[_delegate recursiveFileAdderDoneAddingFiles:self];
	}
}

- (void)dataSourceDelegate:(BaseXMLReader *)dataSource finishedParsingDocument:(CXMLDocument *)document
{
	if([_remainingPaths count])
	{
		[NSThread detachNewThreadSelector:@selector(fetchData) toTarget:self withObject:nil];
	}
	else
	{
		[_delegate recursiveFileAdderDoneAddingFiles:self];
	}
}

@end
