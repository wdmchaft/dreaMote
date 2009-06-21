//
//  ServiceListController.m
//  dreaMote
//
//  Created by Moritz Venn on 08.03.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "ServiceListController.h"

#import "EventListController.h"

#import "RemoteConnectorObject.h"
#import "Objects/ServiceProtocol.h"

#import "ServiceTableViewCell.h"

@implementation ServiceListController

/* initialize */
- (id)init
{
	self = [super init];
	if (self) {
		self.title = NSLocalizedString(@"Services", @"Title of ServiceListController");
		_services = [[NSMutableArray array] retain];
		_refreshServices = YES;
		_eventListController = nil;
	}
	return self;
}

/* dealloc */
- (void)dealloc
{
	[_services release];
	[_eventListController release];
	[_serviceXMLDoc release];

	[super dealloc];
}

/* memory warning */
- (void)didReceiveMemoryWarning
{
	[_eventListController release];
	_eventListController = nil;

	[super didReceiveMemoryWarning];
}

/* getter for bouquet property */
- (NSObject<ServiceProtocol> *)bouquet
{
	return _bouquet;
}

/* setter for bouquet property */
- (void)setBouquet: (NSObject<ServiceProtocol> *)new
{
	// Same bouquet assigned, abort
	if(_bouquet == new) return;

	// Free old bouquet, retain new one
	[_bouquet release];
	_bouquet = [new retain];

	// Set Title
	self.title = new.sname;

	// Free Caches and reload data
	[_services removeAllObjects];
	[(UITableView *)self.view reloadData];
	[_serviceXMLDoc release];
	_serviceXMLDoc = nil;
	_refreshServices = NO;

	// Spawn a thread to fetch the event data so that the UI is not blocked while the
	// application parses the XML file.
	[NSThread detachNewThreadSelector:@selector(fetchServices) toTarget:self withObject:nil];
}

/* layout */
- (void)loadView
{
	UITableView *tableView = [[UITableView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame] style:UITableViewStylePlain];
	tableView.delegate = self;
	tableView.dataSource = self;
	tableView.rowHeight = 38.0;
	tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
	tableView.sectionHeaderHeight = 0;

	// setup our content view so that it auto-rotates along with the UViewController
	tableView.autoresizesSubviews = YES;
	tableView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);

	self.view = tableView;
	[tableView release];
}

/* about to appear */
- (void)viewWillAppear:(BOOL)animated
{
	/*!
	 @brief See if we should refresh services
	 @note If bouquet is nil we are in single bouquet mode and therefore we refresh here
	 and not in setBouquet:
	 */
	if(_refreshServices && _bouquet == nil)
	{
		[_services removeAllObjects];

		[(UITableView *)self.view reloadData];
		[_serviceXMLDoc release];
		_serviceXMLDoc = nil;

		// Spawn a thread to fetch the service data so that the UI is not blocked while the
		// application parses the XML file.
		[NSThread detachNewThreadSelector:@selector(fetchServices) toTarget:self withObject:nil];
	}

	_refreshServices = YES;

	[super viewWillAppear: animated];
}

/* did disappear */
- (void)viewDidDisappear:(BOOL)animated
{
	if(_refreshServices && _bouquet == nil)
	{
		[_services removeAllObjects];

		[_eventListController release];
		_eventListController = nil;
		[_serviceXMLDoc release];
		_serviceXMLDoc = nil;
	}
}

/* fetch service list */
- (void)fetchServices
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[_serviceXMLDoc release];
	_serviceXMLDoc = [[[RemoteConnectorObject sharedRemoteConnector] fetchServices:self action:@selector(addService:) bouquet: _bouquet] retain];
	[pool release];
}

/* add service to list */
- (void)addService:(id)service
{
	if(service != nil)
	{
		[_services addObject: service];
#ifdef ENABLE_LAGGY_ANIMATIONS
		[(UITableView*)self.view insertRowsAtIndexPaths: [NSArray arrayWithObject: [NSIndexPath indexPathForRow:[_services count]-1 inSection:0]]
						withRowAnimation: UITableViewRowAnimationTop];
	}
	else
#else
	}
#endif
		[(UITableView *)self.view reloadData];
}

#pragma mark	-
#pragma mark		Table View
#pragma mark	-

/* cell for row */
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	ServiceTableViewCell *cell = (ServiceTableViewCell*)[tableView dequeueReusableCellWithIdentifier: kServiceCell_ID];
	if(cell == nil)
		cell = [[[ServiceTableViewCell alloc] initWithFrame: CGRectZero reuseIdentifier: kServiceCell_ID] autorelease];

	cell.service = [_services objectAtIndex:indexPath.row];

	return cell;
}

/* row selected */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSObject<ServiceProtocol> *service = [_services objectAtIndex: indexPath.row];

	// Check for invalid service
	if(!service.valid)
		[tableView deselectRowAtIndexPath: indexPath animated: YES];
	// Callback mode
	else if(_selectTarget != nil && _selectCallback != nil)
	{
		[_selectTarget performSelector:(SEL)_selectCallback withObject: service];
		// XXX: this requires _selectTarget to be an UIViewController!
		[self.navigationController popToViewController: _selectTarget animated: YES];
	}
	// Show UIActionSheet
	else
	{
		UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"What to do with the currently selected Service?", @"UIActionSheet when List Item in ServiceListController selected")
																delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") destructiveButtonTitle:nil otherButtonTitles:NSLocalizedString(@"Zap", @""), NSLocalizedString(@"Show EPG", @""), nil];
		[actionSheet showInView: tableView];
		[actionSheet release];
	}
}

/* action sheet callback */
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex: (NSInteger)buttonIndex
{
	NSObject<ServiceProtocol> *service = [(ServiceTableViewCell *)[(UITableView*)self.view cellForRowAtIndexPath: [(UITableView*)self.view indexPathForSelectedRow]] service];

	if (buttonIndex == 0)
	{
		// Second Button: zap
		[[RemoteConnectorObject sharedRemoteConnector] zapTo: service];
	}
	else if (buttonIndex == 1)
	{
		// Third Button: epg
		if(_eventListController == nil)
			_eventListController = [[EventListController alloc] init];

		_eventListController.service = service;

		_refreshServices = NO;
		[self.navigationController pushViewController: _eventListController animated:YES];
	}

	NSIndexPath *tableSelection = [(UITableView*)self.view indexPathForSelectedRow];
	[(UITableView*)self.view deselectRowAtIndexPath:tableSelection animated: NO]; // XXX: looks buggy if animated...
}

/* number of sections */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	// TODO: handle seperators?
	return 1;
}

/* number of rows */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	return [_services count];
}

/* set callback */
- (void)setTarget: (id)target action: (SEL)action
{
	/*!
	 @note We do not retain the target, this theoretically could be a problem but
	 is not in this case.
	 */
	_selectTarget = target;
	_selectCallback = action;
}

/* rotate with device */
- (BOOL)shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

@end
