//
//  CHMTableOfContent.m
//  ichm
//
//  Created by Robin Lu on 7/18/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "CHMTableOfContent.h"
#import <libxml/HTMLparser.h>
//#import <libxml2/libxml/HTMLparser.h>
#import "CHMDocument.h"

@implementation LinkItem
@synthesize pageID;

- (id)init
{
	_children = [[NSMutableArray alloc] init];
	_name = nil;
	_path = nil;
	return self;
}

- (void)setPageID:(NSUInteger)pageid
{
	pageID = pageid;
}

- (void) dealloc
{
	[_children release];
	[_path release];
	[_name release];
	[super dealloc];
}

- (id)initWithName:(NSString *)name Path:(NSString *)path
{
	[self init];
	_name = name;
	_path = path;
	[_name retain];
	[_path retain];
	return self;
}

- (void)setName:(NSString *)name
{
	[_name release];
	_name = name;
	[_name retain];
}

- (void)setPath:(NSString *)path
{
	[_path release];
	_path = path;
	[_path retain];
}

- (int)numberOfChildren
{
	return _children ? [_children count] : 0;
}

- (LinkItem *)childAtIndex:(int)n
{
	return [_children objectAtIndex:n];
}

- (NSString *)name
{
	return _name;
}

- (NSString *)uppercaseName
{
	return [_name uppercaseString];
}

- (NSString *)path
{
	return _path;
}

- (NSMutableArray*)children
{
	return _children;
}

- (void)appendChild:(LinkItem *)item
{
	if(!_children)
		_children = [[NSMutableArray alloc] init];
	[_children addObject:item];
}

- (LinkItem*)find_by_path:(NSString *)path withStack:(NSMutableArray*)stack
{
	NSString *p = _path;
	if( [p hasPrefix:@"/"] ) {
		p = [p substringFromIndex:1];
    }
	else if ( [p hasPrefix:@"./"] ) {
		p = [p substringFromIndex:2];
	}
	
	if ([p isEqualToString:path])
		return self;
	
	if(!_children)
		return nil;
	
	for (LinkItem* item in _children) {
		LinkItem * rslt = [item find_by_path:path withStack:stack];
		if (rslt != nil)
		{
			if(stack)
				[stack addObject:self];
			return rslt;
		}
	}
	
	return nil;
}

- (void)enumerateItemsWithSEL:(SEL)selector ForTarget:(id)target
{
	if (![_path isEqualToString:@"/"])
		[target performSelector:selector withObject:self];
	for (LinkItem* item in _children)
	{
		[item enumerateItemsWithSEL:selector ForTarget:target];
	}
}

- (void)sort
{
	NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"uppercaseName" ascending:YES];
	NSMutableArray * sda = [[NSMutableArray alloc] init];
	[sda addObject:sd];
	[_children sortUsingDescriptors:sda];
	[sda release];
	[sd release];	
}

- (void)purge
{
	NSMutableIndexSet *set = [[NSMutableIndexSet alloc] init];
	for (LinkItem * item in _children) {
		if ([item name] == nil && [item path] == nil && [item numberOfChildren] == 0)
			[set addIndex:[_children indexOfObject:item]];
		else
			[item purge];
	}
	
	[_children removeObjectsAtIndexes:set];
	[set release];
}

- (void)removeAllChildren
{
	[_children removeAllObjects];
}
@end

@interface CHMTableOfContent (Private)
- (void)push_item;
- (void)pop_item;
- (void)new_item;
- (void)addToPageList:(LinkItem*)item;
@end

@implementation CHMTableOfContent
@synthesize rootItems;

static void elementDidStart( CHMTableOfContent *toc, const xmlChar *name, const xmlChar **atts );
static void elementDidEnd( CHMTableOfContent *toc, const xmlChar *name );

