#import "ISViewController.h"

@implementation ISViewController

- (id)init
{
    self = [super init];
    if (self) {
        self.operationQueue = [[NSOperationQueue alloc] init];
        self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Mem Warning"
                                         style:UIBarButtonItemStyleBordered
                                        target:self
                                        action:@selector(simulateMemoryWarning)];
        
        self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                      target:self
                                                      action:@selector(refresh)];
    }
    return self;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self refresh];
}

- (void)refresh
{
    NSMutableArray *indexes = [@[] mutableCopy];
    for (NSInteger index = 0; index < 100; index++) {
        [indexes addObject:@(index)];
    }
    self.array = [indexes copy];
    [self.tableView reloadData];
}

- (void)simulateMemoryWarning
{
    [[UIApplication sharedApplication] performSelector:@selector(_performMemoryWarning)];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.array count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *Identifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:Identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:Identifier];
    }
    NSNumber *indexNumber = [self.array objectAtIndex:indexPath.row];
    NSInteger size = [indexNumber integerValue] + 88;
    NSString *URLString = [NSString stringWithFormat:@"http://placehold.it/%dx%d", size, size];
    cell.textLabel.text = URLString;
    cell.imageView.image = [UIImage imageNamed:@"placeholder"];
    
    NSURL *URL = [NSURL URLWithString:URLString];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:self.operationQueue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                               UIImage *image = [UIImage imageWithData:data];
                               if (image) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                                       cell.imageView.image = image;
                                   });
                               }
                           }];
    
    return cell;
}

@end
