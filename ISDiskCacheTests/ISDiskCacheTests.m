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
    cache = nil;
    key = nil;
    value = nil;
    
    [super tearDown];
}

- (void)testSetObject
{
    [cache setObject:value forKey:key];
    
    STAssertEqualObjects([cache objectForKey:key], value, @"object did not match set object.");
}

- (void)testRemoveObject
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

@end
