//
//  XattrBridge.m
//  Graffiti
//
//  Created by Thomas Povinelli on 1/1/23.
//

#import "XattrBridge.h"
#include <sys/xattr.h>
#include <errno.h>

@implementation XattrBridge

+(NSString *)getXAttrAttributeForFile:(NSString *)path withKey: (NSString *)key andError:(NSError **)error {
    long attr_size = getxattr(path.UTF8String, key.UTF8String, NULL, 0, 0, 0);
    
    void *buffer = malloc(attr_size + 1);
    
    if (buffer == NULL) {
        NSException *e = [NSException exceptionWithName:@"MemoryError" reason:@"malloc() returned null" userInfo:nil];
        @throw e;
    }
    
    long bytes = getxattr(path.UTF8String, key.UTF8String, buffer, attr_size, 0, 0);
    
    if (bytes < 0L) {
        free(buffer);
        if (error != nil) {
            *error = [NSError errorWithDomain:[@"Error reading xattrs: " stringByAppendingString: [NSString stringWithCString: strerror(errno) encoding: NSUTF8StringEncoding]] code:200 userInfo:nil];
        }
        return @"";
    } else {
        char * cstr = (char *)buffer;
        cstr[bytes] = '\0';
        NSString *string = [NSString stringWithCString:(char *)buffer encoding:NSUTF8StringEncoding];
        // TODO: is this legal
        free(buffer);
        return string;
    }
}

+(NSInteger)appendXAttrAttributeForFile:(NSString *)path valueOf: (NSString *)value withKey: (NSString *)key delimitedBy: (NSString *)delim andError:(NSError **)error {
    NSString *s = [XattrBridge getXAttrAttributeForFile:path withKey:key andError:error];
    if (s == nil) {
        s = @"";
    } else {
        s = [s stringByAppendingString:delim];
    }
    s = [s stringByAppendingString:value];
    long v = [XattrBridge setXAttrAttributeForFile:path valueOf:s withKey:key andError:error];
    return v;
}

+(NSInteger)setXAttrAttributeForFile:(NSString *)path valueOf: (NSString *)value withKey: (NSString *)key andError:(NSError **)error {
    if (value.length >= 4096) {
        @throw [NSException exceptionWithName:@"IndexOutOfBounds" reason:@"The value for an xattr attribute was too long. An xattr can be at most 4095 chars long" userInfo:nil];
        return -127; // in debug builds a user can click "continue" and we do not want to write out the value
    }
    return setxattr(path.UTF8String, key.UTF8String, (void *) value.UTF8String, value.length, 0, 0);
}

+(NSArray<NSString *> *)getXAttrAttributesForFile:(NSString *)path withKey: (NSString *)key delimitedBy: (NSString *)delim andError:(NSError **)error {
    NSString *data = [XattrBridge getXAttrAttributeForFile:path withKey:key andError:error];
    if (data == nil) {
        return [NSArray new];
    }
    NSArray *content = [data componentsSeparatedByString:delim];
    return content;
}

+(NSInteger)removeXAttrAttributesForFile:(NSString *)path withKey: (NSString *)key andError: (NSError **)error {
    return removexattr(path.UTF8String, key.UTF8String, 0);
}

@end
