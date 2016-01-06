/**
 * Copyright (c) 2013, 2015, Pecunia Project. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; version 2 of the
 * License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301  USA
 */

#import "StatementsOverviewController.h"

#import "MessageLog.h"

#import "MOAssistant.h"
#import "BankingCategory.h"
#import "StatCatAssignment.h"
#import "BankStatement.h"
#import "BankStatementPrintView.h"
#import "BankAccount.h"
#import "StatSplitController.h"
#import "PreferenceController.h"
#import "StatementDetails.h"
#import "PecuniaSplitView.h"
#import "AttachmentImageView.h"
#import "BankingController.h"
#import "BankStatementController.h"
#import "HBCIController.h"

#import "NSColor+PecuniaAdditions.h"
#import "NSImage+PecuniaAdditions.h"

extern void *UserDefaultsBindingContext;

//----------------------------------------------------------------------------------------------------------------------

@interface StatementsOverviewController () {
    NSDecimalNumber *saveValue;

    // Sorting statements.
    int  sortIndex;
    BOOL sortAscending;

    IBOutlet NSArrayController  *categoryAssignments;
    IBOutlet StatementsListView *statementsListView;
    __weak IBOutlet StatementsTable *statementsTable;

    IBOutlet NSTextField       *selectedSumField;
    IBOutlet NSTextField       *totalSumField;

    IBOutlet NSSegmentedControl *sortControl;
}

@end

@implementation StatementsOverviewController

@synthesize selectedCategory;

- (void)awakeFromNib {
    sortAscending = NO;
    sortIndex = 0;

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([userDefaults objectForKey: @"mainSortIndex"]) {
        sortIndex = [[userDefaults objectForKey: @"mainSortIndex"] intValue];
        if (sortIndex < 0 || sortIndex >= sortControl.segmentCount) {
            sortIndex = 0;
        }
        sortControl.selectedSegment = sortIndex;
    }

    if ([userDefaults objectForKey: @"mainSortAscending"]) {
        sortAscending = [[userDefaults objectForKey: @"mainSortAscending"] boolValue];
    }
    
    [userDefaults addObserver: self forKeyPath: @"colors" options: 0 context: UserDefaultsBindingContext];

    [self updateSorting];
    [self updateValueColors];

    statementsListView.owner = self;

    // Setup statements listview.
    [statementsListView bind: @"dataSource" toObject: categoryAssignments withKeyPath: @"arrangedObjects" options: nil];

    // Bind controller to selectedRow property and the listview to the controller's
    // selectedIndex property to get notified about selection changes.
    [categoryAssignments bind: @"selectionIndexes" toObject: statementsListView withKeyPath: @"selectedRows" options: nil];
    [statementsListView bind: @"selectedRows" toObject: categoryAssignments withKeyPath: @"selectionIndexes" options: nil];

    [statementsListView setCellSpacing: 0];
    [statementsListView setAllowsEmptySelection: YES];
    [statementsListView setAllowsMultipleSelection: YES];

    [categoryAssignments addObserver: self forKeyPath: @"selectionIndexes" options: 0 context: nil];

    categoryAssignments.managedObjectContext = MOAssistant.sharedAssistant.context;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver: self];
    [NSUserDefaults.standardUserDefaults removeObserver: self forKeyPath: @"colors"];
}

- (void)updateStatementsTable {
    [statementsTable setNeedsDisplay];
}

#pragma mark - Sorting and searching statements

- (IBAction)filterStatements: (id)sender
{
    NSTextField *te = sender;
    NSString    *searchName = [te stringValue];

    if ([searchName length] == 0) {
        [categoryAssignments setFilterPredicate: nil];
    } else {
        NSPredicate *pred = [NSPredicate predicateWithFormat: @"statement.purpose contains[c] %@ or statement.remoteName contains[c] %@ or userInfo contains[c] %@ or value = %@",
                             searchName, searchName, searchName, [NSDecimalNumber decimalNumberWithString: searchName locale: [NSLocale currentLocale]]];
        if (pred != nil) {
            [categoryAssignments setFilterPredicate: pred];
        }
    }
}

- (void)clearStatementFilter
{
    [categoryAssignments setFilterPredicate:nil];
}

- (IBAction)sortingChanged: (id)sender
{
    if ([sender selectedSegment] == sortIndex) {
        sortAscending = !sortAscending;
    } else {
        sortAscending = NO; // Per default entries are sorted by date in decreasing order.
    }

    [self updateSorting];
}

#pragma mark - General logic

- (BOOL)canEditAttachment
{
    return categoryAssignments.selectedObjects.count == 1;
}

