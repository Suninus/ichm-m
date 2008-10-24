//
//  FileResource.m
//  iChm
//
//  Created by Robin Lu on 10/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "FileResource.h"
#import "RegexKitLite.h"
#import "HTTPConnection.h"

@implementation FileResource

+ (BOOL)canHandle:(CFHTTPMessageRef)request
{
	CFURLRef url = CFHTTPMessageCopyRequestURL(request);
	NSString* fullpath = [(NSString*)CFURLCopyPath(url) autorelease];
	NSString* path = [[fullpath componentsSeparatedByString:@"/"] objectAtIndex:1];
	NSLog(path);
	path = [[path componentsSeparatedByString:@"."] objectAtIndex:0];
	NSComparisonResult rslt = [path caseInsensitiveCompare:@"files"];
	CFRelease(url);
	return rslt == NSOrderedSame;
}

- (id)initWithConnection:(HTTPConnection*)conn
{
	if (self = [self init])
	{
		request = conn.request;
		boundary = nil;
		parameters = conn.params;
		connection = conn;
		[connection retain];
	}
	return self;
}

- (void)dealloc
{
	[connection release];
	[super dealloc];
}

- (void)handleRequest
{
	CFURLRef url = CFHTTPMessageCopyRequestURL(request);
	NSString *method = [(NSString *)CFHTTPMessageCopyRequestMethod(request) autorelease];
	NSString* path = [(NSString*)CFURLCopyPath(url) autorelease];
	if ([method isEqualToString:@"GET"])
	{
		if ([path caseInsensitiveCompare:@"/files"])
			[self actionList];
		else
			[self actionShow];
	}
	else if (([method isEqualToString:@"POST"]))
	{
		[self actionNew];
	}
	
	CFRelease(url);
}

- (void)actionList
{
}

- (void)actionShow
{
}

- (void)actionNew
{
	NSString *filename = [parameters objectForKey:@"newfile"];
	NSString* docDir = [NSString stringWithFormat:@"%@/Documents", NSHomeDirectory()];
	NSString *filePath = [NSString stringWithFormat:@"%@/%@", docDir, filename];
	NSString *tmpfile = [parameters objectForKey:@"tmpfilename"];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSError *error;
	[fm moveItemAtPath:tmpfile toPath:filePath error:&error];
	[connection redirectoTo:@"/"];
}
	
@end