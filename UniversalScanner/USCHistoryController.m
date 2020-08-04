//
//  USCHistoryController.m
//  UniversalScanner
//
//  Created by Andrey Butcitcyn on 31.07.2020.
//  Copyright © 2020 Andrey Butcitcyn. All rights reserved.
//

#import "USCHistoryController.h"
#import "USCHistoryTableViewCell.h"

@interface USCHistoryController ()
@property (nonatomic, strong) NSMutableArray<NSString*> *data;
@end

@implementation USCHistoryController

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.tabBarItem = [[UITabBarItem alloc]initWithTitle:@"History" image:[UIImage imageNamed:@"info_selected"] tag:1];
         [self.tableView registerNib:[UINib nibWithNibName:@"USCHistoryTableViewCell" bundle:nil] forCellReuseIdentifier:@"cell"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.data = [NSMutableArray<NSString*> new];
    
}

#pragma mark USCDataService
- (void)addEntry:(NSString *)entry{
    [self.data addObject:entry];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
#warning Incomplete implementation, return the number of rows
    return self.data.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    USCHistoryTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.texView.text = self.data[indexPath.row];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath{
    return NO;
}

@end
