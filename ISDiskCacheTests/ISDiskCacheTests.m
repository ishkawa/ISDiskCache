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

- (void)testExample
{
    [cache setObject:value forKey:key];
    
    STAssertEqualObjects([cache objectForKey:key], value, nil);
}

@end
