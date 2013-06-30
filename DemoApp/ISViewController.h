#import <UIKit/UIKit.h>

@interface ISViewController : UITableViewController

@property (nonatomic) BOOL networkingEnabled;
@property (nonatomic) BOOL cacheEnabled;
@property (nonatomic, strong) NSArray *array;
@property (nonatomic, strong) NSOperationQueue *operationQueue;

@end
