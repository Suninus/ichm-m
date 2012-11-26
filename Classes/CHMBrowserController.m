//
//  CHMBrowserController.m
//  iChm
//
//  Created by Robin Lu on 10/8/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "CHMBrowserController.h"
#import "ITSSProtocol.h"
#import "CHMDocument.h"
#import "TableOfContentController.h"
#import "DocumentSettingController.h"
#import "IndexController.h"
#import "CHMTableOfContent.h"
#import "iChmAppDelegate.h"

@interface CHMBrowserController (Private)

- (void)resetNavBar;
- (NSString*)extractPathFromURL:(NSURL*)url;
- (void)updateTOCButton;
- (void)willTerminate;
- (void)startLoadingIndicator;
- (void)stopLoadingIndicator;
- (void)setCurrentItem;
- (void)tocLoadFinished;
- (void)indexReady;
@end

@implementation CHMBrowserController

@synthesize currentItem;

// Override initWithNibName:bundle: to load the view using a nib file then perform additional customization that is not appropriate for viewDidLoad.
-(id)init
{
    if (self = [super initWithNibName:@"CHMBrowser" bundle:nil]) {
		// setup notification
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(tocLoadFinished) name:CHMDocumentTOCReady object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(indexReady) name:CHMDocumentIDXReady object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(willTerminate) name:UIApplicationWillTerminateNotification object:nil];
		rightBarControl = nil;
		currentItem = nil;
		needResetCurrentItem = NO;
    }
	
    return self;
}

/*
// Implement loadView to create a view hierarchy programmatically.
- (void)loadView {
}
 */

- (void)indexReady {
	[self performSelectorOnMainThread:@selector(updateTOCButton) withObject:nil waitUntilDone:NO];
}

- (void) updateTOCButton {
    if (!rightBarControl)
    {
        rightBarControl = [[UISegmentedControl alloc] initWithItems:
                                                        [NSArray arrayWithObjects:
                                                           [UIImage imageNamed:@"toc.png"],
                                                           [UIImage imageNamed:@"idx.png"],
                                                           nil]];
        [rightBarControl addTarget:self action:@selector(toTocOrIdx:) forControlEvents:UIControlEventValueChanged];
        rightBarControl.frame = CGRectMake(0, 0, 80, 30);
        rightBarControl.segmentedControlStyle = UISegmentedControlStyleBar;
        rightBarControl.momentary = YES;
        
        @synchronized(self)
        {
            UIBarButtonItem *segmentBarItem = [[[UIBarButtonItem alloc] initWithCustomView:rightBarControl] autorelease];
            self.navigationItem.rightBarButtonItem = segmentBarItem;
        }
    }
    [rightBarControl setEnabled:[[CHMDocument CurrentDocument] tocSource] != nil forSegmentAtIndex:0];
    [rightBarControl setEnabled:[[CHMDocument CurrentDocument] idxItems] != nil forSegmentAtIndex:1];
}

- (void) addLoadingTOCIndicator {
	@synchronized(self)
	{
		if (rightBarControl)
			return;
		UIActivityIndicatorView * loadingTOCView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
		UIBarButtonItem *segmentBarItem = [[UIBarButtonItem alloc] initWithCustomView:loadingTOCView];
		[loadingTOCView startAnimating];
		self.navigationItem.rightBarButtonItem = segmentBarItem;
		[loadingTOCView release];
		[segmentBarItem release];
	}
}

// Implement viewDidLoad to do additional setup after loading the view.
- (void)viewDidLoad {
    UISegmentedControl *fontControl = [[UISegmentedControl alloc] initWithItems:
                                            [NSArray arrayWithObjects:
                                                    [UIImage imageNamed:@"zoom-out.png"],
                                                    [UIImage imageNamed:@"zoom-in.png"],
                                             nil]];
    [fontControl addTarget:self action:@selector(zoom:) forControlEvents:UIControlEventValueChanged];
    fontControl.frame = CGRectMake(0, 0, 80, 30);
    fontControl.segmentedControlStyle = UISegmentedControlStyleBar;
    fontControl.momentary = YES;
    self.navigationItem.titleView = fontControl;
    [fontControl release];
	[self resetNavBar];

	CHMDocument * doc = [CHMDocument CurrentDocument];
	if ([doc tocIsReady]) {
		[self updateTOCButton];
	}
	else
	{
		[self addLoadingTOCIndicator];
	}

	self.view.autoresizesSubviews = YES;
	self.view.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
	webView.autoresizesSubviews = YES;
    webView.backgroundColor = [UIColor whiteColor];
	webView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
	NSString *scaleToFitPref = [[CHMDocument CurrentDocument] getPrefForKey:@"scale to fit" withDefault:@"NO"];
	if ([scaleToFitPref isEqualToString:@"YES"])
		webView.scalesPageToFit = YES;
		
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
	self.navigationController.navigationBar.barStyle = UIBarStyleDefault;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return interfaceOrientation != UIDeviceOrientationPortraitUpsideDown;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}