- (void)updateSorting
{
    [sortControl setImage: nil forSegment: sortIndex];
    sortIndex = [sortControl selectedSegment];
    if (sortIndex < 0) {
        sortIndex = 0;
    }
    NSImage *sortImage = sortAscending ? [NSImage imageNamed: @"sort-indicator-inc"] : [NSImage imageNamed: @"sort-indicator-dec"];
    [sortControl setImage: sortImage forSegment: sortIndex];

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setValue: @((int)sortIndex) forKey: @"mainSortIndex"];
    [userDefaults setValue: @(sortAscending) forKey: @"mainSortAscending"];

    NSString *key;
    switch (sortIndex) {
        case 1:
            statementsListView.canShowHeaders = NO;
            key = @"statement.remoteName";
            break;

        case 2:
            statementsListView.canShowHeaders = NO;
            key = @"statement.purpose";
            break;

        case 3:
            statementsListView.canShowHeaders = NO;
            key = @"statement.categoriesDescription";
            break;

        case 4:
            statementsListView.canShowHeaders = NO;
            key = @"value";
            break;

        default: {
            statementsListView.canShowHeaders = YES;
            key = @"statement.date";
            break;
        }
    }
    [categoryAssignments setSortDescriptors: @[[[NSSortDescriptor alloc] initWithKey: key ascending: sortAscending]]];
    [categoryAssignments rearrangeObjects];
}

- (void)deleteSelectedStatements
{
    // Process all selected assignments. If only a single assignment is selected then do an extra round
    // regarding duplication check and confirmation from the user. Otherwise just confirm the delete operation as such.
    NSArray *assignments = [categoryAssignments selectedObjects];
    BOOL    doDuplicateCheck = assignments.count == 1;

    if (!doDuplicateCheck) {
        int result = NSRunAlertPanel(NSLocalizedString(@"AP806", nil),
                                     NSLocalizedString(@"AP809", nil),
                                     NSLocalizedString(@"AP4", nil),
                                     NSLocalizedString(@"AP3", nil),
                                     nil, assignments.count);
        if (result != NSAlertAlternateReturn) {
            return;
        }
    }

    NSManagedObjectContext *context = MOAssistant.sharedAssistant.context;
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName: @"BankStatement" inManagedObjectContext: context];
    NSFetchRequest      *request = [[NSFetchRequest alloc] init];
    [request setEntity: entityDescription];

    NSMutableSet *affectedAccounts = [[NSMutableSet alloc] init];
    for (StatCatAssignment *assignment in assignments) {
        BankStatement *statement = assignment.statement;

        NSError *error = nil;
        BOOL    deleteStatement = NO;

        if (doDuplicateCheck) {
            // Check if this statement is a duplicate. Select all statements with same date.
            NSPredicate *predicate = [NSPredicate predicateWithFormat: @"(account = %@) AND (date = %@)", statement.account, statement.date];
            [request setPredicate: predicate];

            NSArray *possibleDuplicates = [context executeFetchRequest: request error: &error];
            if (error) {
                NSAlert *alert = [NSAlert alertWithError: error];
                [alert runModal];
                return;
            }

            BOOL hasDuplicate = NO;
            for (BankStatement *possibleDuplicate in possibleDuplicates) {
                if (possibleDuplicate != statement && [possibleDuplicate matches: statement]) {
                    hasDuplicate = YES;
                    break;
                }
            }
            int res;
            if (hasDuplicate) {
                res = NSRunAlertPanel(NSLocalizedString(@"AP805", nil),
                                      NSLocalizedString(@"AP807", nil),
                                      NSLocalizedString(@"AP4", nil),
                                      NSLocalizedString(@"AP3", nil),
                                      nil);
                if (res == NSAlertAlternateReturn) {
                    deleteStatement = YES;
                }
            } else {
                res = NSRunCriticalAlertPanel(NSLocalizedString(@"AP805", nil),
                                              NSLocalizedString(@"AP808", nil),
                                              NSLocalizedString(@"AP4", nil),
                                              NSLocalizedString(@"AP3", nil),
                                              nil);
                if (res == NSAlertAlternateReturn) {
                    deleteStatement = YES;
                }
            }
        } else {
            deleteStatement = YES;
        }

        if (deleteStatement) {
            BOOL isManualAccount = [statement.account.isManual boolValue];
            BankAccount *account = statement.account;
            [affectedAccounts addObject: account]; // Automatically ignores duplicates.

            [context deleteObject: assignment];
            [context deleteObject: statement];

            // Remove deleted amount from the acount's balance, so we can recompute the intermittant values at the end.
            if (isManualAccount) {
                account.balance = [account.balance decimalNumberBySubtracting: statement.value];
            }
        }
    }
    
    for (BankAccount *account in affectedAccounts) {
        [account invalidateCacheIncludeParents: YES recursive: NO];
    }
    
    [context processPendingChanges];
    for (BankAccount *account in affectedAccounts) {
        [account updateAssignmentsForReportRange];
        [account updateStatementBalances];
    }
    [[BankingCategory bankRoot] updateCategorySums];
    [categoryAssignments prepareContent];
}

