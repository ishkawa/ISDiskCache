#import "ISDiskCache.h"
#import <CommonCrypto/CommonCrypto.h>

static NSString *const ISDiskCacheException = @"ISDiskCacheException";

@interface ISDiskCache ()

@property (nonatomic, readonly) NSOperationQueue *calculationQueue;
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
        _calculationQueue = [[NSOperationQueue alloc] init];
        _semaphore = dispatch_semaphore_create(1);
        _limitOfSize = 10 * 1024 * 1024; // 10MB
        
        [self performSelectorInBackground:@selector(calculateCurrentSize) withObject:nil];
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
    CC_MD5([data bytes], (CC_LONG)[data length], result);
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
        BOOL exists = [fileManager fileExistsAtPath:path isDirectory:&isDirectory];
        return !isHidden && !isDirectory && exists;
    }];
    
    return [paths filteredArrayUsingPredicate:predicate];
}

#pragma mark - key

- (BOOL)hasObjectForKey:(id<NSCoding>)key
{
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    NSString *path = [self filePathForKey:key];
    BOOL hasObject = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:NULL];
    dispatch_semaphore_signal(self.semaphore);
    return hasObject;
}

- (id)objectForKey:(id <NSCoding>)key
{
    if (![self hasObjectForKey:key]) {
        return nil;
    }
    
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    NSString *path = [self filePathForKey:key];
    NSMutableDictionary *attributes = [[self attributesForFilePath:path] mutableCopy];
    if (attributes) {
        [attributes setObject:[NSDate date] forKey:NSFileModificationDate];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        if (![fileManager setAttributes:[attributes copy] ofItemAtPath:path error:&error]) {
            [NSException raise:ISDiskCacheException format:@"%@", error];
        }
    }
    
    NSData *data = [NSData dataWithContentsOfFile:path];
    id object = data ? [NSKeyedUnarchiver unarchiveObjectWithData:data] : nil;
    dispatch_semaphore_signal(self.semaphore);
    
    return object;
}

- (void)setObject:(id <NSCoding>)object forKey:(id <NSCoding>)key;
{
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    NSString *path = [self filePathForKey:key];
    NSString *directoryPath = [path stringByDeletingLastPathComponent];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:directoryPath isDirectory:NULL]) {
        NSError *error = nil;
        if (![fileManager createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:&error]) {
            [NSException raise:ISDiskCacheException format:@"%@", error];
        }
    }
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object];
    [data writeToFile:path atomically:YES];
    [self calculateCurrentSize];
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
        NSDictionary *attributes = [self attributesForFilePath:filePath];
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

- (void)removeOldObjects
{
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    static NSString *ISDiskCacheFilePathKey = @"ISDiskCacheFilePathKey";
    
    NSMutableArray *attributesArray = [@[] mutableCopy];
    for (NSString *filePath in [self validFilePathsUnderPath:self.rootPath]) {
        NSMutableDictionary *attributes = [[self attributesForFilePath:filePath] mutableCopy];
        [attributes setObject:filePath forKey:ISDiskCacheFilePathKey];
        [attributesArray addObject:attributes];
    }
    
    [attributesArray sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSDate *date1 = [obj1 objectForKey:NSFileModificationDate];
        NSDate *date2 = [obj2 objectForKey:NSFileModificationDate];
        return [date2 compare:date1];
    }];
    
    NSInteger sum = 0;
    for (NSDictionary *attributes in [attributesArray copy]) {
        sum += [[attributes objectForKey:NSFileSize] integerValue];
        if (sum >= self.limitOfSize / 2) {
            break;
        }
        [attributesArray removeObject:attributes];
    }
    dispatch_semaphore_signal(self.semaphore);
    
    NSArray *filePathsToRemove = [attributesArray valueForKey:ISDiskCacheFilePathKey];
    [self removeObjectsUsingBlock:^BOOL(NSString *filePath) {
        return [filePathsToRemove containsObject:filePath];
    }];
}

- (NSDictionary *)attributesForFilePath:(NSString *)filePath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSMutableDictionary *attributes = [[fileManager attributesOfItemAtPath:filePath error:&error] mutableCopy];
    if (error) {
        if (error.code == NSFileReadNoSuchFileError) {
            return nil;
        } else {
            [NSException raise:ISDiskCacheException format:@"%@", error];
        }
    }
    return attributes;
}

- (void)calculateCurrentSize
{
    [self.calculationQueue cancelAllOperations];
    [self.calculationQueue addOperationWithBlock:^{
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        NSInteger sum = 0;
        for (NSString *filePath in [self validFilePathsUnderPath:self.rootPath]) {
            NSDictionary *attributes = [self attributesForFilePath:filePath];
            sum += [[attributes objectForKey:NSFileSize] integerValue];
        }
        dispatch_semaphore_signal(self.semaphore);
        
        if (sum >= self.limitOfSize) {
            [self removeOldObjects];
        }
    }];
}

@end
