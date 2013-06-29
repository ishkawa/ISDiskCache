#import <Foundation/Foundation.h>

@interface ISDiskCache : NSMutableDictionary {
    NSString *_rootPath;
}

@property (nonatomic, readonly) NSString *rootPath;
@property (nonatomic, readonly) NSArray *existingFilePaths;

- (NSString *)filePathForKey:(id <NSCoding>)key;

- (id)objectForKey:(id <NSCoding>)key;
- (void)setObject:(id <NSCoding>)object forKey:(id <NSCoding>)key;
- (void)removeObjectForKey:(id <NSCoding>)key;

@end
