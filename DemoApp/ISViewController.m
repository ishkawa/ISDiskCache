#import "ISViewController.h"
#import <ISDiskCache/ISDiskCache.h>

@implementation ISViewController

- (id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        NSMutableArray *indexes = [@[] mutableCopy];
        for (NSInteger index = 0; index < 100; index++) {
            [indexes addObject:@(index)];
        }
        self.array = [indexes copy];
        self.operationQueue = [[NSOperationQueue alloc] init];
        self.networkingEnabled = YES;
        self.cacheEnabled = YES;
        
        self.title = @"ISDiskCache";
        self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Clear"
                                         style:UIBarButtonItemStyleBordered
                                        target:self
                                        action:@selector(clearDiskCache)];
    }
    return self;
}

#pragma mark -

- (void)clearDiskCache
{
    [[ISDiskCache sharedCache] removeObjectsUsingBlock:^BOOL(NSString *filePath) {
        return YES;
    }];
    
    [self.tableView reloadData];
}

- (void)switchDidToggle:(UISwitch *)sender
{
    UITableViewCell *cell = (UITableViewCell *)sender.superview;
    NSIndexPath *indexPath  = [self.tableView indexPathForCell:cell];
    switch (indexPath.row) {
        case 0: self.networkingEnabled = !self.networkingEnabled; break;
        case 1: self.cacheEnabled = !self.cacheEnabled; break;
    }
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0: return 2;
        case 1: return [self.array count];
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0: return [self tableView:tableView switchCellForRowAtIndexPath:indexPath];
        case 1: return [self tableView:tableView imageCellForRowAtIndexPath:indexPath];
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView switchCellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"SwitchCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
        
        UISwitch *toggleSwitch = [[UISwitch alloc] init];
        [toggleSwitch addTarget:self
                         action:@selector(switchDidToggle:)
               forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggleSwitch;
    }
    
    UISwitch *toggleSwitch = (UISwitch *)cell.accessoryView;
    switch (indexPath.row) {
        case 0:
            cell.textLabel.text = @"Networking";
            toggleSwitch.on = self.networkingEnabled;
            break;
            
        case 1:
            cell.textLabel.text = @"Disk Cache";
            toggleSwitch.on = self.cacheEnabled; break;
            break;
    }
    
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView imageCellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"ImageCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    NSNumber *indexNumber = [self.array objectAtIndex:indexPath.row];
    NSInteger size = [indexNumber integerValue] + 88;
    NSString *URLString = [NSString stringWithFormat:@"http://placehold.it/%dx%d", size, size];
    cell.textLabel.text = URLString;
    cell.imageView.image = [UIImage imageNamed:@"placeholder"];
    
    NSURL *URL = [NSURL URLWithString:URLString];
    ISDiskCache *diskCache = [ISDiskCache sharedCache];
    if ([diskCache hasObjectForKey:URL] && self.cacheEnabled) {
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(queue, ^{
            UIImage *image = [diskCache objectForKey:URL];
            dispatch_async(dispatch_get_main_queue(), ^{
                UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                cell.imageView.image = image;
            });
        });
    }
    else if (self.networkingEnabled) {
        NSURLRequest *request = [NSURLRequest requestWithURL:URL];
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:self.operationQueue
                               completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                                   UIImage *image = [UIImage imageWithData:data];
                                   if (image) {
                                       [diskCache setObject:image forKey:URL];
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                                           cell.imageView.image = image;
                                       });
                                   }
                               }];
    }
    
    return cell;
}

@end