- (void)splitSelectedStatement
{
    NSArray *selection = [categoryAssignments selectedObjects];
    if (selection.count == 1) {
        StatSplitController *splitController = [[StatSplitController alloc] initWithStatement: [selection[0] statement]];
        [NSApp runModalForWindow: [splitController window]];
    }
}

- (void)markSelectedStatementsRead {
    NSArray *selection = [categoryAssignments selectedObjects];
    if (selection.count > 0) {
        for (StatCatAssignment *assignment in selection) {
            assignment.statement.isNew = @NO;
        }
        [BankingController.controller updateUnread];
        [statementsListView updateVisibleCells];
    }
}

- (void)markSelectedStatementsUnread {
    NSArray *selection = [categoryAssignments selectedObjects];
    if (selection.count > 0) {
        for (StatCatAssignment *assignment in selection) {
            if (!assignment.statement.isPreliminary.boolValue) {
                assignment.statement.isNew = @YES;
            }
        }
        [BankingController.controller updateUnread];
        [statementsListView updateVisibleCells];
    }
}

- (void)updateValueColors
{
    NSDictionary *positiveAttributes = @{NSForegroundColorAttributeName: [NSColor applicationColorForKey: @"Positive Cash"]};
    NSDictionary *negativeAttributes = @{NSForegroundColorAttributeName: [NSColor applicationColorForKey: @"Negative Cash"]};

    NSNumberFormatter *formatter = [selectedSumField.cell formatter];
    [formatter setTextAttributesForPositiveValues: positiveAttributes];
    [formatter setTextAttributesForNegativeValues: negativeAttributes];
    [selectedSumField setNeedsDisplay];

    formatter = [totalSumField.cell formatter];
    [formatter setTextAttributesForPositiveValues: positiveAttributes];
    [formatter setTextAttributesForNegativeValues: negativeAttributes];
    [totalSumField setNeedsDisplay];
}

- (void)reload
{
    [statementsListView reloadData];
}

#pragma mark - KVO

- (void)observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object change: (NSDictionary *)change context: (void *)context
{
    if (context == UserDefaultsBindingContext) {
         if ([keyPath isEqualToString: @"colors"]) {
            [self updateValueColors];
            return;
        }

        return;
    }

    if (object == categoryAssignments) {
        static NSIndexSet *oldIdx;

        if ([keyPath isEqualToString: @"selectionIndexes"]) {
            NSIndexSet *selIdx = categoryAssignments.selectionIndexes;
            if (oldIdx == nil && selIdx == nil) {
                return;
            }
            if (oldIdx != nil && selIdx != nil) {
                if ([oldIdx isEqualTo: selIdx]) {
                    return;
                }
            }
            oldIdx = selIdx;

            // If the currently selected entry is marked as unread mark it now as read (if that is enabled).
            if ([NSUserDefaults.standardUserDefaults boolForKey: @"autoResetNew"]) {
                BOOL needUnreadUpdate = NO;
                for (StatCatAssignment *stat in [categoryAssignments selectedObjects]) {
                    if ([stat.statement.isNew boolValue]) {
                        needUnreadUpdate = YES;
                        stat.statement.isNew = @NO;
                        BankAccount *account = stat.statement.account;
                        account.unreadEntries = [NSNumber numberWithInteger: account.unreadEntries.integerValue - 1];
                    }
                }
                if (needUnreadUpdate) {
                    [BankingController.controller updateUnread];
                }
            }
        }
        return;
    }
    [super observeValueForKeyPath: keyPath ofObject: object change: change context: context];
}

#pragma mark - Table View delegate methods

- (id)tableView: (NSTableView *)table viewForTableColumn: (nullable NSTableColumn *)tableColumn row: (NSInteger)row {
    return [table makeViewWithIdentifier: @"DataCellView" owner: table];
}

- (CGFloat)tableView: (NSTableView *)tableView heightOfRow: (NSInteger)row {
    return 70;
}

#pragma mark - Menu handling

