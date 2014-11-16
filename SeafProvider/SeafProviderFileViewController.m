//
//  SeafProviderFileViewController.m
//  seafilePro
//
//  Created by Wang Wei on 11/14/14.
//  Copyright (c) 2014 Seafile. All rights reserved.
//

#import "SeafProviderFileViewController.h"
#import "SeafFile.h"
#import "SeafRepos.h"
#import "FileSizeFormatter.h"
#import "SeafDateFormatter.h"
#import "Debug.h"

@interface SeafProviderFileViewController ()<SeafDentryDelegate, UIScrollViewDelegate>
@property (strong, nonatomic) IBOutlet UIButton *backButton;
@property (strong, nonatomic) IBOutlet UILabel *titleLabel;
@property (strong, nonatomic) UIProgressView* progressView;
@property (strong) UIAlertController *alert;
@property (strong) SeafFile *sfile;
@end

@implementation SeafProviderFileViewController

- (IBAction)goBack:(id)sender
{
    [self popViewController];
}

- (NSFileCoordinator *)fileCoordinator {
    NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] init];
    [fileCoordinator setPurposeIdentifier:@"com.seafile.seafilePro"];
    return fileCoordinator;
}


- (void)setDirectory:(SeafDir *)directory
{
    _directory = directory;
    _directory.delegate = self;
    [_directory loadContent:true];
    self.titleLabel.text = _directory.name;
}

- (UIProgressView *)progressView
{
    if (!_progressView) {
        _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    }
    return _progressView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.rowHeight = 50;
    self.titleLabel.text = _directory.name;
    [self.tableView reloadData];
    [self.backButton addTarget:self action:@selector(goBack:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)alertWithMessage:(NSString*)message handler:(void (^)())handler;
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:message message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"Seafile") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        handler();
    }];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:true completion:nil];
}

- (void)popupSetRepoPassword:(SeafRepo *)repo
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Password of this library", @"Seafile") message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Seafile") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    }];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"Seafile") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *textfiled = [alert.textFields objectAtIndex:0];
        NSString *input = textfiled.text;
        if (!input || input.length == 0) {
            [self alertWithMessage:NSLocalizedString(@"Password must not be empty", @"Seafile")handler:^{
                [self popupSetRepoPassword:repo];
            }];
            return;
        }
        if (input.length < 3 || input.length  > 100) {
            [self alertWithMessage:NSLocalizedString(@"The length of password should be between 3 and 100", @"Seafile") handler:^{
                [self popupSetRepoPassword:repo];
            }];
            return;
        }
        [repo setDelegate:self];
        if ([repo->connection localDecrypt:repo.repoId])
            [repo checkRepoPassword:input];
        else
            [repo setRepoPassword:input];

    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.secureTextEntry = true;
    }];
    [alert addAction:cancelAction];
    [alert addAction:okAction];

    [self presentViewController:alert animated:true completion:nil];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _directory.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SeafBase *entry = [_directory.items objectAtIndex:indexPath.row];

    NSString *CellIdentifier = @"SeafProviderCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }

    cell.textLabel.text = entry.name;
    cell.textLabel.font = [UIFont systemFontOfSize:17];
    cell.textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    cell.imageView.image = entry.icon;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
    if ([entry isKindOfClass:[SeafRepo class]]) {
        SeafRepo *srepo = (SeafRepo *)entry;
        NSString *detail = [NSString stringWithFormat:@"%@, %@", [FileSizeFormatter stringFromNumber:[NSNumber numberWithUnsignedLongLong:srepo.size ] useBaseTen:NO], [SeafDateFormatter stringFromLongLong:srepo.mtime]];
        cell.detailTextLabel.text = detail;
    } else if ([entry isKindOfClass:[SeafDir class]]) {
        cell.detailTextLabel.text = nil;
    } else if ([entry isKindOfClass:[SeafFile class]]) {
        SeafFile *sfile = (SeafFile *)entry;
        cell.detailTextLabel.text = sfile.detailText;
    }
    cell.imageView.frame = CGRectMake(8, 8, 32, 32);
    return cell;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

#pragma mark - Table view delegate