- (void)resetNavBar
{
	CHMTableOfContent *tocSource = [[CHMDocument CurrentDocument] tocSource];
	[backButton setEnabled:[webView canGoBack]];
	[forwardButton setEnabled:[webView canGoForward]];
	[pageupButton setEnabled:[tocSource canGoPrevPage:currentItem]];
	[pagedownButton setEnabled:[tocSource canGoNextPage:currentItem]];
}

- (void)realTocLoadFinished
{
	if (needResetCurrentItem)
	{
		[self setCurrentItem];
		needResetCurrentItem = NO;
	}
	[self updateTOCButton];
	[self resetNavBar];
}

- (void)tocLoadFinished
{
	[self performSelectorOnMainThread:@selector(realTocLoadFinished) withObject:nil waitUntilDone:NO];
}

- (NSString*)extractPathFromURL:(NSURL*)url
{
	return [[[url absoluteString] substringFromIndex:11] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [webView reload];
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)settingSaved
{
    needResetCurrentItem = YES;
    [[CHMDocument CurrentDocument] reloadTOC];
    [self updateTOCButton];
    [webView reload];
}
#pragma mark load page
- (void)loadPath:(NSString *)path
{
	NSURL *url = [self composeURL:path];
	[self loadURL:url];
}

- (void)loadURL:(NSURL *)url
{
	if( url ) {
		NSURLRequest *req = [NSURLRequest requestWithURL:url];
		[webView loadRequest:req];
	}
}

- (NSURL*)composeURL:(NSString *)path
{
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"itss://chm/%@", path]];
	if (!url)
		url = [NSURL URLWithString:[NSString stringWithFormat:@"itss://chm/%@", [path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
	return url;
}

#pragma mark ui actions
- (void)navHistory:(id)sender
{
	UISegmentedControl* segCtl = sender;
	// the segmented control was clicked, handle it here
	switch ([segCtl selectedSegmentIndex]) {
		case 0:
			[webView goBack];
			break;
		case 1:
			[self loadPath:[[CHMDocument CurrentDocument] homePath]];
			break;
		case 2:
			[webView goForward];
			break;
	}
}

- (void)toTocOrIdx:(id)sender
{
	UISegmentedControl* segCtl = sender;
	// the segmented control was clicked, handle it here
	switch ([segCtl selectedSegmentIndex]) {
		case 0:
			[self navToTOC:sender];
			break;
		case 1:
			[self navToIDX:sender];
			break;
	}
	self.navigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
}

- (void)navToIDX:(id)sender
{
	CHMDocument *doc = [CHMDocument CurrentDocument];
	IndexController* controller = [[[IndexController alloc]
									initWithBrowserController:self
								    idxSource:[[doc indexSource] rootItems] ] autorelease];
	[[self navigationController] pushViewController:controller animated:NO];
}

- (void)navToTOC:(id)sender
{
	CHMDocument *doc = [CHMDocument CurrentDocument];
	NSMutableArray *tocStack = [[NSMutableArray alloc] init];
	[[doc tocSource] itemForPath:[currentItem path] 
					  withStack:tocStack];
	if ([tocStack count])
	{
		NSEnumerator *enumerator = [tocStack reverseObjectEnumerator];
		for (LinkItem *p in enumerator) {
			TableOfContentController *tocController = [[[TableOfContentController alloc] initWithBrowserController:self tocRoot:p] autorelease];
			[[self navigationController] pushViewController:tocController animated:NO];
		}
	}
	else
	{
		LinkItem *p = [doc tocItems];
		TableOfContentController *tocController = [[[TableOfContentController alloc] initWithBrowserController:self tocRoot:p] autorelease];
		[[self navigationController] pushViewController:tocController animated:NO];		
	}
	[tocStack release];
}

- (IBAction)zoom:(id)sender
{
    UISegmentedControl* segCtl = sender;
	// the segmented control was clicked, handle it here
	switch ([segCtl selectedSegmentIndex]) {
		case 0:
			[self zoomOut:self];
			break;
		case 1:
			[self zoomIn:self];
			break;
	}    
}

- (IBAction)zoomIn:(id)sender
{
    [[CHMDocument CurrentDocument] zoomIn];
    [webView reload];
}

- (IBAction)zoomOut:(id)sender
{
    [[CHMDocument CurrentDocument] zoomOut];
    [webView reload];    
}

#pragma mark webviewdelegate
- (void)webViewDidStartLoad:(UIWebView *)webView
{
	[self startLoadingIndicator];
}

- (void)setCurrentItem
{
	CHMTableOfContent *toc = [[CHMDocument CurrentDocument] tocSource];
	if (toc == nil)
		return;

	NSURL *url = [webView.request URL];
	NSString *path = [self extractPathFromURL:url];
	currentItem = [toc itemForPath:path withStack:nil];
	if (currentItem == nil)
	{
		path = [[path componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"#?"]] objectAtIndex:0];
		currentItem = [toc itemForPath:path withStack:nil];
	}	
}

- (void)webViewDidFinishLoad:(UIWebView *)webview
{	
    NSURL *url = [webView.request URL];
	NSString *path = [self extractPathFromURL:url];
    [[CHMDocument CurrentDocument] setPref:path forKey:@"last path"];
    
	CHMTableOfContent *toc = [[CHMDocument CurrentDocument] tocSource];

    if (toc)
	{
		[self setCurrentItem];
	}
	else
		needResetCurrentItem = YES;
	
	[self resetNavBar];
	[self stopLoadingIndicator];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	[self stopLoadingIndicator];	
}

- (void)startLoadingIndicator
{
	[loadIndicatorView setHidden:NO];
	[loadIndicatorView startAnimating];
}

- (void)stopLoadingIndicator
{
	[loadIndicatorView stopAnimating];
	[loadIndicatorView setHidden:YES];
}

#pragma mark actions
- (IBAction)toggleFullScreen:(id)sender
{
	BOOL isHide = !self.navigationController.navigationBarHidden;
	self.navigationController.navigationBarHidden = isHide;
	[toolBar setHidden:isHide];
	[fullScreenButton setHidden:!isHide];
	CGFloat height = self.view.frame.size.height - (isHide ? 0 : toolBar.frame.size.height);
	CGRect frame = [webView frame];
	frame.size.height = height;
	[webView setFrame:frame];
}

- (IBAction)goHome:(id)sender
{
	[self loadPath:[[CHMDocument CurrentDocument] homePath]];
}

- (IBAction)goNextPage:(id)sender
{
	CHMTableOfContent *tocSource = [[ CHMDocument CurrentDocument] tocSource];
	LinkItem *item = [tocSource getNextPage:currentItem];
	[self loadPath:[item path]];
}

- (IBAction)goPrevPage:(id)sender
{
	CHMTableOfContent *tocSource = [[ CHMDocument CurrentDocument] tocSource];
	LinkItem *item = [tocSource getPrevPage:currentItem];
	[self loadPath:[item path]];
}

- (IBAction)toggleScaleToFit:(id)sender
{
	webView.scalesPageToFit = !webView.scalesPageToFit;

	NSString *value = webView.scalesPageToFit ? @"YES" : @"NO";
	[[CHMDocument CurrentDocument] setPref:value forKey:@"scale to fit"];
	[webView reload];
}

- (IBAction)openSettings:(id)sender
{
    DocumentSettingController *controller = [[DocumentSettingController alloc]
                                             initWithNibName:@"DocumentSetting" bundle:nil];
    [self.navigationController pushViewController:controller animated:YES];
    controller.delegate = self;
    [controller release];
}
#pragma mark dealloc
- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];	
	[rightBarControl release];
	[webView stopLoading];
	webView.delegate = nil;
    [super dealloc];
}

- (void)willTerminate
{
	// Save data if appropriate
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:[CHMDocument CurrentDocument].fileName forKey:@"last open file"];
	[defaults synchronize];
}
@end
