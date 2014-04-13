# ISDiskCache [![Build Status](https://travis-ci.org/ishkawa/ISDiskCache.png)](https://travis-ci.org/ishkawa/ISDiskCache) [![Coverage Status](https://coveralls.io/repos/ishkawa/ISDiskCache/badge.png?branch=master)](https://coveralls.io/r/ishkawa/ISDiskCache?branch=master)

LRU disk cache for iOS.

## Requirements

- iOS 4.3 or later
- ARC

## Features

- deletes old files automatically using accessed date.
- accepts any type of object for key and value as long as it conforms to `NSCoding`.

## Usage

### Saving object to file

```objectivec
[[ISDiskCache sharedCache] setObject:object forKey:@"http://example.com"];
```

### Loading object from file

```objectivec
[[ISDiskCache sharedCache] objectForKey:@"http://example.com"];
```

### Set limit of size

```objectivec
[ISDiskCache sharedCache].limitOfSize = 10 * 1024 * 1024; // 10MB
```

When total size of disk cache is over limit of size, `ISDiskCache` calls `removeOldObjects` automatically.
This method sorts files by `NSFileModificationDate` and remove files from oldest file.
`NSFileModificationDate` is updated in each `objectForKey:`, so modification date equals to accessed date.

## Installing

Add `ISDiskCache/ISDiskCache.{h,m}` to your Xcode project.

### CocoaPods

If you use CocoaPods, you can install ISDiskCache by inserting config below.

```
pod 'ISDiskCache'
```

## Note

### Synchronicity

You should pay attetion to that `ISDiskCache` works synchronously.
If you call APIs on main thread, it will causes blocking user interaction.
To avoid this, you should call APIs of `ISDiskCache` asynchronously.
Recommended solution of this issue is using APIs in `NSOperation` which loads data from server.
Another solution is calling APIs in dispatch queue like below.

```objectivec
dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
dispatch_async(queue, ^{
    UIImage *image = [diskCache objectForKey:URL];
    dispatch_async(dispatch_get_main_queue(), ^{
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        cell.imageView.image = image;
    });
});
```

See `ISViewController` in demo app for example.

### Using ISMemoryCache together

If you want to use fast cache together, use [ISMemoryCache](https://github.com/ishkawa/ISMemoryCache).

```objectivec
UIImageView *imageView;
NSURL *URL = [NSURL URLWithString:@"http://example.com"];

imageView.image = [[ISMemoryCache sharedCache] objectForKey:URL];
if (imageView.image == nil && [[ISDiskCache sharedCache] hasObjectForKey:URL]) {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        UIImage *image = [diskCache objectForKey:URL];
        dispatch_async(dispatch_get_main_queue(), ^{
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            cell.imageView.image = image;
        });
    });
}
```

### Algorithm in generating file path from key

`ISDiskCache` uses MD5 hash to obtain file path from key.

```objectivec
NSData *data = [NSKeyedArchiver archivedDataWithRootObject:key];
unsigned char result[16];
CC_MD5([data bytes], [data length], result);
NSString *fileName = [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
        result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7],
        result[8], result[9], result[10], result[11],result[12], result[13], result[14], result[15]];
```

## License

Copyright (c) 2013-2014 Yosuke Ishikawa

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

