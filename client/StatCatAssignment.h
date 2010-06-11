//
//  StatCatAssignment.h
//  Pecunia
//
//  Created by Frank Emminghaus on 29.12.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Category;
@class BankStatement;

@interface StatCatAssignment : NSManagedObject {

}

@property (nonatomic, retain) NSString *userInfo;
@property (nonatomic, retain) NSDecimalNumber *value;
//@property (nonatomic, retain) Category *category;
@property (nonatomic, retain) BankStatement *statement;

-(NSString*)stringForFields: (NSArray*)fields usingDateFormatter: (NSDateFormatter*)dateFormatter;
-(void)moveToCategory:(Category*)tcat;
-(void)remove;
-(NSComparisonResult)compareDate: (StatCatAssignment*)stat;

-(void)setCategory:(Category *)cat;
-(Category*)category;

@end

// coalesce these into one @interface StatCatAssignment (CoreDataGeneratedPrimitiveAccessors) section
@interface StatCatAssignment (CoreDataGeneratedPrimitiveAccessors)

- (Category *)primitiveCategory;
- (void)setPrimitiveCategory:(Category *)value;

@end