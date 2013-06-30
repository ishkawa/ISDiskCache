#import <Foundation/Foundation.h>

@interface ISDiskCache : NSObject {
    NSString *_rootPath;
}

@property (nonatomic, readonly) NSString *rootPath;
@property (nonatomic) NSInteger limitOfSize; // bytes

+ (instancetype)sharedCache;

- (NSString *)filePathForKey:(id <NSCoding>)key;
- (BOOL)hasObjectForKey:(id<NSCoding>)key;
- (id)objectForKey:(id <NSCoding>)key;

- (void)setObject:(id <NSCoding>)object forKey:(id <NSCoding>)key;
- (void)removeObjectForKey:(id <NSCoding>)key;

- (void)removeOldObjects; // will be called automatically when currentSize > limitOfSize.
- (void)removeObjectsByAccessedDate:(NSDate *)accessedDate;
- (void)removeObjectsUsingBlock:(BOOL (^)(NSString *filePath))block;

@end