- (void)menuAction: (NSMenuItem *)item {
    LogEnter;

    NSArray *assignments;
    if (![categoryAssignments.selectionIndexes containsIndex: statementsTable.clickedRow]) {
        assignments = [[NSArray alloc] initWithObjects: categoryAssignments.arrangedObjects[statementsTable.clickedRow], nil];
    } else {
        assignments = categoryAssignments.selectedObjects;
    }

    switch (item.tag) {
        case MenuActionShowDetails: // Only called for single selection.
            [statementsTable toggleStatementDetails];
            break;

        case MenuActionAddStatement:
            if (selectedCategory.accountNumber != nil) {
                BankStatementController *controller = [[BankStatementController alloc] initWithAccount: (BankAccount *)selectedCategory
                                                                                             statement: nil];

                int res = [NSApp runModalForWindow: controller.window];
                if (res != 0) {
                    [selectedCategory updateAssignmentsForReportRange];
                }
            }

            break;

        case MenuActionSplitStatement:
            [self splitSelectedStatement];
            break;

        case MenuActionDeleteStatement:
            [self deleteSelectedStatements];
            break;

        case MenuActionMarkRead:
            [self markSelectedStatementsRead];
            break;

        case MenuActionMarkUnread:
            [self markSelectedStatementsUnread];
            break;
            /*
             case MenuActionStartTransfer:
             if ([[HBCIController controller] isTransferSupported: TransferTypeSEPA forAccount: selectedCategory]) {
             [BankingController.controller startTransferOfType: TransferTypeSEPA
             fromAccount: selectedCategory
             statement: assignment.statement];
             } else {
             if ([[HBCIController controller] isTransferSupported: TransferTypeInternalSEPA forAccount: account]) {
             [BankingController.controller startTransferOfType: TransferTypeInternalSEPA
             fromAccount: account
             statement: assignment.statement];
             }
             }
             break;

             case MenuActionCreateTemplate:
             if ([[HBCIController controller] isTransferSupported: TransferTypeSEPA forAccount: account]) {
             [BankingController.controller createTemplateOfType: TransferTypeSEPA fromStatement: assignment.statement];
             } else {
             if ([[HBCIController controller] isTransferSupported: TransferTypeInternalSEPA forAccount: account]) {
             [BankingController.controller createTemplateOfType: TransferTypeInternalSEPA fromStatement: assignment.statement];
             }
             }
             break;*/
    }

    LogLeave;

}

- (void)menuNeedsUpdate: (NSMenu *)menu {
    LogEnter;

    [menu removeAllItems];
    BOOL isManualAccount = NO;

    if (selectedCategory.isBankAccount) {
        isManualAccount = [(BankAccount *)selectedCategory isManual].boolValue;
    }

    NSMenuItem *item;
    if (isManualAccount) {
        item = [menu addItemWithTitle: NSLocalizedString(@"AP238", nil)
                               action: @selector(menuAction:)
                        keyEquivalent: @"n"];
        item.target = self;
        item.keyEquivalentModifierMask = NSCommandKeyMask;
        item.tag = MenuActionAddStatement;

        [menu addItem: NSMenuItem.separatorItem];
    }
    item = [menu addItemWithTitle: NSLocalizedString(@"AP240", nil)
                           action: @selector(menuAction:)
                    keyEquivalent: @" "];
    item.target = self;
    item.keyEquivalentModifierMask = 0;
    item.tag = MenuActionShowDetails;

    item = [menu addItemWithTitle: NSLocalizedString(@"AP233", nil)
                           action: @selector(menuAction:)
                    keyEquivalent: @"s"];
    item.target = self;
    item.tag = MenuActionSplitStatement;

    item = [menu addItemWithTitle: NSLocalizedString(@"AP234", nil)
                           action: @selector(menuAction:)
                    keyEquivalent: [NSString stringWithFormat: @"%c", NSBackspaceCharacter]];
    item.target = self;
    item.tag = MenuActionDeleteStatement;

    [menu addItem: NSMenuItem.separatorItem];

    __block BOOL allRead = YES;
    if (![categoryAssignments.selectionIndexes containsIndex: statementsTable.clickedRow]) {
        allRead = ![categoryAssignments.arrangedObjects[statementsTable.clickedRow] statement].isNew.boolValue;
    } else {
        for (StatCatAssignment *assignment in categoryAssignments.selectedObjects) {
            if (assignment.statement.isNew.boolValue) {
                allRead = NO;
                break;
            }
        }
    }
    item = [menu addItemWithTitle: allRead ? NSLocalizedString(@"AP235", nil): NSLocalizedString(@"AP239", nil)
                           action: @selector(menuAction:)
                    keyEquivalent: @""];
    item.target = self;
    item.tag = allRead ? MenuActionMarkUnread : MenuActionMarkRead;

    if (!isManualAccount) {
        [menu addItem: [NSMenuItem separatorItem]];
        item = [menu addItemWithTitle: NSLocalizedString(@"AP236", nil)
                               action: @selector(menuAction:)
                        keyEquivalent: @""];
        item.target = self;
        item.tag = MenuActionStartTransfer;
    }

    item = [menu addItemWithTitle: NSLocalizedString(@"AP237", nil)
                           action: @selector(menuAction:)
                    keyEquivalent: @""];
    item.target = self;
    item.tag = MenuActionCreateTemplate;

    LogLeave;
}

