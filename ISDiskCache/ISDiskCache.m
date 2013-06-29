#import "ISDiskCache.h"
#import <CommonCrypto/CommonCrypto.h>

static NSString *const ISDiskCacheException = @"ISDiskCacheException";

@interface ISDiskCache ()

@property (nonatomic, strong) NSArray *existingFilePaths;
#if OS_OBJECT_USE_OBJC
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
#else
@property (nonatomic, assign) dispatch_semaphore_t semaphore;
#endif

@end

@implementation ISDiskCache

- (id)init
{
    self = [super init];
    if (self) {
        _existingFilePaths = @[];
        _semaphore = dispatch_semaphore_create(1);
    }
    return self;
}

- (void)dealloc
{
#if !OS_OBJECT_USE_OBJC
    dispatch_release(_semaphore);
#endif
}

#pragma mark - cache paths

- (NSString *)rootPath
{
    if (_rootPath) {
        return _rootPath;
    }
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    _rootPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"ISDiskCache"];
    return _rootPath;
}

- (NSString *)filePathForKey:(id<NSCoding>)key
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:key];
	if ([data length] == 0) {
		return nil;
	}
    
	unsigned char result[16];
    CC_MD5([data bytes], [data length], result);
	NSString *cacheKey = [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
            result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],result[12], result[13], result[14], result[15]];
    
    NSString *prefix = [cacheKey substringToIndex:2];
    NSString *directoryPath = [self.rootPath stringByAppendingPathComponent:prefix];
    return [directoryPath stringByAppendingPathComponent:cacheKey];
}

#pragma mark -

- (void)removeDirectoryIfEmpty:(NSString *)directoryPath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:directoryPath]) {
        return;
    }
        
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return ![(NSString *)evaluatedObject hasPrefix:@"."];
    }];
    
    if (![[[fileManager subpathsAtPath:directoryPath] filteredArrayUsingPredicate:predicate] count] ) {
        NSError *error = nil;
        if (![fileManager removeItemAtPath:directoryPath error:&error]) {
            [NSException raise:ISDiskCacheException format:@"%@", error];
        }
    }
}

- (void)removeObjectsByModificationDate:(NSDate *)borderDate
{
    [self removeObjectsUsingBlock:^BOOL(NSString *filePath) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        NSMutableDictionary *attributes = [[fileManager attributesOfItemAtPath:filePath error:&error] mutableCopy];
        if (error) {
            [NSException raise:ISDiskCacheException format:@"%@", error];
        }
        
        NSDate *modificationDate = [attributes objectForKey:NSFileModificationDate];
        return [modificationDate timeIntervalSinceDate:borderDate] < 0.0;
    }];
}

- (void)removeObjectsUsingBlock:(BOOL (^)(NSString *))block
{
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *path in [fileManager subpathsAtPath:self.rootPath]) {
        NSString *filePath = [self.rootPath stringByAppendingPathComponent:path];
        if ([[filePath lastPathComponent] hasPrefix:@"."]) {
            continue;
        }
        
        BOOL isDirectory;
        if ([fileManager fileExistsAtPath:filePath isDirectory:&isDirectory] && !isDirectory) {
            if (block(filePath)) {
                NSError *error = nil;
                if (![fileManager removeItemAtPath:filePath error:&error]) {
                    [NSException raise:ISDiskCacheException format:@"%@", error];
                }
                
                NSString *directoryPath = [filePath stringByDeletingLastPathComponent];
                [self removeDirectoryIfEmpty:directoryPath];
            }
        }
    }
    dispatch_semaphore_signal(self.semaphore);
}

#pragma mark - NSDictionary

- (id)initWithObjects:(NSArray *)objects forKeys:(NSArray *)keys
{
    self = [self init];
    if (self) {
        for (NSString *key in keys) {
            NSInteger index = [keys indexOfObject:key];
            id object = [objects objectAtIndex:index];
            [self setObject:object forKey:key];
        }
    }
    return self;
}

- (NSUInteger)count
{
    return [self.existingFilePaths count];
}

- (id)objectForKey:(id <NSCoding>)key
{
    NSString *path = [self filePathForKey:key];
    if (![self.existingFilePaths containsObject:path]) {
        return nil;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path isDirectory:NULL]) {
        return nil;
    }
    
    NSError *getAttributesError = nil;
    NSMutableDictionary *attributes = [[fileManager attributesOfItemAtPath:path error:&getAttributesError] mutableCopy];
    if (getAttributesError) {
        [NSException raise:ISDiskCacheException format:@"%@", getAttributesError];
    }
    [attributes setObject:[NSDate date] forKey:NSFileModificationDate];
    
    NSError *setAttributesError = nil;
    if (![fileManager setAttributes:[attributes copy] ofItemAtPath:path error:&setAttributesError]) {
        [NSException raise:ISDiskCacheException format:@"%@", getAttributesError];
    }
    
    NSData *data = [NSData dataWithContentsOfFile:path];
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}

- (NSEnumerator *)keyEnumerator
{
    return [self.existingFilePaths objectEnumerator];
}

#pragma mark - NSMutableDictionary

- (void)setObject:(id <NSCoding>)object forKey:(id <NSCoding>)key;
{
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    NSString *path = [self filePathForKey:key];
    NSString *directoryPath = [path stringByDeletingLastPathComponent];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:directoryPath isDirectory:NULL]) {
        NSError *error = nil;
        if (![fileManager createDirectoryAtPath:directoryPath
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:&error]) {
            [NSException raise:ISDiskCacheException format:@"%@", error];
        }
    }
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object];
    [data writeToFile:path atomically:YES];
    
    self.existingFilePaths = [self.existingFilePaths arrayByAddingObject:path];
    dispatch_semaphore_signal(self.semaphore);
}

- (void)removeObjectForKey:(id)key
{
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    NSString *filePath = [self filePathForKey:key];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath isDirectory:NULL]) {
        NSError *error = nil;
        if (![fileManager removeItemAtPath:filePath error:&error]) {
            [NSException raise:NSInvalidArgumentException format:@"%@", error];
        }
    }
    
    NSString *directoryPath = [filePath stringByDeletingLastPathComponent];
    [self removeDirectoryIfEmpty:directoryPath];
    
    NSMutableArray *keys = [self.existingFilePaths mutableCopy];
    [keys removeObject:filePath];
    self.existingFilePaths = [keys copy];
    dispatch_semaphore_signal(self.semaphore);
}

@end
