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
    void *buffer = malloc(4096);
    
    long bytes = getxattr(path.UTF8String, key.UTF8String, buffer, 4095, 0, 0);
    
    if (bytes < 0L) {
        free(buffer);
        if (error != nil) {
            *error = [NSError errorWithDomain:@"file not found" code:200 userInfo:nil];
        }
        return nil;
    } else {
        char * cstr = (char *)buffer;
        cstr[bytes] = '\0';
        NSString *string = [NSString stringWithCString:(char *)buffer encoding:kUnicodeUTF8Format];
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
    long v= [XattrBridge setXAttrAttributeForFile:path valueOf:s withKey:key andError:error    ];
    NSLog(@"append %d\n", v);
    NSLog(@"append %@, %@, %@\n", path, s, key);
    NSLog(@"append %s\n", strerror(errno));
    return v;
}

+(NSInteger)setXAttrAttributeForFile:(NSString *)path valueOf: (NSString *)value withKey: (NSString *)key andError:(NSError **)error {
    NSLog(@"set: %s, %s, %s, %ld\n", path.UTF8String, key.UTF8String, value.UTF8String, value.length);
    return setxattr(path.UTF8String, key.UTF8String, (void *) value.UTF8String, value.length, 0, 0);
}

+(NSArray *)getXAttrAttributesForFile:(NSString *)path withKey: (NSString *)key delimitedBy: (NSString *)delim andError:(NSError **)error {
    NSString *data = [XattrBridge getXAttrAttributeForFile:path withKey:key andError:error];
    NSArray * content = [data componentsSeparatedByString:delim];
    return content;
}

+(NSInteger)removeXAttrAttributesForFile:(NSString *)path withKey: (NSString *)key andError: (NSError **)error {
    return removexattr(path.UTF8String, key.UTF8String, 0);
}

@end
