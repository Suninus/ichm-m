//
//  NSFileManagerExt.m
//  ringtone
//
//  Created by Robin Lu on 12/13/10.
//  Copyright 2010 CodeWalrus.com. All rights reserved.
//

#import "NSFileManagerExt.h"


@implementation NSFileManager (Ext)

+ (void) createIfNotExist: (NSString *) folder  {
  NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:folder]) {
        [fm createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"can not path %@ : %@", folder, error);
        }
    }
}

+ (NSString*) DocumentFolder
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *folder = [paths objectAtIndex:0];
    return folder;    
}

+ (void)removeFile:(NSString*)fileName
{
    NSString *path = [[self DocumentFolder] stringByAppendingPathComponent:fileName];
    NSError *error = nil;
    if ([[self defaultManager] removeItemAtPath:path error:&error]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:NSFileManagerEXTFileDeletedNotification 
                                                            object:[path lastPathComponent]];
    }
    else {
        NSLog(@"%@ can not be removed because:%@", path, error);
    }
}
@end