static htmlSAXHandler saxHandler = {
NULL, /* internalSubset */
NULL, /* isStandalone */
NULL, /* hasInternalSubset */
NULL, /* hasExternalSubset */
NULL, /* resolveEntity */
NULL, /* getEntity */
NULL, /* entityDecl */
NULL, /* notationDecl */
NULL, /* attributeDecl */
NULL, /* elementDecl */
NULL, /* unparsedEntityDecl */
NULL, /* setDocumentLocator */
NULL, /* startDocument */
NULL, /* endDocument */
(startElementSAXFunc) elementDidStart, /* startElement */
(endElementSAXFunc) elementDidEnd, /* endElement */
NULL, /* reference */
NULL, /* characters */
NULL, /* ignorableWhitespace */
NULL, /* processingInstruction */
NULL, /* comment */
NULL, /* xmlParserWarning */
NULL, /* xmlParserError */
NULL, /* xmlParserError */
NULL, /* getParameterEntity */
};

- (id)initWithData:(NSData *)data encodingName:(NSString*)encodingName
{
	urlSpliter = [NSCharacterSet characterSetWithCharactersInString:@"#?"];
	lastPath = nil;

	itemStack = [[NSMutableArray alloc] init];
	pageList = [[NSMutableArray alloc] init];
	rootItems = [[LinkItem alloc] initWithName:@"root"	Path:@"/"];
	curItem = rootItems;
	
	if(!encodingName || [encodingName length] == 0)
		encodingName = @"iso_8859_1";
	
	htmlDocPtr doc = htmlSAXParseDoc( (xmlChar *)[data bytes], [encodingName UTF8String],
									 &saxHandler, self);
	[itemStack release];
	
	if( doc ) {
	    xmlFreeDoc( doc );
	}
	[rootItems purge];
	[rootItems enumerateItemsWithSEL:@selector(addToPageList:) ForTarget:self];
	return self;
}

- (void) dealloc
{
	[rootItems release];
	[pageList release];
	[super dealloc];
}