- (void)showDownloadProgress:(SeafFile *)file
{
    self.alert = [UIAlertController alertControllerWithTitle:file.name message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Seafile") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [file cancelDownload];
    }];
    self.sfile = file;
    [self.alert addAction:cancelAction];
    [self presentViewController:self.alert animated:true completion:^{
        self.progressView.progress = 0.f;
        CGRect r = self.alert.view.frame;
        self.progressView.frame = CGRectMake(20, r.size.height-45, r.size.width - 40, 20);
        [self.alert.view addSubview:self.progressView];
        [file load:self force:NO];
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SeafBase *entry = [_directory.items objectAtIndex:indexPath.row];
    if ([entry isKindOfClass:[SeafFile class]]) {
        SeafFile *file = (SeafFile *)entry;
        if (![file hasCache]) {
            [self showDownloadProgress:file];
            return;
        }
        if (self.root.documentPickerMode == UIDocumentPickerModeImport
            || self.root.documentPickerMode == UIDocumentPickerModeOpen) {
            NSURL *exportURL = [file exportURL];
            NSURL *url = [self.root.documentStorageURL URLByAppendingPathComponent:exportURL.lastPathComponent];
            [self.fileCoordinator coordinateWritingItemAtURL:url options:NSFileCoordinatorWritingForDeleting error:NULL byAccessor:^(NSURL *newURL) {
                NSError *error = nil;
                [[NSFileManager defaultManager] copyItemAtURL:exportURL toURL:newURL error:&error];
                if (!error) {
                    [self.root dismissGrantingAccessToURL:newURL];
                }
            }];
        }
    } else if ([entry isKindOfClass:[SeafRepo class]] && [(SeafRepo *)entry passwordRequired]) {
        [self popupSetRepoPassword:(SeafRepo *)entry];
    } else if ([entry isKindOfClass:[SeafDir class]]) {
        [self pushViewControllerDir:(SeafDir *)entry];
    }
}

#pragma mark - SeafDentryDelegate
- (void)entry:(SeafBase *)entry updated:(BOOL)updated progress:(int)percent
{
    if (!updated || ![self isViewLoaded])
        return;

    if (_directory == entry)
        [self.tableView reloadData];
    else {
        if (entry != self.sfile) return;
        NSUInteger index = [_directory.allItems indexOfObject:entry];
        if (index == NSNotFound)
            return;
        self.progressView.progress = percent * 1.0f/100.f;
        if (percent == 100) {
            [self.alert dismissViewControllerAnimated:NO completion:^{
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
                [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }];
        }
    }
}
- (void)entry:(SeafBase *)entry downloadingFailed:(NSUInteger)errCode
{
    if (_directory == entry) {
        if ([_directory hasCache])
            return;

        //[SVProgressHUD showErrorWithStatus:NSLocalizedString(@"Failed to load content of the directory", @"Seafile")];
        Warning("Failed to load directory content %@\n", entry.name);
    } else {
        if (entry != self.sfile) return;
        [self.alert dismissViewControllerAnimated:NO completion:^{
            NSUInteger index = [_directory.allItems indexOfObject:entry];
            if (index == NSNotFound)
                return;
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
            [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            Warning("Failed to download file %@\n", entry.name);
            NSString *msg = [NSString stringWithFormat:@"Failed to download file '%@'", entry.name];
            [self alertWithMessage:msg handler:nil];
        }];
    }
}

- (void)entry:(SeafBase *)entry repoPasswordSet:(BOOL)success
{
    //[SVProgressHUD dismiss];
    if (success) {
        [self pushViewControllerDir:(SeafDir *)entry];
    } else {
        //[SVProgressHUD showErrorWithStatus:NSLocalizedString(@"Wrong library password", @"Seafile") duration:2.0];
        [self performSelector:@selector(popupSetRepoPassword:) withObject:entry afterDelay:1.0];
    }
}

- (void)pushViewControllerDir:(SeafDir *)dir
{
    SeafProviderFileViewController *controller = [[UIStoryboard storyboardWithName:@"SeafProviderFileViewController" bundle:nil] instantiateViewControllerWithIdentifier:@"SeafProviderFileViewController"];
    controller.directory = dir;
    controller.root = self.root;
    controller.view.frame = CGRectMake(self.view.frame.size.width, self.view.frame.origin.y, self.view.frame.size.width, self.view.frame.size.height);
    [self addChildViewController:controller];
    [controller didMoveToParentViewController:self];
    [self.view addSubview:controller.view];

    [UIView animateWithDuration:0.5f delay:0.f options:0 animations:^{
        controller.view.frame = self.view.frame;
    } completion:^(BOOL finished) {
    }];
}

- (void)popViewController
{
    [UIView animateWithDuration:0.5
                     animations:^{
                         self.view.frame = CGRectMake(self.view.frame.size.width, self.view.frame.origin.y, self.view.frame.size.width, self.view.frame.size.height);
                     }
                     completion:^(BOOL finished){
                         [self willMoveToParentViewController:self.parentViewController];
                         [self.view removeFromSuperview];
                         [self removeFromParentViewController];
                     }];
}

@end