#import <Foundation/Foundation.h>

extern NSString *ISCacheKeyMake(id <NSCoding> key);

@interface ISDiskCache : NSMutableDictionary {
    NSString *_rootPath;
}

@property (nonatomic, readonly) NSString *rootPath;

- (NSString *)pathForCacheKey:(NSString *)cacheKey;

- (id)objectForKey:(id <NSCoding>)key;
- (void)setObject:(id <NSCoding>)object forKey:(id <NSCoding>)key;
- (void)removeObjectForKey:(id <NSCoding>)key;

@end
