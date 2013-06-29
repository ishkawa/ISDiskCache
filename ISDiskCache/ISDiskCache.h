#import <Foundation/Foundation.h>

@interface ISDiskCache : NSMutableDictionary {
    NSString *_rootPath;
}

@property (nonatomic, readonly) NSString *rootPath;
@property (nonatomic, readonly) NSArray *existingFilePaths;

- (NSString *)filePathForKey:(id <NSCoding>)key;
- (void)removeObjectsByAccessedDate:(NSDate *)modificationDate;
- (void)removeObjectsUsingBlock:(BOOL (^)(NSString *filePath))block;

// NSDictionary
- (id)objectForKey:(id <NSCoding>)key;

// NSMutableDictioanry
- (void)setObject:(id <NSCoding>)object forKey:(id <NSCoding>)key;
- (void)removeObjectForKey:(id <NSCoding>)key;

@end
