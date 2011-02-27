//
//  NSFileManagerExt.h
//  ringtone
//
//  Created by Robin Lu on 12/13/10.
//  Copyright 2010 CodeWalrus.com. All rights reserved.
//

#import <Foundation/Foundation.h>

#define NSFileManagerEXTFileDeletedNotification @"FileDeleted"

@interface NSFileManager (Ext)
+ (NSString*) DocumentFolder;
+ (void)removeFile:(NSString*)fileName;
@end
