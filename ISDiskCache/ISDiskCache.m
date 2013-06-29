#import "ISDiskCache.h"
#import <CommonCrypto/CommonCrypto.h>

static NSString *const ISDiskCacheException = @"ISDiskCacheException";
NSString *ISCacheKeyMake(id <NSCoding> key)
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:key];
	if ([data length] == 0) {
		return nil;
	}
    
	unsigned char result[16];
    CC_MD5([data bytes], [data length], result);
	return [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
            result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],result[12], result[13], result[14], result[15]];
}

@interface ISDiskCache ()

@property (nonatomic, strong) NSArray *existingKeys;
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
        _existingKeys = @[];
        _semaphore = dispatch_semaphore_create(1);
        
        [self createCacheDirectories];
    }
    return self;
}

- (void)dealloc
{
#if !OS_OBJECT_USE_OBJC
    dispatch_release(_semaphore);
#endif
}

#pragma mark -

- (NSString *)rootPath
{
    if (_rootPath) {
        return _rootPath;
    }
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    _rootPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"ISDiskCache"];
    return _rootPath;
}

- (NSString *)pathForCacheKey:(NSString *)cacheKey
{
    NSString *prefix = [cacheKey substringToIndex:2];
    NSString *directoryPath = [self.rootPath stringByAppendingPathComponent:prefix];
    return [directoryPath stringByAppendingPathComponent:cacheKey];
}

- (void)createCacheDirectories
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    BOOL isDirectory = NO;
    BOOL exists = [fileManager fileExistsAtPath:self.rootPath isDirectory:&isDirectory];
    if (!exists || !isDirectory) {
        [fileManager createDirectoryAtPath:self.rootPath
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:nil];
    }
    
    for (int i = 0; i < 16; i++) {
        for (int j = 0; j < 16; j++) {
            NSString *path = [NSString stringWithFormat:@"%@/%X%X", self.rootPath, i, j];
            exists = [fileManager fileExistsAtPath:path isDirectory:&isDirectory];
            if (!exists || !isDirectory) {
                [fileManager createDirectoryAtPath:path
                       withIntermediateDirectories:YES
                                        attributes:nil
                                             error:nil];
            }
        }
    }
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
    return [self.existingKeys count];
}

- (id)objectForKey:(id)key
{
    NSString *cacheKey = ISCacheKeyMake(key);
    if (![self.existingKeys containsObject:cacheKey]) {
        return nil;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [self pathForCacheKey:cacheKey];
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
    return [self.existingKeys objectEnumerator];
}

#pragma mark - NSMutableDictionary

- (void)setObject:(id <NSCoding>)object forKey:(id <NSCoding>)key;
{
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    NSString *cacheKey = ISCacheKeyMake(key);
    NSString *path = [self pathForCacheKey:cacheKey];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object];
    [data writeToFile:path atomically:YES];
    
    self.existingKeys = [self.existingKeys arrayByAddingObject:cacheKey];
    dispatch_semaphore_signal(self.semaphore);
}

- (void)removeObjectForKey:(id)key
{
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    NSString *cacheKey = ISCacheKeyMake(key);
    NSString *path = [self pathForCacheKey:cacheKey];
    
    NSError *error = nil;
    if (![[NSFileManager defaultManager] removeItemAtPath:path error:&error]) {
        [NSException raise:NSInvalidArgumentException format:@"%@", error];
    }
    
    NSMutableArray *keys = [self.existingKeys mutableCopy];
    [keys removeObject:cacheKey];
    self.existingKeys = [keys copy];
    dispatch_semaphore_signal(self.semaphore);
}

@end
