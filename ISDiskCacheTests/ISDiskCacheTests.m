#import <SenTestingKit/SenTestingKit.h>
#import "ISDiskCache.h"

@interface ISDiskCacheTests : SenTestCase {
    ISDiskCache *cache;
    id <NSCoding> key;
    id <NSCoding> value;
}

@end

@implementation ISDiskCacheTests

- (void)setUp
{
    [super setUp];
    
    cache = [[ISDiskCache alloc] init];
    key = @"foo";
    value = @"bar";
}

- (void)tearDown
{
    [cache removeObjectsUsingBlock:^BOOL(NSString *filePath) {
        return YES;
    }];
    
    cache = nil;
    key = nil;
    value = nil;
    
    [super tearDown];
}

- (void)testSetObjectForKey
{
    [cache setObject:value forKey:key];
    
    STAssertEqualObjects([cache objectForKey:key], value, @"object did not match set object.");
}

- (void)testRemoveObjectForKey
{
    [cache setObject:value forKey:key];
    [cache removeObjectForKey:key];
    
    STAssertNil([cache objectForKey:key], @"object for removed key should be nil.");
}

- (void)testUpdateModificationDateOnAccessing
{
    [cache setObject:value forKey:key];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
    
    NSDate *accessedDate = [NSDate date];
    [cache objectForKey:key];
    
    NSString *path = [cache filePathForKey:key];
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    NSDate *modificationDate = [attributes objectForKey:NSFileModificationDate];
    
    STAssertTrue(ABS([accessedDate timeIntervalSinceDate:modificationDate]) < 1.0, nil);
}

- (void)testRemoveObjectsUsingBlock
{
    [cache setObject:value forKey:key];
    [cache removeObjectsUsingBlock:^BOOL(NSString *filePath) {
        return YES;
    }];
    
    STAssertNil([cache objectForKey:key], @"cache should be empty.");
}

- (void)testRemoveObjectsByModificationDate
{
    [cache setObject:value forKey:key];
    [cache removeObjectsByAccessedDate:[NSDate dateWithTimeIntervalSinceNow:-10.0]];
    STAssertEqualObjects([cache objectForKey:key], value, @"should not remove object.");
    
    [cache removeObjectsByAccessedDate:[NSDate date]];
    STAssertNil([cache objectForKey:key], @"should remove object.");
}

- (void)testRemoveParentDirectoryIfSiblingsDoesNotExist
{
    NSString *directoryPath = [[cache filePathForKey:key] stringByDeletingLastPathComponent];
    [cache setObject:value forKey:key];
    [cache removeObjectForKey:key];
    
    STAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:directoryPath], @"did not remove parect directory.");
}

- (void)testWriteFromMultipThreads
{
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    for (NSInteger index = 0; index < 1000; index++) {
        [queue addOperationWithBlock:^{
            [cache setObject:value forKey:key];
        }];
        [queue addOperationWithBlock:^{
            [cache removeObjectForKey:key];
        }];
    }
    [queue waitUntilAllOperationsAreFinished];
}

@end
