//
//  ViewController.m
//  YelpNearby
//
//  Created by Behera, Subhransu on 12/5/13.
//  Copyright (c) 2013 Subh. All rights reserved.
//

#import "ViewController.h"
#import "Restaurant.h"
#import "ResultTableViewCell.h"

@interface ViewController ()

@end
const unsigned char SpeechKitApplicationKey[] = {"0x0f 0x7c 0x9f 0x26 0xeb 0x67 0x26 0x94 0x16 0x28 0x01 0xaa 0xf1 0xa3 0x83 0x84 0x3f 0x0e 0x06 0x13 0x8f 0x44 0x83 0x66 0xae 0xf2 0x91 0x68 0x50 0x01 0xf0 0x5f 0x7e 0x8f 0x86 0x69 0xf7 0xac 0xfd 0x0d 0xd4 0xfe 0xb7 0xc5 0xa1 0x3b 0x49 0xe0 0x49 0x50 0xf4 0xd8 0x94 0x77 0x3e 0x42 0x69 0xcf 0xab 0xb9 0xd1 0x9b 0x19 0x4f"};

@implementation ViewController

-  (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.messageLabel.text = @"Tap on the mic";
    self.activityIndicator.hidden = YES;
    
    if (!self.tableViewDisplayDataArray) {
        self.tableViewDisplayDataArray = [[NSMutableArray alloc] init];
    }
    
    self.appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [self.appDelegate updateCurrentLocation];
    [self.appDelegate setupSpeechKitConnection];
    
    self.searchTextField.returnKeyType = UIReturnKeySearch;
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

    
# pragma mark - TableView Datasource and Delegate methods
    
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.tableViewDisplayDataArray count];
}
    
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ResultTableViewCell *cell = (ResultTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"SearchResultTableViewCell"];
    
    Restaurant *restaurantObj = (Restaurant *)[self.tableViewDisplayDataArray objectAtIndex:indexPath.row];
    
    cell.nameLabel.text = restaurantObj.name;
    cell.addressLabel.text = restaurantObj.address;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSData *thumbImageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:restaurantObj.thumbURL]];
        NSData *ratingImageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:restaurantObj.ratingURL]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            cell.thumbImage.image = [UIImage imageWithData:thumbImageData];
            cell.ratingImage.image = [UIImage imageWithData:ratingImageData];
        });
    });
    
    return cell;
}
    
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    Restaurant *restaurantObj = (Restaurant *)[self.tableViewDisplayDataArray objectAtIndex:indexPath.row];
    
    if (restaurantObj.yelpURL) {
        UIApplication *app = [UIApplication sharedApplication];
        [app openURL:[NSURL URLWithString:restaurantObj.yelpURL]];
    }
}

# pragma mark - Textfield Delegate Method and Method to handle Button Touch-up Event

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if ([self.searchTextField isFirstResponder]) {
        [self.searchTextField resignFirstResponder];
    }
    
    return YES;
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if ([self.searchTextField isFirstResponder]) {
        [self.searchTextField resignFirstResponder];
    }
}

# pragma mark - when record button is tapped

- (IBAction)recordButtonTapped:(id)sender {
    self.recordButton.selected = !self.recordButton.isSelected;
    
    // This will initialize a new speech recognizer instance
    if (self.recordButton.isSelected) {
        self.voiceSearch = [[SKRecognizer alloc] initWithType:SKSearchRecognizerType
                                                    detection:SKShortEndOfSpeechDetection
                                                     language:@"en_US"
                                                     delegate:self];
    }
    
    // This will stop existing speech recognizer processes
    else {
        if (self.voiceSearch) {
            [self.voiceSearch stopRecording];
            [self.voiceSearch cancel];
        }
    }
}

- (void)recognizerDidBeginRecording:(SKRecognizer *)recognizer {
    self.messageLabel.text = @"Listening..";
}

- (void)recognizerDidFinishRecording:(SKRecognizer *)recognizer {
    self.messageLabel.text = @"Done Listening..";
}

- (void)recognizer:(SKRecognizer *)recognizer didFinishWithResults:(SKRecognition *)results {
    long numOfResults = [results.results count];
    
    if (numOfResults > 0) {
        // update the text of text field with best result from SpeechKit
        self.searchTextField.text = [results firstResult];
    }
    
    self.recordButton.selected = !self.recordButton.isSelected;
    
    if (self.voiceSearch) {
        [self.voiceSearch cancel];
    }
}

- (void)recognizer:(SKRecognizer *)recognizer didFinishWithError:(NSError *)error suggestion:(NSString *)suggestion {
    self.recordButton.selected = !self.recordButton.isSelected;
    self.messageLabel.text = @"Connection error";
    self.activityIndicator.hidden = YES;
    // This will extract category filter from search text
    NSString *yelpCategoryFilter = [self getYelpCategoryFromSearchText];
    
    // This will find nearby restaurants by category
    [self findNearByRestaurantsFromYelpbyCategory:yelpCategoryFilter];
    
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                    message:[error localizedDescription]
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

# pragma mark - Yelp API Delegate Method

-(void)loadResultWithDataArray:(NSArray *)resultArray {
    self.messageLabel.text = @"Tap on the mic";
    self.activityIndicator.hidden = YES;
    
    self.tableViewDisplayDataArray = [resultArray mutableCopy];
    [self.resultTableView reloadData];
}

-(NSString *)getYelpCategoryFromSearchText {
    NSString *categoryFilter;
    
    if ([[self.searchTextField.text componentsSeparatedByString:@" restaurant"] count] > 1) {
        NSCharacterSet *separator = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        NSArray *trimmedWordArray = [[[self.searchTextField.text componentsSeparatedByString:@"restaurant"] firstObject] componentsSeparatedByCharactersInSet:separator];
        
        if ([trimmedWordArray count] > 2) {
            int objectIndex = (int)[trimmedWordArray count] - 2;
            categoryFilter = [trimmedWordArray objectAtIndex:objectIndex];
        }
        
        else {
            categoryFilter = [trimmedWordArray objectAtIndex:0];
        }
    }
    
    else if (([[self.searchTextField.text componentsSeparatedByString:@" restaurant"] count] <= 1)
             && self.searchTextField.text &&  self.searchTextField.text.length > 0){
        categoryFilter = self.searchTextField.text;
    }
    
    return categoryFilter;
}

- (void)findNearByRestaurantsFromYelpbyCategory:(NSString *)categoryFilter {
    if (categoryFilter && categoryFilter.length > 0) {
        if (([CLLocationManager authorizationStatus] != kCLAuthorizationStatusDenied)
            && self.appDelegate.currentUserLocation &&
            self.appDelegate.currentUserLocation.coordinate.latitude) {
            
            [self.tableViewDisplayDataArray removeAllObjects];
            [self.resultTableView reloadData];
            
            self.messageLabel.text = @"Fetching results..";
            self.activityIndicator.hidden = NO;
            
            self.yelpService = [[YelpAPIService alloc] init];
            self.yelpService.delegate = self;
            
            self.searchCriteria = categoryFilter;
            
            [self.yelpService searchNearByRestaurantsByFilter:[categoryFilter lowercaseString] atLatitude:self.appDelegate.currentUserLocation.coordinate.latitude andLongitude:self.appDelegate.currentUserLocation.coordinate.longitude];
        }
        
        else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Location is Disabled"
                                                            message:@"Enable it in settings and try again"
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
    }
}

@end