- (LinkItem *)itemForPath:(NSString*)path withStack:(NSMutableArray*)stack
{
	if( [path hasPrefix:@"/"] ) {
		path = [path substringFromIndex:1];
    }
	
	LinkItem *item = [rootItems find_by_path:path withStack:stack];
	if (!item)
	{
		NSString *encoded_path = [path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		item = [rootItems find_by_path:encoded_path withStack:stack];
	}
	return item;
}

- (int)rootChildrenCount
{
	return [rootItems numberOfChildren];
}

- (void)sort
{
	[rootItems sort];	
}

- (LinkItem*)getNextPage:(LinkItem*)item
{
	NSUInteger idx = [item pageID] + 1;
	if (idx >= [pageList count])
		return nil;
	return [pageList objectAtIndex:idx];
}

- (LinkItem*)getPrevPage:(LinkItem*)item
{
	int idx = [item pageID] - 1;
	if (idx <= -1)
		return nil;
	return [pageList objectAtIndex:idx];
}

- (BOOL)canGoNextPage:(LinkItem*)item
{
	return ([self getNextPage:item] != nil);
}

- (BOOL)canGoPrevPage:(LinkItem*)item
{
	return [self getPrevPage:item] != nil;
}

- (LinkItem *)curItem
{
	return curItem;
}

- (void)push_item
{
	[itemStack addObject:curItem];
}

- (void)new_item
{
    if ([itemStack count] == 0) {
        [self push_item];
    }
	curItem = [[[LinkItem alloc] init] autorelease];
	LinkItem * parent = [itemStack lastObject];
	[parent appendChild:curItem];
}

- (void)pop_item
{
	curItem = [itemStack lastObject];
	[itemStack removeLastObject];
}

- (void)addToPageList:(LinkItem*)item
{
	if ([item path] == nil)
		return;
	
	if(nil == lastPath || ![[item path] hasPrefix:lastPath])
	{
		[pageList addObject:item];
		lastPath = [[[item path] componentsSeparatedByCharactersInSet:urlSpliter] objectAtIndex:0];
	}
	[item setPageID:([pageList count] - 1)];
}

# pragma mark NSXMLParser delegation
static void elementDidStart( CHMTableOfContent *context, const xmlChar *name, const xmlChar **atts ) 
{
	if (!context)
		return;
	
    if ( !strcasecmp( "ul", (char *)name ) ) {
		[context push_item];
        return;
    }
	
    if ( !strcasecmp( "li", (char *)name ) ) {
		[context new_item];
        return;
    }
	
    if ( !strcasecmp( "param", (char *)name ) && ( atts != NULL ) ) {
		// Topic properties
		const xmlChar *type = NULL;
		const xmlChar *value = NULL;
		
		for( int i = 0; atts[ i ] != NULL ; i += 2 ) {
			if( !strcasecmp( "name", (char *)atts[ i ] ) ) {
				type = atts[ i + 1 ];
			}
			else if( !strcasecmp( "value", (char *)atts[ i ] ) ) {
				value = atts[ i + 1 ];
			}
		}
		
		if( ( type != NULL ) && ( value != NULL ) ) {
			if( !strcasecmp( "Name", (char *)type )  || !strcasecmp( "Keyword", (char *)type ) ) {
				// Name of the topic
				NSString *str = [[NSString alloc] initWithUTF8String:(char *)value];
				if (![[context curItem] name])
					[[context curItem] setName:str];
				[str release];
			}
			else if( !strcasecmp( "Local", (char *)type ) ) {
				// Path of the topic
				NSString *str = [[NSString alloc] initWithUTF8String:(char *)value];
				[[context curItem] setPath:str]; 
				[str release];
			}
		}
        return;
    }
}

static void elementDidEnd( CHMTableOfContent *context, const xmlChar *name )
{
    if ( !strcasecmp( "ul", (char *)name ) ) {
		[context pop_item];
        return;
    }	
}
@end

@implementation CHMSearchResult

- (id) init
{
	rootItems = [[ScoredLinkItem alloc] initWithName:@"root"	Path:@"/" Score:0];
	return self;
}

- (id)initwithTOC:(CHMTableOfContent*)toc withIndex:(CHMTableOfContent*)index
{
	[self init];
	
	tableOfContent = toc;
	if (tableOfContent)
		[tableOfContent retain];
	
	indexContent = index;
	if (indexContent)
		[indexContent retain];
	
	return self;
}

- (void) dealloc
{
	if (tableOfContent)
		[tableOfContent release];
	
	if (indexContent)
		[indexContent release];
	[super dealloc];
}

- (void)addPath:(NSString*)path Score:(float)score
{
	LinkItem * item = nil;
	if (tableOfContent)
		item = [tableOfContent itemForPath:path withStack:nil];
	if (!item && indexContent)
		item = [indexContent itemForPath:path withStack:nil];
	
	if (!item)
		return;
	ScoredLinkItem * newitem = [[ScoredLinkItem alloc] initWithName:[item name] Path:[item path] Score:score];
	[rootItems appendChild:newitem];
}

- (void)sort
{
	[(ScoredLinkItem*)rootItems sort];
}
@end

@implementation ScoredLinkItem

@synthesize relScore;

- (void)sort
{
	NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"relScore" ascending:NO];
	NSMutableArray * sda = [[NSMutableArray alloc] init];
	[sda addObject:sd];
	[_children sortUsingDescriptors:sda];
	[sda release];
	[sd release];
}

- (id)initWithName:(NSString *)name Path:(NSString *)path Score:(float)score
{
	relScore = score;
	return [self initWithName:name Path:path];
}

@end

@implementation CHMIndex

- (id)initWithData:(NSData *)data encodingName:(NSString*)encodingName
{
	if (self = [super initWithData:data encodingName:encodingName])
	{
		[rootItems sort];
		LinkItem *new_root = [[LinkItem alloc] initWithName:@"root"	Path:@"/"];
		LinkItem *currentSection = nil;
		for (LinkItem* item in [rootItems children])
		{
			if ([item numberOfChildren] > 0)
				[item setName:[NSString stringWithFormat:@"%@, %@", [item name], [[item childAtIndex:0] name]]];
			if ([item name] == nil || [[item name] length] == 0)
				continue;
			NSString *title = [[[item name] substringToIndex:1] uppercaseString];
			if ([title localizedCaseInsensitiveCompare:@"a"] < 0)
			{
				title = @"#";
				if (currentSection != nil)
					currentSection = [new_root childAtIndex:0];
			}
			if (currentSection == nil || ![[currentSection name] isEqualToString:title ])
			{
				currentSection = [[[LinkItem alloc] initWithName:title Path:@""] autorelease];
				[new_root appendChild:currentSection];
			}
			[currentSection appendChild:item];
		}
		[rootItems release];
		rootItems = new_root;
	}
	return self;
}

@end