- (BOOL)validateMenuItem: (NSMenuItem *)item
{
    if (item.target != self) { // Call from the main menu.
        if ([item action] == @selector(deleteStatement:)) {
            if (!selectedCategory.isBankAccount || categoryAssignments.selectedObjects.count == 0) {
                return NO;
            }
        }
        if ([item action] == @selector(splitStatement:)) {
            if (categoryAssignments.selectedObjects.count != 1) {
                return NO;
            }

            StatCatAssignment *stat = categoryAssignments.selectedObjects.lastObject;
            if (stat.statement.isPreliminary.boolValue == YES) {
                return NO;
            }
        }
    } else {
        // Call from the context menu.
        BOOL isManualAccount = NO;
        if (selectedCategory.isBankAccount) {
            isManualAccount = [(BankAccount *)selectedCategory isManual].boolValue;
        }

        // Determine the selected assignement, if there is only one.
        StatCatAssignment *singleAssignment = nil;
        if (![categoryAssignments.selectionIndexes containsIndex: statementsTable.clickedRow]
            || (categoryAssignments.selectedObjects.count == 1)) {
            singleAssignment = categoryAssignments.arrangedObjects[statementsTable.clickedRow];
        }

        BOOL isPreliminary = (singleAssignment == nil) ? NO : singleAssignment.statement.isPreliminary.boolValue;

        switch (item.tag) {
            case MenuActionShowDetails:
                return singleAssignment != nil;

            case MenuActionSplitStatement:
            case MenuActionStartTransfer:
            case MenuActionCreateTemplate:
                return singleAssignment != nil && !isPreliminary;

            case MenuActionMarkUnread:
            case MenuActionMarkRead:
                return !isPreliminary;

            case MenuActionDeleteStatement:
                item.title = NSLocalizedString((singleAssignment == nil) ? @"AP806" : @"AP805", nil);
                break;
        }
    }
    
    return YES;
}

#pragma mark - PecuniaSectionItem protocol

- (void)activate {
}

- (void)deactivate {
}

- (void)setTimeRangeFrom: (ShortDate *)from to: (ShortDate *)to {
}

- (void)print
{
    NSPrintInfo *printInfo = [NSPrintInfo sharedPrintInfo];

    // Set the maxium possible print area.
    // Note: there's a minimum marging area set by the printer. Values below that only confuse
    //       the print preview page size computation. NSPrintInfo.imageablePageBounds is supposed to have that info
    //       but returns, at least for my printer, twice as large vertical margins as what are really possible.
    printInfo.topMargin = 20;
    printInfo.bottomMargin = 20;
    printInfo.leftMargin = 18;
    printInfo.rightMargin = 18;

    NSPrintOperation *printOp;
    NSView *view = [[BankStatementPrintView alloc] initWithStatements: [categoryAssignments arrangedObjects]
                                                            printInfo: printInfo
                                                                title: nil
                                                             category: selectedCategory
                                                       additionalText: nil];
    printOp = [NSPrintOperation printOperationWithView: view printInfo: printInfo];
    [printOp setShowsPrintPanel: YES];
    [printOp runOperation];
}

- (void)setSelectedCategory: (BankingCategory *)newCategory
{
    if (selectedCategory != newCategory) {
        selectedCategory = newCategory;
    }
}

- (void)removeSelection {
    [statementsListView deselectRows];
}

- (void)terminate
{
    selectedCategory = nil;
    [statementsListView unbind: @"dataSource"];
    [categoryAssignments unbind: @"selectionIndexes"];
    [statementsListView unbind: @"selectedRows"];
    [categoryAssignments removeObserver: self forKeyPath: @"selectionIndexes"];
    categoryAssignments.content = nil;

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults removeObserver: self forKeyPath: @"colors"];
}

@end
