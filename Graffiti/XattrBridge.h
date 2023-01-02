//
//  XattrBridge.h
//  Graffiti
//
//  Created by Thomas Povinelli on 1/1/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static const NSString* kDEFAULT_XATTR_DELIM = @",";

@interface XattrBridge : NSObject

+(NSString *)getXAttrAttributeForFile:(NSString *)path withKey: (NSString *)key andError:(NSError **)error;

+(NSInteger)setXAttrAttributeForFile:(NSString *)path valueOf: (NSString *)value withKey: (NSString *)key andError:(NSError **)error;

+(NSInteger)appendXAttrAttributeForFile:(NSString *)path valueOf: (NSString *)value withKey: (NSString *)key delimitedBy: (NSString *)delim andError:(NSError **)error;

+(NSArray *)getXAttrAttributesForFile:(NSString *)path withKey: (NSString *)key delimitedBy: (NSString *)delim andError:(NSError **)error;

+(NSInteger)removeXAttrAttributesForFile:(NSString *)path withKey: (NSString *)key andError: (NSError **)error;

@end

NS_ASSUME_NONNULL_END
