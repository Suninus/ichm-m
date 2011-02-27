//
//  RootViewController.m
//  iChm
//
//  Created by Robin Lu on 10/7/08.
//  Copyright __MyCompanyName__ 2008. All rights reserved.
//

#import "RootViewController.h"
#import "iChmAppDelegate.h"
#import "CHMDocument.h"
#import "TableOfContentController.h"
#import "CHMBrowserController.h"
#import "FileManagerController.h"
#import "HTTPServer.h"
#import "AboutPageController.h"

@interface RootViewController (Private)

- (NSArray*) fileList;

@end

@implementation RootViewController

#pragma mark init
- (void)awakeFromNib
{
	self.title = NSLocalizedString(@"iChm", @"iChm");
	[[NSNotificationCenter defaultCenter] addObserver:self
			 selector:@selector(updateFilelist:) name:HTTPUploadingFinishedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
			 selector:@selector(updateFilelist:) name:HTTPFileDeletedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateFilelist:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
	fileManagerController = nil;
	
	// about page
	UIButton* aboutViewButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
	[aboutViewButton addTarget:self action:@selector(aboutPage:) forControlEvents:UIControlEventTouchUpInside];
	UIBarButtonItem *aboutButton = [[UIBarButtonItem alloc] initWithCustomView:aboutViewButton];
	self.navigationItem.rightBarButtonItem = aboutButton;
	[aboutButton release];
	
	self.tableView.rowHeight = 40;
}

- (NSArray*) fileList
{
	iChmAppDelegate* appDelegate = [[UIApplication sharedApplication] delegate];
	return [appDelegate fileList];
}

- (NSArray*) fileTitleList
{
	iChmAppDelegate* appDelegate = [[UIApplication sharedApplication] delegate];
	return [appDelegate fileTitleList];
}
#pragma mark tableView
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1 ;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if ([[self fileList] count] == 0)
		return 1;
	else
		return [[self fileList] count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"fileListCell";
    static NSString *EmptyCellIdentifier = @"EmptyFileListCell";
    
    UITableViewCell *cell;
	if ([[self fileList] count] == 0)
	{
		cell = [tableView dequeueReusableCellWithIdentifier:EmptyCellIdentifier];
		if (cell == nil)
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:EmptyCellIdentifier] autorelease];
		cell.textLabel.text = NSLocalizedString(@"Start File Manager to upload files", @"Start File Manager to upload files");
		cell.accessoryType = UITableViewCellSeparatorStyleNone;
		cell.imageView.image = [UIImage imageNamed:@"uparrow.png"];
		cell.textLabel.font = [UIFont italicSystemFontOfSize:16];		
	}
	else {
		cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil)
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
        cell.textLabel.text = [[self fileTitleList] objectAtIndex:indexPath.row];
        cell.detailTextLabel.text = [[self fileList] objectAtIndex:indexPath.row];
	}
    return cell;
}


- (void) launchBrowserForFile: (NSString *) filename  {
    CHMDocument *doc = [CHMDocument OpenDocument:filename];
	CHMBrowserController *browserController = [[CHMBrowserController alloc] init];
	[[self navigationController] pushViewController:browserController animated:YES];
	
	NSString *docPath = [doc getPrefForKey:@"last path" withDefault:[doc homePath]];
	[browserController loadPath:docPath];
	
	[browserController release];

}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([[self fileList] count] == 0)
    {
        [self startFileManager:self];
		return;
    }
	
    // Navigation logic -- create and push a new view controller
	NSString* filename = [[self fileList] objectAtIndex:indexPath.row];
	[self launchBrowserForFile: filename];

}


/*
- (void)viewDidLoad {
    [super viewDidLoad];
    // Uncomment the following line to add the Edit button to the navigation bar.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}
*/


/*
// Override to support editing the list
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    }   
    if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/


/*
// Override to support conditional editing of the list
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/


/*
// Override to support rearranging the list
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


/*
// Override to support conditional rearranging of the list
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
	
	// restore latest page
	NSString *key = @"last open file";
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString* filename = [defaults stringForKey:key];
	if (filename && [[self fileList] indexOfObject:filename] != NSNotFound)
	{
		[self launchBrowserForFile:filename];
	}
	[defaults removeObjectForKey:key];
	self.navigationController.navigationBar.topItem.title = NSLocalizedString(@"iChm", @"iChm");
}
/*
- (void)viewWillDisappear:(BOOL)animated {
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
}
*/

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return NO;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}


- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];	
	[fileManagerController release];
    [super dealloc];
}

#pragma mark actions
- (IBAction)startFileManager:(id)sender
{
	if (nil == fileManagerController)
		fileManagerController = [[FileManagerController alloc] init];
	[self.navigationController pushViewController:fileManagerController animated:YES];
}

- (IBAction)aboutPage:(id)sender
{
	AboutPageController *aboutPageController = [[AboutPageController alloc] init];
	[[self navigationController] pushViewController:aboutPageController animated:YES];
    [aboutPageController release];
}

#pragma mark notification
- (void)updateFilelist:(NSNotification*)notification
{
	iChmAppDelegate* appDelegate = [[UIApplication sharedApplication] delegate];
	[appDelegate reloadFileList];
	[self.tableView reloadData];
}
@end
