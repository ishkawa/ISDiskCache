[![Build Status](https://travis-ci.org/ishkawa/ISDiskCache.png)](https://travis-ci.org/ishkawa/ISDiskCache)

LRU disk cache for iOS.

## Requirements

- iOS 4.3 or later
- ARC

## Features

- deletes files by accessed date (LRU).
- accepts any type of object which conforms to NSCoding for key and value.

## Usage

### Saving object to file

```objectivec
[[ISDiskCache sharedCache] setObject:object forKey:@"key"];
```

### Loading object from file

```objectivec
[[ISDiskCache sharedCache] objectForKey:@"key"];
```

### Removing old files

remove object which is not retained by any other objects.

```objectivec
[[ISDiskCache sharedCache] removeObjectsByAccessedDate:[NSDate dateWithTimeIntervalSinceNow:-10000.0]];
```

## Installing

Add `ISDiskCache/ISDiskCache.{h,m}` to your Xcode project.

### CocoaPods

If you use CocoaPods, you can install ISDiskCache by inserting config below.

```
pod 'ISDiskCache', :git => 'https://github.com/ishkawa/ISDiskCache.git'
```

## Note

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

See `ISViewController` of demo app for more example.

## License

Copyright (c) 2013 Yosuke Ishikawa

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
