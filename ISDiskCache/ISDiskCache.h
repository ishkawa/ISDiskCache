#import <Foundation/Foundation.h>

@interface ISDiskCache : NSObject {
    NSString *_rootPath;
}

@property (nonatomic, readonly) NSString *rootPath;
@property (nonatomic, readonly) NSArray *filePaths;

- (NSString *)filePathForKey:(id <NSCoding>)key;

- (BOOL)hasObjectForKey:(id <NSCoding>)key;
- (id)objectForKey:(id <NSCoding>)key;
- (void)setObject:(id <NSCoding>)object forKey:(id <NSCoding>)key;

- (void)removeObjectForKey:(id <NSCoding>)key;
- (void)removeObjectsByAccessedDate:(NSDate *)accessedDate;
- (void)removeObjectsUsingBlock:(BOOL (^)(NSString *filePath))block;

@end
