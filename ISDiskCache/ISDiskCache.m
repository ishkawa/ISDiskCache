#import "ISDiskCache.h"
#import <CommonCrypto/CommonCrypto.h>

static NSString *const ISDiskCacheException = @"ISDiskCacheException";

@interface ISDiskCache ()

@property (nonatomic, strong) NSArray *filePaths;
#if OS_OBJECT_USE_OBJC
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
#else
@property (nonatomic, assign) dispatch_semaphore_t semaphore;
#endif

@end

@implementation ISDiskCache

+ (instancetype)sharedCache
{
    static ISDiskCache *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[ISDiskCache alloc] init];
    });
    return cache;
}

- (id)init
{
    self = [super init];
    if (self) {
        _filePaths = [self validFilePathsUnderPath:self.rootPath];
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

#pragma mark - paths

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

- (NSArray *)validFilePathsUnderPath:(NSString *)parentPath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableArray *paths = [@[] mutableCopy];
    for (NSString *subpath in [fileManager subpathsAtPath:parentPath]) {
        NSString *path = [parentPath stringByAppendingPathComponent:subpath];
        [paths addObject:path];
    }
    
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        NSString *path = (NSString *)evaluatedObject;
        BOOL isHidden = [[path lastPathComponent] hasPrefix:@"."];
        BOOL isDirectory;
        if (![fileManager fileExistsAtPath:path isDirectory:&isDirectory]) {
            return NO;
        }
        return !isHidden && !isDirectory;
    }];
    return [paths filteredArrayUsingPredicate:predicate];
}

#pragma mark - key

- (BOOL)hasObjectForKey:(id<NSCoding>)key
{
    NSString *path = [self filePathForKey:key];
    return [self.filePaths containsObject:path];
}

- (id)objectForKey:(id <NSCoding>)key
{
    NSString *path = [self filePathForKey:key];
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
    
    self.filePaths = [self.filePaths arrayByAddingObject:path];
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
    
    NSMutableArray *keys = [self.filePaths mutableCopy];
    [keys removeObject:filePath];
    self.filePaths = [keys copy];
    dispatch_semaphore_signal(self.semaphore);
}

#pragma mark - remove

- (void)removeDirectoryIfEmpty:(NSString *)directoryPath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:directoryPath]) {
        return;
    }
        
    if (![[self validFilePathsUnderPath:directoryPath] count]) {
        NSError *error = nil;
        if (![fileManager removeItemAtPath:directoryPath error:&error]) {
            [NSException raise:ISDiskCacheException format:@"%@", error];
        }
    }
}

- (void)removeObjectsByAccessedDate:(NSDate *)borderDate
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
                
                NSMutableArray *filePaths = [self.filePaths mutableCopy];
                [filePaths removeObject:filePath];
                _filePaths = [filePaths copy];
            }
        }
    }
    dispatch_semaphore_signal(self.semaphore);
}

@end
