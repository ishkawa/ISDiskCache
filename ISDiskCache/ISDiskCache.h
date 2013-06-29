#import <Foundation/Foundation.h>

@interface ISDiskCache : NSMutableDictionary {
    NSString *_rootPath;
}

@property (nonatomic, readonly) NSString *rootPath;

- (id)objectForKey:(id <NSCoding>)key;
- (void)setObject:(id <NSCoding>)object forKey:(id <NSCoding>)key;
- (void)removeObjectForKey:(id <NSCoding>)key;

@end
